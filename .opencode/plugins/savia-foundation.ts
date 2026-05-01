// savia-foundation.ts — SPEC-127 Slice 2b-i (foundation) + Slice 2b-ii (hooks wired)
//
// OpenCode v1.14 plugin for Savia. Registers a single tool.execute.before
// dispatcher that runs the 5 TIER-1 safety guards in order. Each guard is
// a pure async function imported from its own module.
//
// Provider-agnostic by construction (PV-06): the guards branch on tool
// name and command/file content, never on a hardcoded vendor name. They
// preserve the bash hook semantics 1:1 while taking advantage of TS types.
//
// Order matters: validate-bash-global (cheap regex on command) →
// block-credential-leak (regex on bash command) → block-gitignored-references
// (regex on edit/write content) → prompt-injection-guard (file content
// scan) → tdd-gate (filesystem probe, the most expensive). Throwing in
// any guard aborts the chain and surfaces the message to the user.
//
// Reference: SPEC-127 Slice 2b-i + 2b-ii
// Reference: docs/rules/domain/provider-agnostic-env.md
// Reference: scripts/hook-portability-classifier.sh (TIER-1 candidates)

import type { Plugin } from "@opencode-ai/plugin";

import { validateBashGlobal } from "./guards/validate-bash-global.ts";
import { blockCredentialLeak } from "./guards/block-credential-leak.ts";
import { blockGitignoredReferences } from "./guards/block-gitignored-references.ts";
import { promptInjectionGuard } from "./guards/prompt-injection-guard.ts";
import { tddGate } from "./guards/tdd-gate.ts";

const GUARDS = [
  validateBashGlobal,
  blockCredentialLeak,
  blockGitignoredReferences,
  promptInjectionGuard,
  tddGate,
] as const;

export const SaviaFoundationPlugin: Plugin = async ({ project, $, directory }) => {
  return {
    "tool.execute.before": async (input: any, output: any) => {
      // Sequential — guards can rely on earlier ones not throwing. Order
      // is documented in the file header.
      for (const guard of GUARDS) {
        await guard(input, output);
      }
    },
  };
};

export default SaviaFoundationPlugin;
