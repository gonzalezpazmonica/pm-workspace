// data-sovereignty-gate.ts — SPEC-OC-01
//
// Port of `.opencode/hooks/data-sovereignty-gate.sh` to OpenCode TS plugin.
// Capa 1 (Regex Gate) + Capa 8 (Base64 Decoder) of Savia Shield.
//
// Blocks Edit/Write operations that would leak credentials, connection
// strings, API keys, or internal IPs into public (N1) files.
//
// Architecture: inline regex + base64 only.
// Daemon path REMOVED 2026-05-06 — OpenCode-native migration.
// Shield daemons (8443/8444) no longer run; this guard relies solely
// on inline regex + base64 decode + cross-write detection.
//
// Block mechanism: throw Error → OpenCode surfaces as tool failure.
//
// Reference: SPEC-OC-01
// Reference: docs/savia-shield.md (Capas 1, 8)
// Reference: docs/rules/domain/data-sovereignty.md

import {
  extractToolName,
  extractFilePath,
  extractContent,
  type ToolInput,
} from "../lib/hook-input.ts";
import {
  detectSovereigntyLeak,
  detectCrossWrite,
  isPrivateDestination,
  isHookSelfRef,
  isShieldScript,
  isN1Destination,
} from "../lib/sovereignty-patterns.ts";

// ── Daemon path REMOVED 2026-05-06 (OpenCode-native migration) ──────────
// Shield daemons no longer run. Guard relies on inline regex + base64
// + cross-write below.

// ── Fallback audit log ────────────────────────────────────────────────────

function auditLog(entry: Record<string, unknown>): void {
  try {
    const ts = new Date().toISOString();
    // console.warn for operator visibility — actual file write would need
    // Bun.write which is async and not appropriate in a sync guard.
    // The audit hook (data-sovereignty-audit.ts) handles persistent logging.
    const line = JSON.stringify({ ts, ...entry });
    // Stderr so it appears in OpenCode logs
    process.stderr.write(`[savia-shield:audit] ${line}\n`);
  } catch {
    // audit failure must not block the guard
  }
}

// ── Path normalization ────────────────────────────────────────────────────

function normalizePath(path: string): string {
  // Replace backslashes, resolve ../
  return path.replace(/\\/g, "/").replace(/\/\.\.\//g, "/");
}

// ── Helper: read existing file content for cross-write detection ──────────

async function readExistingFile(filePath: string): Promise<string> {
  try {
    const { readFile } = await import("node:fs/promises");
    const buf = await readFile(filePath, "utf-8");
    // First 10000 chars (same limit as bash hook)
    return buf.slice(0, 10000);
  } catch {
    return "";
  }
}

// ── Main guard ────────────────────────────────────────────────────────────

export async function dataSovereigntyGate(
  input: ToolInput,
  _output: unknown,
): Promise<void> {
  const tool = extractToolName(input);
  if (tool !== "edit" && tool !== "write") return;

  const rawPath = extractFilePath(input);
  if (!rawPath) return;

  const normPath = normalizePath(rawPath);

  // ── Skip private destinations ──
  // N4/N4b files are never scanned. Writing TO private locations is always allowed.
  // Includes: projects/, tenants/, output/, .savia/, hooks/, tests/hooks/
  if (isPrivateDestination(normPath)) return;
  if (isHookSelfRef(normPath)) return; // hooks + tests/hooks self-references

  const content = extractContent(input);
  if (!content) return;

  // ── Shield script self-references ──
  // Legitimate sovereignty/shield scripts contain credential patterns for detection
  if (isShieldScript(normPath)) return;

  // ── Daemon path REMOVED — go straight to inline regex + base64 ──
  // Cross-write: combine existing file content + new content
  const existingContent = await readExistingFile(normPath);
  if (existingContent) {
    const crossWrite = detectCrossWrite(existingContent, content);
    if (crossWrite) {
      auditLog({
        layer: "fallback",
        verdict: "BLOCKED",
        reason: "split_write",
        file: normPath,
      });
      throw new Error(
        `BLOCKED [Savia Shield fallback]: split connection string detected in ${normPath}.`,
      );
    }
  }

  // Inline regex sovereignty detection (including base64 decode)
  const scan = detectSovereigntyLeak(content);
  if (scan.blocked) {
    const reasons = scan.detections.map((d) => d.message).join("; ");
    auditLog({
      layer: "fallback",
      verdict: "BLOCKED",
      reason: reasons,
      file: normPath,
    });
    throw new Error(
      `BLOCKED [Savia Shield fallback]: ${reasons} in ${normPath}. ` +
        `Use private destinations (projects/, .savia/).`,
    );
  }

  // ── Ollama classification (Capa 3) ──
  // For longer content that passed regex, classify with local LLM.
  // N1 destinations: AMBIGUOUS → warn but allow. CONFIDENTIAL → block.
  if (content.length > 50) {
    try {
      const { execFile } = await import("node:child_process");
      const classifyScript = "./scripts/ollama-classify.sh";

      const result = await new Promise<string>((resolve, reject) => {
        execFile(
          "bash",
          [classifyScript, content],
          { timeout: 15000, maxBuffer: 1024 * 10 },
          (err, stdout) => {
            if (err) {
              reject(err);
            } else {
              resolve(stdout.trim());
            }
          },
        );
      });

      switch (result) {
        case "CONFIDENTIAL":
          throw new Error(
            `BLOCKED [Savia Shield Ollama]: confidential content detected in ${normPath}.`,
          );
        case "AMBIGUOUS":
          if (isN1Destination(normPath)) {
            console.warn(
              `WARNING [Savia Shield]: Ollama AMBIGUOUS in ${normPath} (N1 dest, allowed)`,
            );
            auditLog({
              layer: "ollama",
              verdict: "WARN",
              reason: "ambiguous_n1",
              file: normPath,
            });
          } else {
            throw new Error(
              `BLOCKED [Savia Shield Ollama]: ambiguous content in ${normPath}`,
            );
          }
          break;
        // PUBLIC, UNAVAILABLE, or anything else → allow
      }
    } catch (e) {
      if (e instanceof Error && e.message.includes("BLOCKED")) {
        throw e;
      }
      // Ollama unavailable → gracefully degrade (already protected by regex above)
    }
  }
}
