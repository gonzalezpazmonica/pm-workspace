#!/usr/bin/env bats
# Ref: SPEC-127 Slice 2b-i — TypeScript toolchain foundation for OpenCode plugins
# Spec: docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md
#
# Slice 2b-i ships:
#   - .opencode/package.json (declares @opencode-ai/plugin dep)
#   - .opencode/tsconfig.json (strict TS config)
#   - .opencode/plugins/savia-foundation.ts (no-op foundation plugin)
#   - .opencode/plugins/savia-foundation.test.ts (contract tests, Bun runner)
#   - .opencode/plugins/README.md (porting roadmap doc)
#
# These tests verify the toolchain structure is in place for Slice 2b-ii
# hook ports. Runtime tests (Bun) are deferred — these are structural BATS.

setup() {
  # set -uo pipefail semantics applied inside test bodies
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT=".opencode/plugins/savia-foundation.ts"
  PKG_JSON="$REPO_ROOT/.opencode/package.json"
  TSCONFIG="$REPO_ROOT/.opencode/tsconfig.json"
  PLUGINS_DIR="$REPO_ROOT/.opencode/plugins"
  FOUNDATION_TS="$REPO_ROOT/$SCRIPT"
  FOUNDATION_TEST="$PLUGINS_DIR/savia-foundation.test.ts"
  PLUGINS_README="$PLUGINS_DIR/README.md"
  SPEC="$REPO_ROOT/docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md"
  CLASSIFIER_REPORT="$REPO_ROOT/output/hook-portability-classification.md"
  TMPDIR_T=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_T"
}

# ── package.json ──────────────────────────────────────────────────────────

@test "package.json exists at .opencode/package.json" {
  [ -f "$PKG_JSON" ]
}

@test "package.json is valid JSON" {
  python3 -c "import json; json.load(open('$PKG_JSON'))"
}

@test "package.json declares @opencode-ai/plugin dependency" {
  python3 -c "
import json
d = json.load(open('$PKG_JSON'))
assert '@opencode-ai/plugin' in d.get('dependencies', {}), 'missing @opencode-ai/plugin'
"
}

@test "package.json is type=module (ESM)" {
  python3 -c "
import json
d = json.load(open('$PKG_JSON'))
assert d.get('type') == 'module', f'expected type=module, got {d.get(\"type\")}'
"
}

@test "package.json is private (not publishable)" {
  python3 -c "
import json
d = json.load(open('$PKG_JSON'))
assert d.get('private') is True, 'package must be private'
"
}

@test "package.json references SPEC-127 Slice 2b-i" {
  grep -q "SPEC-127 Slice 2b-i" "$PKG_JSON"
}

# ── tsconfig.json ─────────────────────────────────────────────────────────

@test "tsconfig.json exists at .opencode/tsconfig.json" {
  [ -f "$TSCONFIG" ]
}

@test "tsconfig.json is valid JSON" {
  python3 -c "import json; json.load(open('$TSCONFIG'))"
}

@test "tsconfig.json declares strict mode" {
  python3 -c "
import json
d = json.load(open('$TSCONFIG'))
assert d.get('compilerOptions', {}).get('strict') is True, 'strict must be true'
"
}

@test "tsconfig.json declares noEmit (typecheck-only)" {
  python3 -c "
import json
d = json.load(open('$TSCONFIG'))
assert d.get('compilerOptions', {}).get('noEmit') is True, 'noEmit must be true'
"
}

@test "tsconfig.json includes plugins/**/*.ts" {
  python3 -c "
import json
d = json.load(open('$TSCONFIG'))
inc = d.get('include', [])
assert any('plugins' in i for i in inc), 'must include plugins'
"
}

@test "tsconfig.json excludes node_modules" {
  python3 -c "
import json
d = json.load(open('$TSCONFIG'))
exc = d.get('exclude', [])
assert any('node_modules' in i for i in exc), 'must exclude node_modules'
"
}

# ── Foundation plugin ──────────────────────────────────────────────────────

@test "foundation plugin TS file exists" {
  [ -f "$FOUNDATION_TS" ]
}

@test "foundation plugin imports Plugin type from @opencode-ai/plugin" {
  grep -qE 'import.*type.*Plugin.*@opencode-ai/plugin' "$FOUNDATION_TS"
}

@test "foundation plugin exports SaviaFoundationPlugin (named + default)" {
  grep -qE 'export const SaviaFoundationPlugin' "$FOUNDATION_TS"
  grep -qE 'export default SaviaFoundationPlugin' "$FOUNDATION_TS"
}

@test "foundation plugin is async function (returns Promise)" {
  grep -qE 'async \(' "$FOUNDATION_TS"
}

@test "foundation plugin is no-op stub (returns empty hooks {})" {
  grep -qE 'return \{\}' "$FOUNDATION_TS"
}

@test "foundation plugin documents porting roadmap (top 5 hooks)" {
  grep -q "validate-bash-global" "$FOUNDATION_TS"
  grep -q "block-credential-leak" "$FOUNDATION_TS"
  grep -q "prompt-injection-guard" "$FOUNDATION_TS"
}

@test "foundation plugin references SPEC-127 + provider-agnostic-env.md" {
  grep -q "SPEC-127" "$FOUNDATION_TS"
  grep -q "provider-agnostic-env" "$FOUNDATION_TS"
}

# ── Test scaffold ──────────────────────────────────────────────────────────

@test "foundation test file exists (.test.ts)" {
  [ -f "$FOUNDATION_TEST" ]
}

@test "foundation test imports SaviaFoundationPlugin" {
  grep -qE 'import.*SaviaFoundationPlugin' "$FOUNDATION_TEST"
}

@test "foundation test imports bun:test runner" {
  grep -qE 'from "bun:test"' "$FOUNDATION_TEST"
}

@test "foundation test verifies plugin returns empty hooks object" {
  grep -qE 'toEqual\(\{\}\)' "$FOUNDATION_TEST"
}

@test "foundation test covers 3+ test cases" {
  count=$(grep -c 'test(' "$FOUNDATION_TEST")
  [ "$count" -ge 3 ]
}

# ── Plugins README ─────────────────────────────────────────────────────────

@test "plugins README exists" {
  [ -f "$PLUGINS_README" ]
}

@test "plugins README documents porting roadmap (top 5 hooks)" {
  for hook in validate-bash-global block-credential-leak block-gitignored-references prompt-injection-guard tdd-gate; do
    grep -q "$hook" "$PLUGINS_README"
  done
}

@test "plugins README references SPEC-127 Slice 2b" {
  grep -qE "SPEC-127 Slice 2b" "$PLUGINS_README"
}

@test "plugins README explains why folder exists (no native bash hooks)" {
  grep -qiE "does not execute.*sh|hook surface" "$PLUGINS_README"
}

@test "plugins README ≤ 150 lines (workspace cap)" {
  lines=$(wc -l < "$PLUGINS_README")
  [ "$lines" -le 150 ]
}

# ── PV-06 — no vendor lock-in ──────────────────────────────────────────────

@test "PV-06: foundation plugin does not reference a hardcoded vendor" {
  ! grep -qiE 'github.copilot|copilot.enterprise|openai\.com|anthropic\.com/v1|mistral\.ai|deepseek/' "$FOUNDATION_TS"
}

@test "PV-06: package.json does not pin to a vendor-specific client" {
  ! grep -qiE 'github.copilot|copilot.enterprise|"openai"|"anthropic"' "$PKG_JSON"
}

# ── Spec ref ────────────────────────────────────────────────────────────────

@test "spec ref: SPEC-127 declares Slice 2 in spec body" {
  grep -qE "Slice 2" "$SPEC"
}

@test "spec ref: docs/propuestas/SPEC-127 referenced in this test file" {
  grep -q "docs/propuestas/SPEC-127" "$BATS_TEST_FILENAME"
}

@test "spec ref: foundation plugin documents Slice 2b-i + Slice 2b-ii roadmap" {
  grep -q "Slice 2b-i" "$FOUNDATION_TS"
  grep -q "Slice 2b-ii" "$FOUNDATION_TS"
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: foundation plugin file is non-empty (boundary)" {
  size=$(wc -c < "$FOUNDATION_TS")
  [ "$size" -gt 200 ]
}

@test "edge: foundation plugin is ≤ 200 lines (foundation should be small)" {
  lines=$(wc -l < "$FOUNDATION_TS")
  [ "$lines" -le 200 ]
}

@test "edge: package.json description mentions Slice 2b-i (boundary)" {
  python3 -c "
import json
d = json.load(open('$PKG_JSON'))
desc = d.get('description', '')
assert 'Slice 2b-i' in desc or 'foundation' in desc.lower(), 'description should mention foundation'
"
}

# ── Coverage ────────────────────────────────────────────────────────────────

@test "coverage: foundation plugin destructures expected context fields" {
  # Plugin context: project, $, directory (per OpenCode v1.14 plugin docs)
  grep -qE 'project.*\$.*directory|directory.*project|project.*directory' "$FOUNDATION_TS"
}

@test "coverage: classifier output (.opencode/plugins/README.md mentions classifier report)" {
  grep -qE 'hook-portability-classifier|hook-portability-classification' "$PLUGINS_README"
}

@test "coverage: foundation directory structure complete" {
  [ -d "$PLUGINS_DIR" ]
  [ -f "$PKG_JSON" ]
  [ -f "$TSCONFIG" ]
  [ -f "$FOUNDATION_TS" ]
  [ -f "$FOUNDATION_TEST" ]
  [ -f "$PLUGINS_README" ]
}
