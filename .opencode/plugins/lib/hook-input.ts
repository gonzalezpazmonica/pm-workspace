// hook-input.ts — SPEC-127 Slice 2b-ii (defensive rewrite 2026-05-10)
//
// Defensive helpers for extracting fields from OpenCode tool.execute hooks.
// History: prior versions assumed input shape `{tool, args: {...}}` based on
// SDK comments; runtime shape varies across OpenCode versions and forks.
// This rewrite searches the field at any depth/alias to eliminate false-positive
// "BLOCKED [tool-healing]: empty file_path" errors. Trace dumps go to
// ~/.savia/logs/healing-trace.log (persistent, gitignored, rotated at 1MB).

export type ToolInput = Record<string, unknown> | undefined | null;

const FILE_PATH_KEYS = ["filePath", "file_path", "path", "filepath", "file"];
const PATTERN_KEYS = ["pattern", "query", "regex"];
const COMMAND_KEYS = ["command", "cmd"];
const CONTENT_KEYS = ["content", "newString", "new_string", "text", "body"];
const TOOL_KEYS = ["tool", "name", "toolName", "tool_name"];
const NEST_KEYS = ["args", "arguments", "input", "params", "parameters", "tool_input"];

function isObject(x: unknown): x is Record<string, unknown> {
  return typeof x === "object" && x !== null && !Array.isArray(x);
}

function pickString(obj: Record<string, unknown>, keys: string[]): string {
  for (const k of keys) {
    const v = obj[k];
    if (typeof v === "string" && v.length > 0) return v;
  }
  return "";
}

/**
 * Search for a string field by name(s) at any depth in the input object.
 * Tries top-level first, then walks any nested container key (args, input, ...).
 * Returns the first non-empty match. Resilient to shape drift between OpenCode
 * versions: input can be {filePath: ...}, {args: {filePath: ...}},
 * {tool_input: {file_path: ...}}, etc.
 */
function deepFind(input: ToolInput, keys: string[]): string {
  if (!isObject(input)) return "";
  // 1. top-level
  const top = pickString(input, keys);
  if (top) return top;
  // 2. nested containers
  for (const nest of NEST_KEYS) {
    const child = input[nest];
    if (isObject(child)) {
      const found = pickString(child, keys);
      if (found) return found;
    }
  }
  // 3. one more level (e.g. event.tool_input.args.filePath in some shapes)
  for (const nest of NEST_KEYS) {
    const child = input[nest];
    if (isObject(child)) {
      for (const inner of NEST_KEYS) {
        const grand = child[inner];
        if (isObject(grand)) {
          const found = pickString(grand, keys);
          if (found) return found;
        }
      }
    }
  }
  return "";
}

export function extractToolName(input: ToolInput): string {
  return deepFind(input, TOOL_KEYS).toLowerCase();
}

export function extractCommand(input: ToolInput): string {
  return deepFind(input, COMMAND_KEYS);
}

export function extractFilePath(input: ToolInput): string {
  return deepFind(input, FILE_PATH_KEYS);
}

export function extractContent(input: ToolInput): string {
  return deepFind(input, CONTENT_KEYS);
}

export function extractPattern(input: ToolInput): string {
  return deepFind(input, PATTERN_KEYS);
}

/**
 * Persistent trace logger for diagnosing future shape-drift bugs.
 * Writes to ~/.savia/logs/healing-trace.log (gitignored, N3).
 * Rotates at 1 MB to .log.1. Best-effort, never throws.
 */
export async function traceHealing(label: string, input: ToolInput): Promise<void> {
  try {
    const fs = await import("node:fs");
    const os = await import("node:os");
    const path = await import("node:path");
    const dir = path.join(os.homedir(), ".savia", "logs");
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, "healing-trace.log");
    // Rotation at 1 MB
    try {
      const st = fs.statSync(file);
      if (st.size > 1_000_000) {
        fs.renameSync(file, file + ".1");
      }
    } catch {
      // file may not exist yet; ignore
    }
    const entry = JSON.stringify({
      ts: new Date().toISOString(),
      label,
      keys: isObject(input) ? Object.keys(input) : [],
      shape: input,
    });
    fs.appendFileSync(file, entry + "\n");
  } catch {
    // Best-effort trace; never block the tool call.
  }
}
