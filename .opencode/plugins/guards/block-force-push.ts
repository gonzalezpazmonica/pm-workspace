// block-force-push.ts — SPEC-OC-01
//
// Blocks destructive git operations: force-push, push to main/master,
// amend on pushed commits, hard reset. Port of `.opencode/hooks/block-force-push.sh`.
//
// Reference: docs/rules/domain/autonomous-safety.md
// Reference: docs/rules/domain/critical-rules-extended.md (Rule 13)

import { extractToolName, extractCommand, type ToolInput } from "../lib/hook-input.ts";

const BLOCK_RULES: Array<{ rx: RegExp; msg: string }> = [
  {
    rx: /git\s+push\s+.*--force/i,
    msg: "git push --force blocked. Use --force-with-lease instead.",
  },
  {
    rx: /git\s+push\s+.*--force-with-lease.*origin\s+main/i,
    msg: "Cannot force-push to origin/main. Create a branch.",
  },
  {
    rx: /git\s+push\s+.*--delete\s+origin\s+main/i,
    msg: "Cannot delete origin/main branch.",
  },
  {
    rx: /git\s+push\s+origin\s+main/i,
    msg: "Cannot push directly to origin/main. Use a feature branch and PR.",
  },
  {
    rx: /git\s+push\s+origin\s+master/i,
    msg: "Cannot push directly to origin/master. Use a feature branch and PR.",
  },
  {
    rx: /git\s+reset\s+--hard/i,
    msg: "git reset --hard blocked. It destroys working directory changes.",
  },
  {
    rx: /git\s+checkout\s+--force/i,
    msg: "git checkout --force blocked. It destroys working directory changes.",
  },
  // Rebasing on main/master
  {
    rx: /git\s+rebase\s+origin\/(main|master)/i,
    msg: "Cannot rebase onto origin/main or origin/master. Use merge instead.",
  },
];

export async function blockForcePush(input: ToolInput, _output: unknown): Promise<void> {
  if (extractToolName(input) !== "bash") return;
  const command = extractCommand(input);
  if (!command) return;

  for (const r of BLOCK_RULES) {
    if (r.rx.test(command)) {
      throw new Error(`BLOCKED [force-push]: ${r.msg}`);
    }
  }
}
