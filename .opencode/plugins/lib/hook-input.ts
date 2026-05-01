// hook-input.ts — SPEC-127 Slice 2b-ii
//
// Common helpers for extracting fields from OpenCode tool.execute.before
// input/output objects. Mirrors what the bash hooks did with `jq` against
// stdin JSON.
//
// OpenCode v1.14 hook signature: (input, output) where input has shape
// { tool: string; args: Record<string, unknown> }. These helpers tolerate
// shape drift and return empty string when fields are absent.

export type ToolInput = {
  tool?: string;
  args?: Record<string, unknown>;
};

export function extractToolName(input: ToolInput): string {
  return String(input?.tool ?? "").toLowerCase();
}

export function extractCommand(input: ToolInput): string {
  const cmd = input?.args?.command;
  return typeof cmd === "string" ? cmd : "";
}

export function extractFilePath(input: ToolInput): string {
  const args = input?.args ?? {};
  const fp = args.file_path ?? args.path ?? "";
  return typeof fp === "string" ? fp : "";
}

export function extractContent(input: ToolInput): string {
  const args = input?.args ?? {};
  const c = args.content ?? args.new_string ?? "";
  return typeof c === "string" ? c : "";
}
