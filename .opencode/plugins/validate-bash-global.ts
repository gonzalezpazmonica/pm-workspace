// validate-bash-global.ts — SPEC-127 Slice 2b-ii
//
// Port of `.claude/hooks/validate-bash-global.sh`. Blocks dangerous Bash
// commands: rm -rf /, chmod 777, curl | bash, sudo, gh pr review/merge
// with auto-approve flags.
//
// Note: the bash original also blocks `git commit/add` on `main` for the
// savia/pm-workspace repo. Detecting current branch from inside a TS
// plugin requires `$` shell access. To keep the port pure (no side
// effects), the branch-check is intentionally OMITTED here and remains
// covered by the bash hook under Claude Code. Under OpenCode, branch
// protection should rely on git pre-commit (TIER-2 reroute).
//
// Reference: SPEC-127 Slice 2b-ii AC-2.2

import { extractToolName, extractCommand, type ToolInput } from "./lib/hook-input.ts";

const RULES: Array<{ rx: RegExp; msg: string }> = [
  {
    rx: /rm[\s]+-rf[\s]+\//i,
    msg: "rm -rf with root path. Potentially destructive.",
  },
  {
    rx: /chmod[\s]+777/i,
    msg: "chmod 777 is insecure. Use more restrictive permissions.",
  },
  {
    rx: /curl[\s]+.*\|\s*(ba)?sh/i,
    msg: "curl | bash is insecure. Download first, review, then execute.",
  },
  {
    rx: /gh[\s]+pr[\s]+review.*--approve/i,
    msg: "Cannot self-approve PR. Assign reviewer or use branch protection.",
  },
  {
    rx: /gh[\s]+pr[\s]+merge.*--admin/i,
    msg: "--admin bypasses branch protection. Requires human review.",
  },
  {
    rx: /^[\s]*sudo[\s]/i,
    msg: "sudo not permitted from agents. Request elevation from operator.",
  },
];

export async function validateBashGlobal(input: ToolInput, _output: unknown): Promise<void> {
  if (extractToolName(input) !== "bash") return;
  const command = extractCommand(input);
  if (!command) return;
  for (const r of RULES) {
    if (r.rx.test(command)) {
      throw new Error(`BLOCKED [validate-bash-global]: ${r.msg}`);
    }
  }
}
