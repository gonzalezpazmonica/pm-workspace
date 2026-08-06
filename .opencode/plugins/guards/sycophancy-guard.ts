// sycophancy-guard.ts — SPEC-150 Slice 2 (TypeScript port of sycophancy-strip.sh)
//
// After-guard that detects adulation patterns in tool output (PostToolUse).
// This is a Layer 1 port: regex-only, fast (<5ms), no LLM judge involved.
// Layer 2 (sycophancy-judge agent) handles semantic detection.
//
// Master switch: SAVIA_ANTIADULATION=off disables both bash and TS guard.
// Mode:          SAVIA_ANTIADULATION_LAYER1 (shadow|warn|block, default shadow)
//
// Pattern source: scripts/anti-adulation/regex-patterns.json (canonical)
//
// Reference: SPEC-150 Slice 2 (sycophancy plugin migration)
// Reference: SPEC-192 (anti-adulation system)
// Reference: docs/rules/domain/hook-multihandler-migration.md
//
// Scope note: Slices 3-6 of SPEC-150 were descoped on 2026-06-24.
// Slice 1 probe measured FP rate = 0.00 (0%), confirming ROI < threshold
// for full migration. Only sycophancy-strip (highest semantic value) was
// migrated as Slice 2. The bash hook remains as Layer 1 fallback.

import { extractToolName, type ToolInput, type ToolOutput } from "../lib/hook-input.ts";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const DEFAULT_PATTERN_PATH = fileURLToPath(
  new URL("../../../scripts/anti-adulation/regex-patterns.json", import.meta.url),
);

/** Loads the canonical obvious-pattern set and fails closed on invalid data. */
export function loadObviousPatterns(path = DEFAULT_PATTERN_PATH): RegExp[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    throw new Error(`Cannot load canonical anti-adulation patterns from ${path}: ${String(error)}`);
  }
  const obvious = (parsed as { obvious?: unknown })?.obvious;
  if (!Array.isArray(obvious) || obvious.length === 0 || obvious.some((value) => typeof value !== "string")) {
    throw new Error(`Canonical anti-adulation patterns at ${path} require a non-empty string array "obvious"`);
  }
  try {
    return obvious.map((pattern) => new RegExp(pattern, "i"));
  } catch (error) {
    throw new Error(`Invalid canonical anti-adulation regex in ${path}: ${String(error)}`);
  }
}

const OBVIOUS_PATTERNS = loadObviousPatterns();

// ── Types ─────────────────────────────────────────────────────────────────────
export interface SycophancyMatch {
  pattern: RegExp;
  position: number;
  category: "obvious";
}

// ── Core detection (exported for unit tests) ──────────────────────────────────

/** Scans the first 200 chars of draft for obvious adulation patterns.
 *  Returns the first match or null if clean. */
export function detectSycophancy(draft: string): SycophancyMatch | null {
  const probe = draft.slice(0, 200);
  for (const rx of OBVIOUS_PATTERNS) {
    const m = probe.match(rx);
    if (m) {
      return { pattern: rx, position: m.index ?? 0, category: "obvious" };
    }
  }
  return null;
}

// ── After-guard ───────────────────────────────────────────────────────────────

export async function sycophancyGuard(
  input: ToolInput,
  output: ToolOutput,
): Promise<void> {
  // Master switch
  const master = process.env["SAVIA_ANTIADULATION"] ?? "on";
  if (master === "off") return;

  const mode = process.env["SAVIA_ANTIADULATION_LAYER1"] ?? "shadow";
  if (mode === "off") return;

  // Only inspect tool output text (PostToolUse)
  const rawOutput = output?.output;
  if (typeof rawOutput !== "string" || rawOutput.length === 0) return;

  const match = detectSycophancy(rawOutput);
  if (!match) return;

  const tool = extractToolName(input);
  const score = match.position < 50 ? 95 : 90;

  switch (mode) {
    case "shadow":
      // Telemetry only — no user-visible output. Mirrors bash shadow mode.
      // Full telemetry write (JSONL) done by bash hook; TS guard avoids
      // duplicate writes to output/anti-adulation-telemetry.jsonl.
      break;

    case "warn":
      console.warn(
        `[anti-adulation TS L1] WARN: adulation pattern detected` +
        ` (tool=${tool} pos=${match.position} score=${score} cat=${match.category})`,
      );
      break;

    case "block":
      if (score >= 85 && match.position < 50) {
        throw new Error(
          `[anti-adulation SPEC-192 L1] Adulation pattern at position ${match.position}` +
          ` (score=${score}). Regenerate without opening social validation.`,
        );
      }
      // Below block threshold: log as warn
      console.warn(
        `[anti-adulation TS L1] BELOW_BLOCK_THRESHOLD (score=${score} pos=${match.position})`,
      );
      break;

    default:
      // Unknown mode: fail-open
      break;
  }
}
