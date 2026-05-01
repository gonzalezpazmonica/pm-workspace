# OpenCode plugins for Savia (SPEC-127 Slice 2b)

> Foundation: SPEC-127 Slice 2b-i (this folder, package.json, tsconfig.json)
> Hook ports: SPEC-127 Slice 2b-ii (incremental, one PR per critical hook)

## Why this folder exists

OpenCode v1.14 does not execute `.claude/hooks/*.sh` natively. Hook surface
under OpenCode lives in `.opencode/plugins/*.ts`, exposing events like
`tool.execute.before` / `tool.execute.after`. To preserve Savia's safety
layer when an operator runs OpenCode against any provider, the top hooks
(by `scripts/hook-portability-classifier.sh` ranking) are ported here
incrementally.

The foundation plugin in `savia-foundation.ts` is a no-op stub. It registers
the plugin so OpenCode's startup `bun install` + plugin loader pick it up,
and establishes the typed contract that Slice 2b-ii ports build on.

## Toolchain

- `package.json` declares `@opencode-ai/plugin` (peer of OpenCode runtime).
- `tsconfig.json` is the workspace TS config (strict, ES2022 target,
  Bundler module resolution — matches Bun runtime).
- Plugins are TypeScript by convention; OpenCode also accepts `.js`.
- `bun install` runs at OpenCode startup automatically (no manual step).

## Porting roadmap (Slice 2b-ii)

These 5 hooks are TIER-1 in the classifier. Each gets its own port file
in `guards/`, with a matching `.test.ts` in `__tests__/` (Bun test runner):

1. `validate-bash-global.sh` → `guards/validate-bash-global.ts` (matcher: bash)
2. `block-credential-leak.sh` → `guards/block-credential-leak.ts` (bash, edit)
3. `block-gitignored-references.sh` → `guards/block-gitignored-references.ts` (edit, write)
4. `prompt-injection-guard.sh` → `guards/prompt-injection-guard.ts` (edit, write)
5. `tdd-gate.sh` → `guards/tdd-gate.ts` (edit)

Each port preserves the bash hook's intent. They are *additive* under
OpenCode; Claude Code keeps using the original `.sh` hooks. PV-01.

## Folder layout

OpenCode v1.14 loads every top-level `.ts` in this folder as a plugin and
expects each to export the `Plugin` shape (`{ auth, ...event handlers }`).
Files that do NOT export that shape (guards, library helpers, tests) live
in subfolders so the plugin loader does not pick them up:

```
plugins/
  savia-foundation.ts          ← only top-level plugin
  guards/                      ← guard functions imported by the plugin
  lib/                         ← shared helpers (regex tables, type guards)
  __tests__/                   ← bun:test suites for guards + foundation
```

If you add a new guard, put it in `guards/` and wire it into
`savia-foundation.ts`. Never place plain functions or test files at the
top level — the loader will crash with `J.auth is undefined` and break
even non-tool commands like `opencode auth login`.

## What this folder does NOT do

- It does not run hooks in Claude Code (those stay in `.claude/hooks/`).
- It does not implement the actual handlers (Slice 2b-ii does that).
- It does not register vendor-specific provider clients (PV-06).
- It does not auto-port the remaining 18 TIER-1 hooks (only top 5 in 2b-ii;
  the rest follow opportunistically).

## Reference

- SPEC-127 (`docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md`)
- `scripts/hook-portability-classifier.sh` (TIER-1/2/3/4 classification)
- `output/hook-portability-classification.md` (auto-generated report)
- OpenCode plugin docs: <https://opencode.ai/docs/plugins>
