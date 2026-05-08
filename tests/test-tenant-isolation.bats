#!/usr/bin/env bats
# BATS tests for tenant-isolation-gate.sh and tenant-resolver.sh
# SCRIPT=.claude/enterprise/hooks/tenant-isolation-gate.sh
# TARGET=.claude/enterprise/hooks/tenant-isolation-gate.sh
# SPEC: SPEC-SE-002 Multi-Tenant & RBAC
# Quality gate: SPEC-055 (audit score >= 80/100)

GATE=".claude/enterprise/hooks/tenant-isolation-gate.sh"
RESOLVER=".claude/enterprise/hooks/tenant-resolver.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  FAKE_ROOT=$(mktemp -d)
  export FAKE_ROOT
  mkdir -p "$FAKE_ROOT/.claude/enterprise/hooks" \
           "$FAKE_ROOT/tenants/tenant-a" \
           "$FAKE_ROOT/tenants/tenant-b" \
           "$FAKE_ROOT/output" \
           "$FAKE_ROOT/.claude/profiles/users/alice"
  cp "$GATE" "$FAKE_ROOT/.claude/enterprise/hooks/"
  cp "$RESOLVER" "$FAKE_ROOT/.claude/enterprise/hooks/"
  chmod +x "$FAKE_ROOT/.claude/enterprise/hooks/"*.sh
  export CLAUDE_PROJECT_DIR="$FAKE_ROOT"
  unset SAVIA_TENANT
}

teardown() {
  unset SAVIA_TENANT CLAUDE_PROJECT_DIR FAKE_ROOT
}

enable_module() {
  printf '{"modules":{"multi-tenant":{"enabled":true}}}\n' \
    > "$FAKE_ROOT/.claude/enterprise/manifest.json"
}

disable_module() {
  printf '{"modules":{"multi-tenant":{"enabled":false}}}\n' \
    > "$FAKE_ROOT/.claude/enterprise/manifest.json"
}

# Helper: invoke the gate with a JSON payload via stdin
invoke_gate() {
  local payload="$1"
  printf '%s' "$payload" | bash "$FAKE_ROOT/.claude/enterprise/hooks/tenant-isolation-gate.sh"
}
export -f invoke_gate 2>/dev/null || true

@test "gate script exists and is executable" {
  [[ -x "$GATE" ]]
}

@test "resolver script exists and is executable" {
  [[ -x "$RESOLVER" ]]
}

@test "gate has set -uo pipefail safety header" {
  head -20 "$GATE" | grep -q "set -uo pipefail"
}

@test "resolver has set -uo pipefail safety header" {
  head -20 "$RESOLVER" | grep -q "set -uo pipefail"
}

@test "gate is no-op when multi-tenant module disabled" {
  disable_module
  export SAVIA_TENANT=tenant-a
  run invoke_gate '{"tool_input":{"file_path":"tenants/tenant-b/x.md"}}'
  [[ "$status" -eq 0 ]]
}

@test "gate is no-op when no manifest exists" {
  rm -f "$FAKE_ROOT/.claude/enterprise/manifest.json"
  export SAVIA_TENANT=tenant-a
  run invoke_gate '{"tool_input":{"file_path":"tenants/tenant-b/x.md"}}'
  [[ "$status" -eq 0 ]]
}

@test "gate is no-op when no active tenant (single-tenant mode)" {
  enable_module
  run invoke_gate '{"tool_input":{"file_path":"tenants/tenant-a/foo.md"}}'
  [[ "$status" -eq 0 ]]
}

@test "negative: blocks cross-tenant read with exit 2" {
  enable_module
  export SAVIA_TENANT=tenant-a
  run invoke_gate '{"tool_input":{"file_path":"tenants/tenant-b/secret.md"}}'
  [[ "$status" -eq 2 ]]
}

@test "negative: blocks cross-tenant write with absolute path" {
  enable_module
  export SAVIA_TENANT=tenant-a
  run invoke_gate '{"tool_input":{"file_path":"/abs/tenants/tenant-b/data.yaml"}}'
  [[ "$status" -eq 2 ]]
}

@test "positive: allows own-tenant access" {
  enable_module
  export SAVIA_TENANT=tenant-a
  run invoke_gate '{"tool_input":{"file_path":"tenants/tenant-a/own.md"}}'
  [[ "$status" -eq 0 ]]
}

@test "positive: allows access to .claude/ core dir" {
  enable_module
  export SAVIA_TENANT=tenant-a
  run invoke_gate '{"tool_input":{"file_path":".opencode/commands/foo.md"}}'
  [[ "$status" -eq 0 ]]
}

@test "positive: allows access to scripts/ core dir" {
  enable_module
  export SAVIA_TENANT=tenant-a
  run invoke_gate '{"tool_input":{"file_path":"scripts/helper.sh"}}'
  [[ "$status" -eq 0 ]]
}

@test "positive: allows access to docs/ core dir" {
  enable_module
  export SAVIA_TENANT=tenant-a
  run invoke_gate '{"tool_input":{"file_path":"docs/readme.md"}}'
  [[ "$status" -eq 0 ]]
}

@test "positive: allows access to tests/ core dir" {
  enable_module
  export SAVIA_TENANT=tenant-a
  run invoke_gate '{"tool_input":{"file_path":"tests/foo.bats"}}'
  [[ "$status" -eq 0 ]]
}

@test "audit log entry includes tenant_id and BLOCK verdict" {
  enable_module
  export SAVIA_TENANT=tenant-a
  invoke_gate '{"tool_input":{"file_path":"tenants/tenant-b/x.md"}}' || true
  [[ -f "$FAKE_ROOT/output/tenant-audit.jsonl" ]]
  grep -q '"tenant_id":"tenant-a"' "$FAKE_ROOT/output/tenant-audit.jsonl"
  grep -q '"verdict":"BLOCK"' "$FAKE_ROOT/output/tenant-audit.jsonl"
}

@test "edge: malformed JSON stdin handled gracefully" {
  enable_module
  export SAVIA_TENANT=tenant-a
  run invoke_gate '{not valid json'
  [[ "$status" -eq 0 ]]
}

@test "edge: empty stdin handled gracefully" {
  enable_module
  export SAVIA_TENANT=tenant-a
  run invoke_gate ''
  [[ "$status" -eq 0 ]]
}

@test "resolver: env var SAVIA_TENANT takes precedence" {
  export SAVIA_TENANT=precedence-wins
  run bash "$RESOLVER"
  [[ "$output" == "precedence-wins" ]]
}

@test "resolver: detects tenant from cwd under tenants/" {
  local here
  here=$(pwd)
  mkdir -p "$FAKE_ROOT/tenants/cwd-tenant/sub"
  cd "$FAKE_ROOT/tenants/cwd-tenant/sub" || return 1
  result=$(bash "$here/$RESOLVER")
  cd "$here" || true
  [[ "$result" == "cwd-tenant" ]]
}

@test "resolver: falls back to empty when nothing resolves" {
  local here
  here=$(pwd)
  cd "$FAKE_ROOT" || return 1
  result=$(bash "$here/$RESOLVER")
  cd "$here" || true
  [[ -z "$result" ]]
}

@test "resolver: detects tenant from user profile identity.md" {
  printf 'active_slug: alice\n' > "$FAKE_ROOT/.claude/profiles/active-user.md"
  printf 'name: alice\ntenant: profile-tenant\n' > "$FAKE_ROOT/.claude/profiles/users/alice/identity.md"
  local here
  here=$(pwd)
  cd "$FAKE_ROOT" || return 1
  result=$(bash "$here/$RESOLVER")
  cd "$here" || true
  [[ "$result" == "profile-tenant" ]]
}
