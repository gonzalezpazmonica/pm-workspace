// block-gitignored-references.ts — SPEC-127 Slice 2b-ii
//
// Port of `.claude/hooks/block-gitignored-references.sh`. Scans the
// content of Edit/Write operations for references to gitignored paths or
// internal-only metrics. Skips when the target file IS itself a private
// destination (writing TO gitignored is fine) or a hook source file
// (self-reference legitimate).
//
// Reference: SPEC-127 Slice 2b-ii AC-2.2 (PV-02 critical safety hook)

import {
  extractToolName,
  extractFilePath,
  extractContent,
  type ToolInput,
} from "./lib/hook-input.ts";
import { detectLeakage } from "./lib/leakage-patterns.ts";

const PRIVATE_DESTINATIONS = [
  /\/projects\//,
  /^projects\//,
  /\.local\./,
  /\/output\//,
  /private-agent-memory/,
  /\/\.savia\//,
  /\/\.claude\/sessions\//,
  /settings\.local\.json/,
];

const SOURCE_SELF_REFS = [
  /\/tests\/test-/,
  /\/tests\/.*\.bats$/,
  /\/\.claude\/hooks\//,
  /\/scripts\/test-/,
  // The hook port itself is allowed to reference patterns in source/test
  /\/\.opencode\/plugins\/lib\/leakage-patterns/,
  /\/\.opencode\/plugins\/.*\.test\.ts$/,
  /\/\.opencode\/plugins\/block-gitignored-references/,
];

function isPrivateDestination(p: string): boolean {
  return PRIVATE_DESTINATIONS.some((rx) => rx.test(p));
}

function isSourceSelfRef(p: string): boolean {
  return SOURCE_SELF_REFS.some((rx) => rx.test(p));
}

export async function blockGitignoredReferences(input: ToolInput, _output: unknown): Promise<void> {
  const tool = extractToolName(input);
  if (tool !== "edit" && tool !== "write") return;

  const filePath = extractFilePath(input);
  if (!filePath) return;
  if (isPrivateDestination(filePath)) return;
  if (isSourceSelfRef(filePath)) return;

  const content = extractContent(input);
  if (!content) return;

  const violations = detectLeakage(content);
  if (violations.length > 0) {
    const list = violations.map((v) => `  - ${v}`).join("\n");
    throw new Error(
      `BLOCKED [gitignored-references]: leak detected in ${filePath}:\n${list}\n` +
        `Use generic terms instead of internal paths/metrics. ` +
        `See: docs/rules/domain/zero-project-leakage.md`,
    );
  }
}
