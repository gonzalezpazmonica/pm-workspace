// savia-foundation.ts — SPEC-127 Slice 2b-i
//
// Foundation plugin for OpenCode v1.14. Establishes the TypeScript
// toolchain + plugin contract so that subsequent slices (2b-ii) can port
// individual safety hooks from .claude/hooks/*.sh into typed handlers
// without re-establishing infrastructure.
//
// This stub is INTENTIONALLY no-op. It registers the plugin so OpenCode's
// `bun install` + plugin loader picks it up at startup. The actual hook
// handlers are added incrementally — see `.opencode/plugins/README.md` for
// the porting roadmap.
//
// Provider-agnostic by construction (PV-06): branches on capability probes
// from `scripts/savia-env.sh` via the user's `~/.savia/preferences.yaml`,
// never on a hardcoded vendor name.
//
// Reference: SPEC-127 Slice 2b-i (foundation)
// Reference: docs/rules/domain/provider-agnostic-env.md
// Reference: scripts/hook-portability-classifier.sh (TIER-1 candidates)

import type { Plugin } from "@opencode-ai/plugin";

export const SaviaFoundationPlugin: Plugin = async ({ project, $, directory }) => {
  // Foundation contract:
  // - directory: workspace root resolved by OpenCode
  // - $: bun shell API (used by hook ports to invoke savia-env.sh / scripts)
  // - project: workspace metadata
  //
  // Slice 2b-ii will populate the returned hooks object with handlers for
  // the top 5 TIER-1 hooks identified by hook-portability-classifier.sh:
  //   - validate-bash-global  → tool.execute.before (matcher: bash)
  //   - block-credential-leak → tool.execute.before (matcher: bash, edit)
  //   - block-gitignored-references → tool.execute.before (matcher: edit, write)
  //   - prompt-injection-guard → tool.execute.before (matcher: edit, write)
  //   - tdd-gate → tool.execute.before (matcher: edit)

  // No-op: foundation only. PV-01 backward compat — does not modify any
  // existing tool behaviour. Slice 2b-ii adds the actual handlers.
  return {};
};

export default SaviaFoundationPlugin;
