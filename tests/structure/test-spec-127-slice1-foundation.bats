#!/usr/bin/env bats
# Ref: SPEC-127 Slice 1 — Provider-agnostic foundation + onboarding
# Spec: docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md
#
# Slice 1 ships:
#   - scripts/savia-env.sh
#   - scripts/savia-preferences.sh
#   - .claude/commands/savia-setup.md
#   - docs/rules/domain/provider-agnostic-env.md
#   - docs/rules/domain/model-alias-schema.md
#
# This BATS suite enforces the 4 AC of Slice 1 as regression guards.
# Cero hardcoded vendor names en este test (PV-06).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="scripts/savia-env.sh"
  ENV_SCRIPT="$REPO_ROOT/$SCRIPT"
  PREFS_SCRIPT="$REPO_ROOT/scripts/savia-preferences.sh"
  PROVIDER_DOC="$REPO_ROOT/docs/rules/domain/provider-agnostic-env.md"
  ALIAS_DOC="$REPO_ROOT/docs/rules/domain/model-alias-schema.md"
  COMMAND_DOC="$REPO_ROOT/.claude/commands/savia-setup.md"
  SPEC="$REPO_ROOT/docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md"
  TMPDIR_S=$(mktemp -d)
  TMPPREFS="$TMPDIR_S/preferences.yaml"
  export SAVIA_PREFS_FILE="$TMPPREFS"
}

teardown() {
  rm -rf "$TMPDIR_S"
  unset SAVIA_WORKSPACE_DIR SAVIA_PROVIDER CLAUDE_PROJECT_DIR OPENCODE_PROJECT_DIR
  unset SAVIA_PREFS_FILE ANTHROPIC_BASE_URL
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

@test "AC-1.1: explicit SAVIA_WORKSPACE_DIR override wins" {
  out=$(env -i SAVIA_WORKSPACE_DIR=/tmp/foo bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_WORKSPACE_DIR")
  [ "$out" = "/tmp/foo" ]
}

@test "AC-1.1: CLAUDE_PROJECT_DIR fallback works when SAVIA_WORKSPACE_DIR unset" {
  out=$(env -i CLAUDE_PROJECT_DIR=/tmp/cd bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_WORKSPACE_DIR")
  [ "$out" = "/tmp/cd" ]
}

@test "AC-1.1: OPENCODE_PROJECT_DIR fallback works when Claude vars absent" {
  out=$(env -i OPENCODE_PROJECT_DIR=/tmp/oc bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_WORKSPACE_DIR")
  [ "$out" = "/tmp/oc" ]
}

@test "AC-1.1: git rev-parse fallback when no env vars set (in repo)" {
  cd "$REPO_ROOT"
  out=$(env -i PATH="$PATH" bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_WORKSPACE_DIR")
  [ "$out" = "$REPO_ROOT" ]
}

@test "AC-1.1: CLI dispatch 'print' shows all required keys" {
  run bash "$ENV_SCRIPT" print
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAVIA_WORKSPACE_DIR="* ]]
  [[ "$output" == *"SAVIA_PROVIDER="* ]]
  [[ "$output" == *"has_hooks="* ]]
  [[ "$output" == *"has_slash_commands="* ]]
  [[ "$output" == *"has_task_fan_out="* ]]
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

@test "AC-1.1: provider-agnostic-env.md documents fallback chain + capability probes" {
  grep -q "SAVIA_WORKSPACE_DIR" "$PROVIDER_DOC"
  grep -q "CLAUDE_PROJECT_DIR" "$PROVIDER_DOC"
  grep -q "OPENCODE_PROJECT_DIR" "$PROVIDER_DOC"
  grep -qE "git rev-parse" "$PROVIDER_DOC"
  grep -q "savia_has_hooks" "$PROVIDER_DOC"
  grep -q "savia_has_task_fan_out" "$PROVIDER_DOC"
}

# ── AC-1.2 — savia-preferences.sh + onboarding command ─────────────────────

@test "AC-1.2: scripts/savia-preferences.sh exists, executable, syntax OK" {
  [ -f "$PREFS_SCRIPT" ]
  [ -x "$PREFS_SCRIPT" ]
  bash -n "$PREFS_SCRIPT"
}

@test "AC-1.2: savia-preferences.sh has 'set -uo pipefail'" {
  head -5 "$PREFS_SCRIPT" | grep -q "set -uo pipefail"
}

@test "AC-1.2: subcommand 'set' creates file with version key" {
  run bash "$PREFS_SCRIPT" set frontend opencode
  [ "$status" -eq 0 ]
  [ -f "$TMPPREFS" ]
  grep -q "^version: 1" "$TMPPREFS"
  grep -q "^frontend: opencode" "$TMPPREFS"
}

@test "AC-1.2: subcommand 'get' reads scalar value (positive case)" {
  bash "$PREFS_SCRIPT" set provider some-vendor >/dev/null
  run bash "$PREFS_SCRIPT" get provider
  [ "$status" -eq 0 ]
  [ "$output" = "some-vendor" ]
}

@test "AC-1.2: subcommand 'set' replaces existing scalar (idempotent)" {
  bash "$PREFS_SCRIPT" set frontend claude-code >/dev/null
  bash "$PREFS_SCRIPT" set frontend opencode >/dev/null
  out=$(bash "$PREFS_SCRIPT" get frontend)
  [ "$out" = "opencode" ]
}

@test "AC-1.2: subcommand 'show' outputs file contents (positive)" {
  bash "$PREFS_SCRIPT" set frontend opencode >/dev/null
  run bash "$PREFS_SCRIPT" show
  [ "$status" -eq 0 ]
  [[ "$output" == *"frontend: opencode"* ]]
}

@test "AC-1.2: subcommand 'show' on absent file returns notice (graceful)" {
  run bash "$PREFS_SCRIPT" show
  [ "$status" -eq 0 ]
  [[ "$output" == *"absent"* ]]
}

@test "AC-1.2: subcommand 'reset' rejects without --confirm (boundary)" {
  bash "$PREFS_SCRIPT" set frontend opencode >/dev/null
  run bash "$PREFS_SCRIPT" reset
  [ "$status" -eq 2 ]
  [ -f "$TMPPREFS" ]
}

@test "AC-1.2: subcommand 'reset --confirm' deletes file (positive)" {
  bash "$PREFS_SCRIPT" set frontend opencode >/dev/null
  [ -f "$TMPPREFS" ]
  run bash "$PREFS_SCRIPT" reset --confirm
  [ "$status" -eq 0 ]
  [ ! -f "$TMPPREFS" ]
}

@test "AC-1.2: subcommand 'reset' on absent file is graceful (no crash)" {
  run bash "$PREFS_SCRIPT" reset --confirm
  [ "$status" -eq 0 ]
  [[ "$output" == *"no preferences"* ]]
}

@test "AC-1.2: validate rejects forbidden credential keys (negative)" {
  cat > "$TMPPREFS" <<EOF
version: 1
api_key: should-not-be-here
EOF
  run bash "$PREFS_SCRIPT" validate
  [ "$status" -ne 0 ]
  [[ "$output" == *"FORBIDDEN"* ]]
}

@test "AC-1.2: validate detects missing version (negative — schema break)" {
  cat > "$TMPPREFS" <<EOF
frontend: opencode
EOF
  run bash "$PREFS_SCRIPT" validate
  [ "$status" -ne 0 ]
  [[ "$output" == *"MISSING"* ]]
}

@test "AC-1.2: unknown subcommand exits 2 (no-arg edge)" {
  run bash "$PREFS_SCRIPT" bogus
  [ "$status" -eq 2 ]
}

@test "AC-1.2: zero-arg shows usage (boundary)" {
  run bash "$PREFS_SCRIPT"
  [ "$status" -eq 2 ]
}

@test "AC-1.2: .claude/commands/savia-setup.md exists with frontmatter" {
  [ -f "$COMMAND_DOC" ]
  grep -q "^name: savia-setup" "$COMMAND_DOC"
  grep -q "^description:" "$COMMAND_DOC"
}

@test "AC-1.2: savia-setup command ≤ 150 lines (workspace cap)" {
  lines=$(wc -l < "$COMMAND_DOC")
  [ "$lines" -le 150 ]
}

@test "AC-1.2: savia-setup command references provider-agnostic + 8 questions" {
  grep -qE "8 preguntas|8 questions" "$COMMAND_DOC"
  grep -q "provider-agnostic" "$COMMAND_DOC"
  grep -q "preferences.yaml" "$COMMAND_DOC"
}

# ── AC-1.3 — model-alias-schema.md ─────────────────────────────────────────

@test "AC-1.3: model-alias-schema.md exists" {
  [ -f "$ALIAS_DOC" ]
}

@test "AC-1.3: model-alias-schema.md ≤ 150 lines (workspace cap)" {
  lines=$(wc -l < "$ALIAS_DOC")
  [ "$lines" -le 150 ]
}

@test "AC-1.3: schema documents top-level YAML keys" {
  for k in version frontend provider model_heavy model_mid model_fast \
           has_hooks has_task_fan_out has_slash_commands \
           budget_kind budget_limit auth_kind; do
    grep -q "$k" "$ALIAS_DOC"
  done
}

@test "AC-1.3: schema lists forbidden credential keys (PV-03)" {
  grep -q "api_key" "$ALIAS_DOC"
  grep -q "password" "$ALIAS_DOC"
  grep -q "secret" "$ALIAS_DOC"
  grep -q "token" "$ALIAS_DOC"
}

@test "AC-1.3: schema documents ≥3 stack examples (illustrative)" {
  count=$(grep -cE '^### [A-C]' "$ALIAS_DOC")
  [ "$count" -ge 3 ]
}

@test "AC-1.3: schema does NOT hardcode vendor names in normative sections" {
  # PV-06: examples can mention vendors, but the schema definition section
  # must say "free-form" or use placeholders, not pin a specific vendor.
  grep -qE "free-form|placeholder|<vendor" "$ALIAS_DOC"
}

# ── AC-1.4 — preferences respected when present + autodetect when absent ───

@test "AC-1.4: preferences file absent — defaults applied gracefully" {
  out=$(env -i SAVIA_PREFS_FILE="$TMPDIR_S/nonexistent.yaml" bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_PROVIDER")
  [ "$out" = "unknown" ]
}

@test "AC-1.4: preferences provider key wins over autodetect" {
  cat > "$TMPPREFS" <<EOF
version: 1
provider: my-custom-provider
EOF
  out=$(env -i SAVIA_PREFS_FILE="$TMPPREFS" CLAUDE_PROJECT_DIR=/tmp bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_PROVIDER")
  [ "$out" = "my-custom-provider" ]
}

@test "AC-1.4: preferences has_hooks=no overrides Claude Code autodetect" {
  cat > "$TMPPREFS" <<EOF
version: 1
has_hooks: no
EOF
  run env -i SAVIA_PREFS_FILE="$TMPPREFS" CLAUDE_PROJECT_DIR=/tmp bash -c "source '$ENV_SCRIPT'; savia_has_hooks; echo \$?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1" ]]
}

@test "AC-1.4: preferences has_task_fan_out=yes overrides default-no" {
  cat > "$TMPPREFS" <<EOF
version: 1
has_task_fan_out: yes
EOF
  run env -i SAVIA_PREFS_FILE="$TMPPREFS" bash -c "source '$ENV_SCRIPT'; savia_has_task_fan_out; echo \$?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0" ]]
}

@test "AC-1.4: explicit SAVIA_PROVIDER env wins over preferences" {
  cat > "$TMPPREFS" <<EOF
version: 1
provider: from-prefs
EOF
  out=$(env -i SAVIA_PREFS_FILE="$TMPPREFS" SAVIA_PROVIDER=from-env bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_PROVIDER")
  [ "$out" = "from-env" ]
}

@test "AC-1.4: zero hardcoded vendor names in env script (PV-06)" {
  # Any literal vendor name in source is a vendor lock-in (PV-06 violation).
  # Env script must reference only free-form classifications and standard env
  # var names. We check that no obvious commercial vendor brand appears.
  ! grep -qiE 'github.copilot|copilot.enterprise|openai\.|mistral\.|deepseek/|ollama/' "$ENV_SCRIPT"
}

@test "AC-1.4: zero hardcoded vendor names in preferences script (PV-06)" {
  ! grep -qiE 'github.copilot|copilot.enterprise|openai\.|mistral\.|deepseek/|ollama/' "$PREFS_SCRIPT"
}

# ── Spec ref + frontmatter ──────────────────────────────────────────────────

@test "spec ref: SPEC-127 file (provider-agnostic) exists with APPROVED status" {
  [ -f "$SPEC" ]
  grep -qE "^status: APPROVED" "$SPEC"
}

@test "spec ref: SPEC-127 declares slice_1_status IMPLEMENTED" {
  grep -qE "^slice_1_status: IMPLEMENTED" "$SPEC"
}

@test "spec ref: SPEC-127 referenced in this test file" {
  grep -q "docs/propuestas/SPEC-127" "$BATS_TEST_FILENAME"
}

@test "spec ref: SPEC-127 declares PV-06 (no vendor lock-in)" {
  grep -qE "PV-06" "$SPEC"
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: savia-env.sh sourced with empty environment defaults to pwd" {
  cd "$TMPDIR_S"
  out=$(env -i PATH="$PATH" bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_WORKSPACE_DIR")
  [ -n "$out" ]
}

@test "edge: provider 'unknown' boundary — zero signals present (no-arg env)" {
  cd "$TMPDIR_S"
  out=$(env -i PATH="$PATH" SAVIA_PREFS_FILE="$TMPDIR_S/none.yaml" bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_PROVIDER")
  [ "$out" = "unknown" ]
}

@test "edge: preferences file with nonexistent path is handled (boundary)" {
  out=$(env -i SAVIA_PREFS_FILE="$TMPDIR_S/never-existed.yaml" bash -c "source '$ENV_SCRIPT'; echo \$SAVIA_PROVIDER")
  [ "$out" = "unknown" ]
}

@test "edge: empty preferences file (zero bytes) is graceful" {
  : > "$TMPPREFS"
  run bash "$PREFS_SCRIPT" show
  [ "$status" -eq 0 ]
}

# ── Coverage ────────────────────────────────────────────────────────────────

@test "coverage: savia-env.sh exposes 4+ capability functions" {
  for fn in savia_workspace_dir savia_provider savia_has_hooks \
            savia_has_slash_commands savia_has_task_fan_out; do
    grep -qE "^${fn}\(\)" "$ENV_SCRIPT"
  done
}

@test "coverage: savia-preferences.sh has 6 subcommands" {
  for sub in init show get set reset validate; do
    grep -qE "^[[:space:]]*${sub}\)" "$PREFS_SCRIPT"
  done
}

@test "coverage: env script reads preferences file via _savia_pref helper" {
  grep -qE "_savia_pref\(\)" "$ENV_SCRIPT"
}

@test "coverage: env script never branches on a hardcoded vendor (PV-06)" {
  # Verify no `if [[ provider == "vendor-name" ]]` patterns
  ! grep -qE 'SAVIA_PROVIDER.*==.*"(claude|opencode|copilot|openai|mistral|ollama|deepseek)"' "$ENV_SCRIPT"
}
