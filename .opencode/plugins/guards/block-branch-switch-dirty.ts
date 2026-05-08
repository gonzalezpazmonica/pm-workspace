// block-branch-switch-dirty.ts — SPEC-OC-04 Slice 2
//
// Prevents `git checkout <branch>` / `git switch <branch>` when the working
// tree has uncommitted changes. Avoids silent data loss when the agent (or
// human) tries to jump branches mid-edit. Port of
// `.opencode/hooks/block-branch-switch-dirty.sh` (Tier: security, always active).
//
// Reference: docs/rules/domain/critical-rules-extended.md (Rule 13)

import { execSync } from "node:child_process";
import { extractToolName, extractCommand, type ToolInput } from "../lib/hook-input.ts";

// Match `git checkout <ref>` and `git switch <ref>` but NOT file restores
// (`git checkout -- file`) which are safe with a dirty tree.
const BRANCH_CHANGE_RX = /\bgit\s+(checkout|switch)\s+(?!--\s)/i;
const FILE_RESTORE_RX = /\bgit\s+checkout\s+--\s/i;

export async function blockBranchSwitchDirty(
  input: ToolInput,
  _output: unknown,
): Promise<void> {
  if (extractToolName(input) !== "bash") return;
  const command = extractCommand(input);
  if (!command) return;

  if (!BRANCH_CHANGE_RX.test(command)) return;
  if (FILE_RESTORE_RX.test(command)) return;

  let dirty = "";
  try {
    dirty = execSync("git status --porcelain", {
      encoding: "utf8",
      timeout: 3000,
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    // Not a git repo or git failed — let the original command run and fail naturally.
    return;
  }

  if (!dirty) return;

  const lines = dirty.split("\n");
  const tracked = lines.filter((l) => /^( M|M |MM|A |D )/.test(l)).length;
  const untracked = lines.filter((l) => l.startsWith("??")).length;

  throw new Error(
    [
      "BLOCKED [branch-switch-dirty]: cannot switch branch with uncommitted changes.",
      `  Modified files:  ${tracked}`,
      `  Untracked files: ${untracked}`,
      "  Options: 1) git add + git commit  2) git stash -u (temporary)",
      "  Never switch branches without saving changes.",
    ].join("\n"),
  );
}
