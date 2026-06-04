// auto-grill-me.ts — SE-091 Caveman always-on
//
// Port of `.opencode/hooks/auto-grill-me.sh`. Non-blocking guard that emits
// a grill-me reminder on Edit/Write over production code files.
//
// Reference: SE-091, docs/rules/domain/caveman-default.md

import { extractToolName, extractFilePath, type ToolInput, type ToolOutput } from "../lib/hook-input.ts";

const TRIGGER_TOOLS = new Set(["Edit", "Write"]);

const CODE_EXT = new Set([
  "py", "sh", "ts", "js", "mts", "mjs",
  "cs", "go", "rs", "java", "rb", "php",
  "swift", "kt", "scala", "ex", "exs",
]);

function ext(path: string): string {
  const i = path.lastIndexOf(".");
  return i >= 0 ? path.slice(i + 1).toLowerCase() : "";
}

export function shouldGrillPath(tool: string, filePath: string): boolean {
  if (!TRIGGER_TOOLS.has(tool)) return false;
  return CODE_EXT.has(ext(filePath));
}

export async function autoGrillMe(
  input: ToolInput,
  output: ToolOutput,
): Promise<void> {
  const tool = extractToolName(input, output);
  const filePath = extractFilePath(input, output);
  if (!tool || !filePath) return;
  if (!shouldGrillPath(tool, filePath)) return;

  console.warn(
    "[grill-me auto] Editing code. Before writing, hunt: " +
    "edge cases with empty/null/very-large inputs, " +
    "unstated assumptions, missing error handling, " +
    "untested paths, silent failure modes.",
  );
}
