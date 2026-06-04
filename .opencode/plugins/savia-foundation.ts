// savia-foundation.ts — SPEC-127 Slice 2b-i (foundation) + Slice 2b-ii (hooks wired)
// Extended by SPEC-OC-01 (Savia Shield OpenCode adaptation)
//
// OpenCode v1.14 plugin for Savia. Registers tool.execute.before and
// tool.execute.after dispatchers that run safety guards in order.
// Each guard is a pure async function imported from its own module.
//
// Provider-agnostic by construction (PV-06): the guards branch on tool
// name and command/file content, never on a hardcoded vendor name. They
// preserve the bash hook semantics 1:1 while taking advantage of TS types.
//
// Guard execution order (tool.execute.before):
//   Cheap → expensive. Throwing aborts the chain.
//   1. validate-bash-global   (regex on bash command, ~0ms)
//   2. auto-redact-credentials    (SPEC-142: mutate args.command, ~0ms)
//   3. block-credential-leak  (regex on bash command, ~0ms)
//   3. block-force-push       (regex on git commands, ~0ms)
//   4. data-sovereignty-gate  (regex + base64 + daemon/fallback, ~0ms-2s)
//   5. block-gitignored-refs  (regex on edit/write content, ~0ms)
//   6. prompt-injection-guard (content scan on context-classified files, ~0ms)
//   7. tdd-gate               (filesystem probe, the most expensive, ~10-50ms)
//
// Guard execution order (tool.execute.after):
//   Non-blocking audit, best-effort.
//   1. data-sovereignty-audit (re-scans written file, ~0-50ms)
//
// Reference: SPEC-127 Slice 2b-i + 2b-ii
// Reference: SPEC-OC-01 (Savia Shield adaptation)
// Reference: docs/rules/domain/provider-agnostic-env.md

import type { Plugin } from "@opencode-ai/plugin";

import { validateBashGlobal } from "./guards/validate-bash-global.ts";
import { autoRedactSecrets } from "./guards/auto-redact-credentials.ts";
import { blockCredentialLeak } from "./guards/block-credential-leak.ts";
import { blockForcePush } from "./guards/block-force-push.ts";
import { blockBranchSwitchDirty } from "./guards/block-branch-switch-dirty.ts";
import { blockInfraDestructive } from "./guards/block-infra-destructive.ts";
import { toolCallHealing } from "./guards/tool-call-healing.ts";
import { dataSovereigntyGate } from "./guards/data-sovereignty-gate.ts";
import { blockGitignoredReferences } from "./guards/block-gitignored-references.ts";
import { promptInjectionGuard } from "./guards/prompt-injection-guard.ts";
import { tddGate } from "./guards/tdd-gate.ts";
import { dataSovereigntyAudit } from "./guards/data-sovereignty-audit.ts";
import { autoGrillMe } from "./guards/auto-grill-me.ts";
import { autoZoomOut } from "./guards/auto-zoom-out.ts";

const BEFORE_GUARDS = [
  // Cheap guards first — fail fast.
  toolCallHealing,
  validateBashGlobal,
  autoRedactSecrets,
  blockCredentialLeak,
  blockForcePush,
  blockBranchSwitchDirty,
  blockInfraDestructive,
  dataSovereigntyGate,
  blockGitignoredReferences,
  promptInjectionGuard,
  tddGate,
  // SE-091: caveman always-on reminders (non-blocking)
  autoGrillMe,
  autoZoomOut,
] as const;

const AFTER_GUARDS = [
  dataSovereigntyAudit,
] as const;

// Model tier mapping for provider-agnostic agents (SPEC-127 / model-alias-schema.md)
// PV-06: NO vendor names hardcoded here. The map is loaded at runtime from
// ~/.savia/preferences.yaml (model_heavy, model_mid, model_fast). The user
// declares their own provider+model_id pairs in that file. The framework
// stays neutral. See docs/rules/domain/model-alias-schema.md.
import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

function loadModelTierMap(): Record<string, string> {
  const prefsPath = join(homedir(), ".savia", "preferences.yaml");
  if (!existsSync(prefsPath)) return {};
  try {
    const raw = readFileSync(prefsPath, "utf8");
    const map: Record<string, string> = {};
    for (const line of raw.split(/\r?\n/)) {
      const m = line.match(/^\s*(model_heavy|model_mid|model_fast)\s*:\s*(.+?)\s*$/);
      if (m) {
        const tier = m[1].replace("model_", "");
        const id = m[2].replace(/^["\']|["\']$/g, "");
        if (id) map[tier] = id;
      }
    }
    return map;
  } catch {
    return {};
  }
}

const MODEL_TIER_MAP: Record<string, string> = loadModelTierMap();

export const SaviaFoundationPlugin: Plugin = async ({ project, $, directory }) => {
  return {
    config: (cfg: any) => {
      // Resolve abstract model tiers in agent definitions so the provider
      // never receives an unknown model ID like "heavy" or "mid".
      if (cfg.agent && typeof cfg.agent === "object") {
        for (const agentDef of Object.values(cfg.agent) as any[]) {
          if (agentDef?.model && MODEL_TIER_MAP[agentDef.model]) {
            agentDef.model = MODEL_TIER_MAP[agentDef.model];
          }
        }
      }
    },
    "tool.execute.before": async (input: any, output: any) => {
      for (const guard of BEFORE_GUARDS) {
        await guard(input, output);
      }
    },
    "tool.execute.after": async (input: any, output: any) => {
      for (const guard of AFTER_GUARDS) {
        try {
          await guard(input, output);
        } catch {
          // After-guards are non-blocking — errors are logged internally
          // but must not surface as tool failures
        }
      }
    },
  };
};

export default SaviaFoundationPlugin;
