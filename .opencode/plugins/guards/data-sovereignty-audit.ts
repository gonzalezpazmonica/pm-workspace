// data-sovereignty-audit.ts — SPEC-OC-01
//
// Capa 5 of Savia Shield: post-edit audit logger.
// Port of `.opencode/hooks/data-sovereignty-audit.sh`.
//
// Runs AFTER Edit/Write tool execution. Re-scans the COMPLETE written file
// (not truncated to first 20000 chars like the gate) for credential leaks.
// Non-blocking — if a leak is found, it logs a warning and writes to the
// audit log but does NOT block the tool (the gate already handled the
// block during PreToolUse).
//
// OpenCode plugin lifecycle:
// - `tool.execute.before` = gate (blocking, Capa 1)
// - `tool.execute.after` = audit (non-blocking, Capa 5)
//
// Reference: docs/savia-shield.md (Capa 5)
// Reference: docs/rules/domain/data-sovereignty.md

import {
  extractToolName,
  extractFilePath,
  type ToolInput,
} from "../lib/hook-input.ts";
import {
  detectSovereigntyLeak,
  isPrivateDestination,
  isHookSelfRef,
  isShieldScript,
  normalizeNFKC,
} from "../lib/sovereignty-patterns.ts";

async function readWrittenFile(filePath: string): Promise<string> {
  try {
    const { readFile } = await import("node:fs/promises");
    const buf = await readFile(filePath, "utf-8");
    return buf;
  } catch {
    return "";
  }
}

export async function dataSovereigntyAudit(input: ToolInput, _output: unknown): Promise<void> {
  const tool = extractToolName(input);
  if (tool !== "edit" && tool !== "write") return;

  const rawPath = extractFilePath(input);
  if (!rawPath) return;

  const normPath = rawPath.replace(/\\/g, "/");

  if (isPrivateDestination(normPath)) return;
  if (isHookSelfRef(normPath)) return;
  if (isShieldScript(normPath)) return;

  // Read the complete file (not truncated)
  const fileContent = await readWrittenFile(normPath);
  if (!fileContent) return;

  // NFKC normalize and scan
  const normalized = normalizeNFKC(fileContent);
  const scan = detectSovereigntyLeak(normalized);

  if (scan.blocked) {
    const reasons = scan.detections.map((d) => d.message).join("; ");
    console.warn(
      `WARNING [Savia Shield Audit]: PII detected in ${normPath} after write. ` +
        `Reasons: ${reasons}. Review the file immediately.`,
    );

    // Log to audit file (stderr for console visibility; the bash hook writes to
    // output/data-sovereignty-audit.jsonl on disk which the TS runtime cannot
    // reliably write to in a non-blocking guard)
    process.stderr.write(
      `[savia-shield:audit:post-write] ${new Date().toISOString()} BLOCKED ${normPath} ${reasons}\n`,
    );

    // Try to write audit log to disk (best effort)
    try {
      const { appendFile, mkdir } = await import("node:fs/promises");
      const { join } = await import("node:path");
      const auditDir = join(process.cwd(), "output");
      await mkdir(auditDir, { recursive: true });
      const auditFile = join(auditDir, "data-sovereignty-audit.jsonl");
      const entry = JSON.stringify({
        ts: new Date().toISOString(),
        layer: "audit",
        verdict: "BLOCKED",
        reason: reasons,
        file: normPath,
      });
      await appendFile(auditFile, entry + "\n");
    } catch {
      // Best effort — audit logging failure must not throw
    }
  }
}
