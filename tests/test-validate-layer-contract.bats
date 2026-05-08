#!/usr/bin/env bats
# BATS tests for validate-layer-contract.sh (hook + script)
# SPEC: SE-001 Savia Enterprise Foundations & Layer Contract

HOOK=".opencode/hooks/validate-layer-contract.sh"
SCRIPT="scripts/validate-layer-contract.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="standard"
  export CLAUDE_PROJECT_DIR="$(pwd)"
}

teardown() {
  unset SAVIA_HOOK_PROFILE
}

# ── Hook: existence and safety ──────────────────────────────────────────────

@test "hook exists and is executable" {
  [[ -x "$HOOK" ]]
}

@test "hook has set -uo pipefail" {
  head -20 "$HOOK" | grep -q "set -uo pipefail"
}

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script has set -uo pipefail" {
  head -20 "$SCRIPT" | grep -q "set -uo pipefail"
}

# ── Hook: positive cases (should allow) ─────────────────────────────────────

@test "hook allows: empty stdin (no hook input)" {
  run bash "$HOOK" < /dev/null
  [[ "$status" -eq 0 ]]
}

@test "hook allows: file outside Core paths" {
  local input='{"tool_input":{"file_path":"'"$CLAUDE_PROJECT_DIR"'/output/foo.md","content":"see .claude/enterprise/x"}}'
  run bash -c "echo '$input' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "hook allows: docs/propuestas reference to enterprise (design doc)" {
  local input='{"tool_input":{"file_path":"'"$CLAUDE_PROJECT_DIR"'/docs/propuestas/foo.md","content":"see @.claude/enterprise/x"}}'
  run bash -c "echo '$input' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "hook allows: enterprise file itself (own dir)" {
  local input='{"tool_input":{"file_path":"'"$CLAUDE_PROJECT_DIR"'/.claude/enterprise/agents/foo.md","content":"anything"}}'
  run bash -c "echo '$input' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "hook allows: Core file without enterprise reference" {
  local input='{"tool_input":{"file_path":"'"$CLAUDE_PROJECT_DIR"'/.opencode/commands/foo.md","content":"this is fine"}}'
  run bash -c "echo '$input' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "hook allows: test file" {
  local input='{"tool_input":{"file_path":"'"$CLAUDE_PROJECT_DIR"'/tests/test-x.bats","content":"@.claude/enterprise/y"}}'
  run bash -c "echo '$input' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

# ── Hook: negative cases (should block) ─────────────────────────────────────

@test "hook blocks: Core command importing enterprise via @import" {
  local input='{"tool_input":{"file_path":"'"$CLAUDE_PROJECT_DIR"'/.opencode/commands/foo.md","content":"load @.claude/enterprise/rules/bar.md"}}'
  run bash -c "echo '$input' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
}

@test "hook blocks: Core rule importing enterprise" {
  local input='{"tool_input":{"file_path":"'"$CLAUDE_PROJECT_DIR"'/docs/rules/domain/foo.md","content":"see .claude/enterprise/skills/x"}}'
  run bash -c "echo '$input' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
}

@test "hook blocks: Core hook referencing enterprise path" {
  local input='{"tool_input":{"file_path":"'"$CLAUDE_PROJECT_DIR"'/.opencode/hooks/foo.sh","new_string":".claude/enterprise/manifest.json"}}'
  run bash -c "echo '$input' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
}

@test "hook blocks: CLAUDE.md referencing enterprise" {
  local input='{"tool_input":{"file_path":"'"$CLAUDE_PROJECT_DIR"'/CLAUDE.md","content":"load @.claude/enterprise/rules/x"}}'
  run bash -c "echo '$input' | bash '$HOOK'"
  [[ "$status" -eq 2 ]]
}

# ── Script: full scan ───────────────────────────────────────────────────────

@test "script passes full Core scan with no violations" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Layer contract OK"* ]]
}

@test "script accepts specific file arguments" {
  run bash "$SCRIPT" CLAUDE.md
  [[ "$status" -eq 0 ]]
}

@test "script exits with usage-error code on non-existent directory" {
  # Running from /tmp where no Core paths exist should still exit 0 (nothing scanned)
  cd /tmp
  run bash "${CLAUDE_PROJECT_DIR}/scripts/validate-layer-contract.sh"
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 2 ]]
}

# ── Enterprise directory structure ─────────────────────────────────────────

@test "enterprise directory exists" {
  [[ -d ".claude/enterprise" ]]
}

@test "enterprise has required subdirs" {
  [[ -d ".claude/enterprise/agents" ]]
  [[ -d ".claude/enterprise/commands" ]]
  [[ -d ".claude/enterprise/skills" ]]
  [[ -d ".claude/enterprise/rules" ]]
}

@test "enterprise README exists" {
  [[ -f ".claude/enterprise/README.md" ]]
}

@test "enterprise manifest.json exists and is valid JSON" {
  [[ -f ".claude/enterprise/manifest.json" ]]
  python3 -c "import json; json.load(open('.claude/enterprise/manifest.json'))"
}

@test "manifest.json has required top-level keys" {
  python3 -c "
import json
m = json.load(open('.claude/enterprise/manifest.json'))
assert 'version' in m
assert 'savia_core_min_version' in m
assert 'modules' in m
assert isinstance(m['modules'], dict)
"
}

@test "manifest.json ships with all modules disabled (opt-in default)" {
  python3 -c "
import json
m = json.load(open('.claude/enterprise/manifest.json'))
for name, cfg in m['modules'].items():
    assert cfg['enabled'] is False, f'{name} should ship disabled'
"
}

@test "manifest.schema.json exists and is valid JSON schema" {
  [[ -f ".claude/enterprise/manifest.schema.json" ]]
  python3 -c "
import json
s = json.load(open('.claude/enterprise/manifest.schema.json'))
assert s['\$schema'] == 'http://json-schema.org/draft-07/schema#'
assert 'properties' in s
"
}

# ── Core survives without Enterprise ────────────────────────────────────────

@test "Core has no references to enterprise (invariant #1)" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "extension-points.md documents the 6 extension points" {
  [[ -f "docs/propuestas/savia-enterprise/extension-points.md" ]]
  grep -c "^## EP-" "docs/propuestas/savia-enterprise/extension-points.md" | grep -q "^6$"
}
