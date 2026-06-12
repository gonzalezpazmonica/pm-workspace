// hook-input.ts — SPEC-127 Slice 2b-ii + SPEC-155 (args shape fix)
//
// Common helpers for extracting fields from OpenCode tool.execute.before
// (input, output) callbacks.
//
// OpenCode v1.14+ contract (per https://opencode.ai/docs/plugins/):
//   - `input.tool`     → string, tool name
//   - `output.args`    → Record<string, unknown>, MUTABLE args object
//   - Mutations to args (e.g. shell escaping, secret redaction) MUST be
//     applied on `output.args` to take effect downstream.
//
// Legacy shape (pre-v1.14 / Claude Code bash hooks emulated in tests):
//   - `input.args`     → was the args carrier.
//
// To stay compatible with both, helpers accept (input, output?) and prefer
// `output.args` when present, falling back to `input.args`. Mutators use
// `mutableArgs(input, output)` which returns the args object guards should
// write to so the change is observed by the runtime.

export type ToolInput = {
  tool?: string;
  args?: Record<string, unknown>;
};

// OpenCode v1.14 ToolOutput contract (per https://opencode.ai/docs/plugins/):
//   - args: MUTABLE args object (input mirror)
//   - title: tool display title
//   - output: stdout/result text (mutable in tool.execute.after)
//   - metadata: tool-specific metadata
// SE-221 added output/title/metadata as optional fields so guards that mutate
// output (context-origin-stamp, context-drop-after-use) can be typed end-to-end.
export type ToolOutput = {
  args?: Record<string, unknown>;
  title?: string;
  output?: string;
  metadata?: Record<string, unknown>;
};

function pickArgs(input?: ToolInput, output?: ToolOutput): Record<string, unknown> {
  // Real OpenCode v1.14+ shape first; legacy fallback for retro-compat.
  return (output?.args as Record<string, unknown> | undefined)
    ?? (input?.args as Record<string, unknown> | undefined)
    ?? {};
}

/** Returns the args object guards should MUTATE for the runtime to see it.
 *  Prefers output.args (real contract); if absent but input.args exists,
 *  returns input.args (covers legacy fixtures + Claude Code bash hooks). */
export function mutableArgs(input?: ToolInput, output?: ToolOutput): Record<string, unknown> | null {
  // Real OpenCode v1.14+: output.args populated by runtime — mutate it.
  if (output && typeof output === "object" && output.args && typeof output.args === "object") {
    return output.args as Record<string, unknown>;
  }
  // Legacy fixtures / Claude Code bash hooks: args live on input. Mutate input.args
  // so test assertions and downstream legacy callers observe the change.
  if (input?.args && typeof input.args === "object") {
    // Mirror by reference so a v1.14 runtime would also see it.
    if (output && typeof output === "object") {
      output.args = input.args;
    }
    return input.args as Record<string, unknown>;
  }
  // Last resort: materialize output.args.
  if (output && typeof output === "object") {
    output.args = {};
    return output.args as Record<string, unknown>;
  }
  return null;
}

export function extractToolName(input?: ToolInput): string {
  return String(input?.tool ?? "").toLowerCase();
}

export function extractCommand(input?: ToolInput, output?: ToolOutput): string {
  const cmd = pickArgs(input, output).command;
  return typeof cmd === "string" ? cmd : "";
}

export function extractFilePath(input?: ToolInput, output?: ToolOutput): string {
  const args = pickArgs(input, output);
  // OpenCode v1.14 schema: filePath (camelCase). Legacy: file_path / path.
  const fp = args.filePath ?? args.file_path ?? args.path ?? "";
  return typeof fp === "string" ? fp : "";
}

export function extractContent(input?: ToolInput, output?: ToolOutput): string {
  const args = pickArgs(input, output);
  // OpenCode v1.14: write → `content`, edit → `newString`.
  // Legacy Claude Code: edit → `new_string`.
  const c = args.content ?? args.newString ?? args.new_string ?? "";
  return typeof c === "string" ? c : "";
}

export function extractPattern(input?: ToolInput, output?: ToolOutput): string {
  const p = pickArgs(input, output).pattern;
  return typeof p === "string" ? p : "";
}
