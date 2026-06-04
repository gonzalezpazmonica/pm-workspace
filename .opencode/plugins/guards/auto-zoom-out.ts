// auto-zoom-out.ts — SE-091 Caveman always-on
//
// Port of `.opencode/hooks/auto-zoom-out.sh`. Non-blocking guard that emits
// a zoom-out reminder on Edit/Write over architecture and documentation files.
//
// Reference: SE-091, docs/rules/domain/caveman-default.md

import { extractToolName, extractFilePath, type ToolInput, type ToolOutput } from "../lib/hook-input.ts";

const TRIGGER_TOOLS = new Set(["Edit", "Write"]);

const ARCH_PATH_PATTERNS = [
  /docs\/(architecture|propuestas|specs|rules)\//,
  /\.(arch|design)\.md$/,
  /(ROADMAP|ARCHITECTURE)\.md$/,
];

export function shouldZoomOutPath(tool: string, filePath: string): boolean {
  if (!TRIGGER_TOOLS.has(tool)) return false;
  return ARCH_PATH_PATTERNS.some((re) => re.test(filePath));
}

export async function autoZoomOut(
  input: ToolInput,
  output: ToolOutput,
): Promise<void> {
  const tool = extractToolName(input, output);
  const filePath = extractFilePath(input, output);
  if (!tool || !filePath) return;
  if (!shouldZoomOutPath(tool, filePath)) return;

  console.warn(
    "[zoom-out auto] Editing architecture/doc. Before changing: " +
    "what dependencies does this affect? " +
    "What second-order effects? What else would break? " +
    "Map the impact, then write.",
  );
}
