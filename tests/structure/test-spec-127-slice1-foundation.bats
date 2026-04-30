#!/usr/bin/env bats
# Ref: SPEC-127 Slice 1 — Provider-agnostic foundation
# Spec: docs/propuestas/SPEC-127-savia-opencode-copilot-enterprise-compat.md
# Slice 1 ships: scripts/savia-env.sh + docs/rules/domain/provider-agnostic-env.md
# + docs/rules/domain/model-alias-table.md + scripts/copilot-instructions-generate.sh
# + .github/copilot-instructions.md (auto-generated)
# This BATS suite enforces the 3 AC of Slice 1 as regression guards.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="scripts/savia-env.sh"
  ENV_SCRIPT="$REPO_ROOT/$SCRIPT"
  COPILOT_GEN="$REPO_ROOT/scripts/copilot-instructions-generate.sh"
  PROVIDER_DOC="$REPO_ROOT/docs/rules/domain/provider-agnostic-env.md"
  ALIAS_DOC="$REPO_ROOT/docs/rules/domain/model-alias-table.md"
  COPILOT_DOC="$REPO_ROOT/.github/copilot-instructions.md"
  SPEC="$REPO_ROOT/docs/propuestas/SPEC-127-savia-opencode-copilot-enterprise-compat.md"
  TMPDIR_S=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_S"
  unset SAVIA_WORKSPACE_DIR SAVIA_PROVIDER CLAUDE_PROJECT_DIR OPENCODE_PROJECT_DIR
  unset COPILOT_TOKEN GITHUB_COPILOT_TOKEN OPENCODE_PROVIDER ANTHROPIC_BASE_URL
}

# ── AC-1.1 — savia-env.sh exists, sourceable, fallback chain works ──────────

@test "AC-1.1: scripts/savia-env.sh exists, has shebang, executable" {
  [ -f "$ENV_SCRIPT" ]
  head -1 "$ENV_SCRIPT" | grep -q '^#!'
  [ -x "$ENV_SCRIPT" ]
}

@test "AC-1.1: savia-env.sh declares 'set -uo pipefail' in first 5 lines" {
  head -5 "$ENV_SCRIPT" | grep -q "set -uo pipefail"
}

@test "AC-1.1: savia-env.sh passes bash -n syntax check" {
  bash -n "$ENV_SCRIPT"
}

@test "AC-1.1: savia-env.sh sourcing exports SAVIA_WORKSPACE_DIR + SAVIA_PROVIDER" {
  unset SAVIA_WORKSPACE_DIR SAVIA_PROVIDER CLAUDE_PROJECT_DIR
  out=$(bash -c "source '$ENV_SCRIPT'; echo \"\$SAVIA_WORKSPACE_DIR|\$SAVIA_PROVIDER\"")
  [[ "$out" == *"|"* ]]
  ws="${out%|*}"
  [ -n "$ws" ]
}

@test "AC-1.1: explicit SAVIA_WORKSPACE_DIR override wins" {
  out=$(env -i SAVIA_WORKSPACE_DIR=/tmp/foo bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_WORKSPACE_DIR")
  [ "$out" = "/tmp/foo" ]
}

@test "AC-1.1: CLAUDE_PROJECT_DIR fallback works when SAVIA_WORKSPACE_DIR unset" {
  out=$(env -i CLAUDE_PROJECT_DIR=/tmp/claude-test bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_WORKSPACE_DIR")
  [ "$out" = "/tmp/claude-test" ]
}

@test "AC-1.1: OPENCODE_PROJECT_DIR fallback works (Claude vars absent)" {
  out=$(env -i OPENCODE_PROJECT_DIR=/tmp/opencode-test bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_WORKSPACE_DIR")
  [ "$out" = "/tmp/opencode-test" ]
}

@test "AC-1.1: git rev-parse fallback when no env vars set (in repo)" {
  cd "$REPO_ROOT"
  out=$(env -i PATH="$PATH" bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_WORKSPACE_DIR")
  [ "$out" = "$REPO_ROOT" ]
}

@test "AC-1.1: provider detection — copilot via COPILOT_TOKEN" {
  out=$(env -i COPILOT_TOKEN=fake bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_PROVIDER")
  [ "$out" = "copilot" ]
}

@test "AC-1.1: provider detection — claude via CLAUDE_PROJECT_DIR" {
  out=$(env -i CLAUDE_PROJECT_DIR=/tmp/c bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_PROVIDER")
  [ "$out" = "claude" ]
}

@test "AC-1.1: provider detection — localai via ANTHROPIC_BASE_URL pointing to localhost" {
  out=$(env -i ANTHROPIC_BASE_URL=http://localhost:8080/v1 bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_PROVIDER")
  [ "$out" = "localai" ]
}

@test "AC-1.1: provider detection — explicit SAVIA_PROVIDER wins all" {
  out=$(env -i SAVIA_PROVIDER=copilot CLAUDE_PROJECT_DIR=/tmp bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_PROVIDER")
  [ "$out" = "copilot" ]
}

@test "AC-1.1: capability probe savia_has_hooks returns 1 under copilot" {
  run env -i COPILOT_TOKEN=fake bash -c "source '$ENV_SCRIPT'; savia_has_hooks; echo \$?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1" ]]
}

@test "AC-1.1: capability probe savia_has_slash_commands returns 1 under copilot" {
  run env -i COPILOT_TOKEN=fake bash -c "source '$ENV_SCRIPT'; savia_has_slash_commands; echo \$?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1" ]]
}

@test "AC-1.1: CLI dispatch 'print' shows all 4 keys" {
  run bash "$ENV_SCRIPT" print
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAVIA_WORKSPACE_DIR="* ]]
  [[ "$output" == *"SAVIA_PROVIDER="* ]]
  [[ "$output" == *"has_hooks="* ]]
  [[ "$output" == *"has_slash_commands="* ]]
}

@test "AC-1.1: CLI dispatch 'workspace' returns just the path" {
  run bash "$ENV_SCRIPT" workspace
  [ "$status" -eq 0 ]
  [ -d "$output" ]
}

@test "AC-1.1: CLI dispatch unknown subcommand exits 2" {
  run bash "$ENV_SCRIPT" bogus
  [ "$status" -eq 2 ]
}

@test "AC-1.1: provider-agnostic-env.md exists with frontmatter heading" {
  [ -f "$PROVIDER_DOC" ]
  head -3 "$PROVIDER_DOC" | grep -q "Provider-agnostic environment"
}

@test "AC-1.1: provider-agnostic-env.md ≤ 150 lines (workspace cap)" {
  lines=$(wc -l < "$PROVIDER_DOC")
  [ "$lines" -le 150 ]
}

@test "AC-1.1: provider-agnostic-env.md documents fallback chain" {
  grep -q "SAVIA_WORKSPACE_DIR" "$PROVIDER_DOC"
  grep -q "CLAUDE_PROJECT_DIR" "$PROVIDER_DOC"
  grep -q "OPENCODE_PROJECT_DIR" "$PROVIDER_DOC"
  grep -qE "git rev-parse" "$PROVIDER_DOC"
}

# ── AC-1.2 — model-alias-table.md ──────────────────────────────────────────

@test "AC-1.2: model-alias-table.md exists" {
  [ -f "$ALIAS_DOC" ]
}

@test "AC-1.2: model-alias-table.md ≤ 150 lines (workspace cap)" {
  lines=$(wc -l < "$ALIAS_DOC")
  [ "$lines" -le 150 ]
}

@test "AC-1.2: documents 3 canonical Claude model rows" {
  grep -q "claude-opus-4-7" "$ALIAS_DOC"
  grep -q "claude-sonnet-4-6" "$ALIAS_DOC"
  grep -q "claude-haiku-4-5-20251001" "$ALIAS_DOC"
}

@test "AC-1.2: documents Copilot primary mappings" {
  grep -qE "github-copilot/" "$ALIAS_DOC"
}

@test "AC-1.2: documents fallback rationale (Why these mappings)" {
  grep -qiE "Why these mappings|Cost caveat|capability cliff" "$ALIAS_DOC"
}

@test "AC-1.2: documents LocalAI emergency fallback (SPEC-122 link)" {
  grep -qE "localai" "$ALIAS_DOC"
  grep -q "SPEC-122" "$ALIAS_DOC"
}

@test "AC-1.2: documents pending operator confirmation block" {
  grep -qiE "Pending operator|verified against|provisional" "$ALIAS_DOC"
}

# ── AC-1.3 — copilot-instructions-generate.sh + output ────────────────────

@test "AC-1.3: copilot-instructions-generate.sh exists, executable, has shebang" {
  [ -f "$COPILOT_GEN" ]
  head -1 "$COPILOT_GEN" | grep -q '^#!'
  [ -x "$COPILOT_GEN" ]
}

@test "AC-1.3: copilot-instructions-generate.sh declares 'set -uo pipefail'" {
  head -10 "$COPILOT_GEN" | grep -q "set -uo pipefail"
}

@test "AC-1.3: copilot-instructions-generate.sh passes bash -n" {
  bash -n "$COPILOT_GEN"
}

@test "AC-1.3: --check is idempotent (in sync after --apply)" {
  run bash "$COPILOT_GEN" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"in sync"* ]]
}

@test "AC-1.3: --check exits 1 when target missing" {
  cp "$COPILOT_DOC" "$TMPDIR_S/backup.md"
  COPILOT_INSTRUCTIONS="$TMPDIR_S/nonexistent.md" run bash "$COPILOT_GEN" --check
  [ "$status" -eq 1 ]
}

@test "AC-1.3: .github/copilot-instructions.md exists" {
  [ -f "$COPILOT_DOC" ]
}

@test "AC-1.3: copilot-instructions.md ≤ 120 lines (Copilot context cap)" {
  lines=$(wc -l < "$COPILOT_DOC")
  [ "$lines" -le 120 ]
}

@test "AC-1.3: copilot-instructions.md contains zero @import directives" {
  ! grep -qE '^@[a-zA-Z]' "$COPILOT_DOC"
}

@test "AC-1.3: copilot-instructions.md has Project identity section" {
  grep -q "Project identity" "$COPILOT_DOC"
}

@test "AC-1.3: copilot-instructions.md has Inviolable rules section" {
  grep -qE "Inviolable rules|PV-01" "$COPILOT_DOC"
}

@test "AC-1.3: copilot-instructions.md documents reduced surface caveats" {
  grep -qE "Reduced surface|hook events|Task tool|slash command" "$COPILOT_DOC"
}

@test "AC-1.3: copilot-instructions.md has Agents section with table" {
  grep -q "## Agents" "$COPILOT_DOC"
  grep -qE '^\| Name \|' "$COPILOT_DOC"
}

@test "AC-1.3: --apply twice yields same content (idempotent)" {
  cp "$COPILOT_DOC" "$TMPDIR_S/first.md"
  bash "$COPILOT_GEN" --apply >/dev/null
  diff -q "$COPILOT_DOC" "$TMPDIR_S/first.md"
}

# ── Spec ref + frontmatter ──────────────────────────────────────────────────

@test "spec ref: SPEC-127 exists and has APPROVED status" {
  [ -f "$SPEC" ]
  grep -qE "^status: APPROVED" "$SPEC"
}

@test "spec ref: SPEC-127 declares slice_1_status IMPLEMENTED" {
  grep -qE "^slice_1_status: IMPLEMENTED" "$SPEC"
}

@test "spec ref: SPEC-127 referenced in this test file" {
  grep -q "docs/propuestas/SPEC-127" "$BATS_TEST_FILENAME"
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: savia-env.sh sourced with empty environment defaults to pwd" {
  cd "$TMPDIR_S"
  out=$(env -i PATH="$PATH" bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_WORKSPACE_DIR")
  # Should resolve to either git toplevel (if mktemp inside git) or pwd
  [ -n "$out" ]
}

@test "edge: provider 'unknown' boundary — zero signals present (no-arg env)" {
  cd "$TMPDIR_S"
  out=$(env -i PATH="$PATH" bash -c "source '$ENV_SCRIPT' 2>/dev/null; echo \$SAVIA_PROVIDER")
  [ "$out" = "unknown" ]
}

@test "edge: copilot-instructions-generate.sh handles nonexistent AGENTS_DIR" {
  run env AGENTS_DIR="$TMPDIR_S/nonexistent" bash "$COPILOT_GEN"
  [ "$status" -eq 3 ]
}

@test "edge: copilot-instructions.md is well-formed markdown (boundary — no broken table rows)" {
  # Every table row has matching | counts
  awk -F'|' '/^\|/ { if (NF != prev && prev != 0) { print NR": "$0; bad++ } prev=NF } END { exit bad>0?1:0 }' "$COPILOT_DOC"
}

# ── Coverage ────────────────────────────────────────────────────────────────

@test "coverage: savia-env.sh exposes 4 capability functions" {
  for fn in savia_workspace_dir savia_provider savia_has_hooks savia_has_slash_commands; do
    grep -qE "^${fn}\(\)" "$ENV_SCRIPT"
  done
}

@test "coverage: copilot-instructions-generate.sh has 3 modes (generate|apply|check)" {
  grep -qE 'generate\)' "$COPILOT_GEN"
  grep -qE 'apply\)' "$COPILOT_GEN"
  grep -qE 'check\)' "$COPILOT_GEN"
}

@test "coverage: AC-1.3 line cap enforcement present in script" {
  grep -qE 'MAX_LINES=120|ACTUAL_LINES.*MAX_LINES' "$COPILOT_GEN"
}
