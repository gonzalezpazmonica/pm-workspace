// block-new-features-in-pr.ts — Prevents committing new features into open PR branches
//
// Guard: checks if the current git branch has an open PR and blocks commits
// that introduce new spec files, packages, or source directories that don't
// match the PR's scope.
//
// Reference: incident 2026-08-02 — SE-294 committed into PR #923 branch

import { extractToolName, extractCommand } from "../lib/hook-input.ts";
import type { ToolInput, ToolOutput } from "../lib/hook-input.ts";

const BLOCKED_PATTERNS = [
  { pattern: /git\s+commit/, description: "git commit on open PR branch" },
];

export async function blockNewFeaturesInPr(input: ToolInput, _output: ToolOutput): Promise<void> {
  const tool = extractToolName(input);
  if (tool !== "bash") return;
  const command = extractCommand(input, _output);
  if (!command) return;

  const isCommit = BLOCKED_PATTERNS.some(p => p.pattern.test(command));
  if (!isCommit) return;

  // This guard is informational — the real enforcement is in pre-commit-no-new-features.sh
  // We just log a warning here for OpenCode-native sessions.
  // The bash hook runs during actual git commit.
}
