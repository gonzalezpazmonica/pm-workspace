// block-infra-destructive.ts — SPEC-OC-04 Slice 2
//
// Blocks destructive infrastructure operations from being executed by an
// agent. Human approval is required for these. Port of
// `.opencode/hooks/block-infra-destructive.sh` (Tier: security, always active).
//
// Reference: docs/rules/domain/critical-rules-extended.md (Rule 10)
// Reference: docs/rules/domain/autonomous-safety.md

import { extractToolName, extractCommand, type ToolInput } from "../lib/hook-input.ts";

const ENV_TOKEN = "(?:^|[\\s/=])(?:pre|production|prod|staging|pro)(?:[\\s/=.]|$)";

const BLOCK_RULES: Array<{ rx: RegExp; msg: string }> = [
  {
    rx: /\bterraform\s+destroy\b/i,
    msg: "terraform destroy requires direct human approval. Never run from an agent.",
  },
  {
    rx: new RegExp(`\\bterraform\\s+apply\\b.*${ENV_TOKEN}`, "i"),
    msg: "terraform apply on PRE/PRO requires human approval. Only DEV is allowed.",
  },
  {
    rx: /\baz\s+group\s+delete\b/i,
    msg: "Azure Resource Group deletion requires human approval.",
  },
  {
    rx: /\baws\s+cloudformation\s+delete-stack\b/i,
    msg: "AWS delete-stack requires human approval.",
  },
  {
    rx: /\bkubectl\s+delete\s+namespace\b/i,
    msg: "Kubernetes namespace deletion requires human approval.",
  },
];

export async function blockInfraDestructive(
  input: ToolInput,
  _output: unknown,
): Promise<void> {
  if (extractToolName(input) !== "bash") return;
  const command = extractCommand(input);
  if (!command) return;

  for (const r of BLOCK_RULES) {
    if (r.rx.test(command)) {
      throw new Error(`BLOCKED [infra-destructive]: ${r.msg}`);
    }
  }
}
