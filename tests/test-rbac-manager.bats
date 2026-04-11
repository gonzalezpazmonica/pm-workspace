#!/usr/bin/env bats
# BATS tests for rbac-manager.sh
# SCRIPT=scripts/rbac-manager.sh
# SPEC: SPEC-SE-002 Multi-Tenant & RBAC
# Quality gate: SPEC-055 (audit score >= 80/100)

SCRIPT="scripts/rbac-manager.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  FAKE_ROOT=$(mktemp -d)
  export FAKE_ROOT
  mkdir -p "$FAKE_ROOT/tenants/acme-corp"
  export CLAUDE_PROJECT_DIR="$FAKE_ROOT"
}

teardown() {
  unset FAKE_ROOT CLAUDE_PROJECT_DIR SAVIA_TENANT
}

rbac() {
  bash "$SCRIPT" --project-dir "$FAKE_ROOT" --tenant acme-corp "$@"
}

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script has set -uo pipefail safety header" {
  head -20 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "grant creates rbac.yaml with user in role" {
  run rbac grant developer alice
  [[ "$status" -eq 0 ]]
  [[ -f "$FAKE_ROOT/tenants/acme-corp/rbac.yaml" ]]
  grep -q 'alice' "$FAKE_ROOT/tenants/acme-corp/rbac.yaml"
}

@test "grant is idempotent: repeating does not duplicate" {
  rbac grant developer alice
  rbac grant developer alice
  rbac grant developer alice
  count=$(grep -c 'alice' "$FAKE_ROOT/tenants/acme-corp/rbac.yaml")
  [[ "$count" -eq 1 ]]
}

@test "grant multiple users to same role" {
  rbac grant developer alice
  rbac grant developer bob
  grep -q 'alice' "$FAKE_ROOT/tenants/acme-corp/rbac.yaml"
  grep -q 'bob' "$FAKE_ROOT/tenants/acme-corp/rbac.yaml"
}

@test "revoke removes user from role" {
  rbac grant developer alice
  rbac revoke developer alice
  run grep 'alice' "$FAKE_ROOT/tenants/acme-corp/rbac.yaml"
  [[ "$status" -ne 0 ]]
}

@test "revoke nonexistent user is a no-op (exit 0)" {
  rbac grant developer alice
  run rbac revoke developer nobody
  [[ "$status" -eq 0 ]]
  grep -q 'alice' "$FAKE_ROOT/tenants/acme-corp/rbac.yaml"
}

@test "list prints tenant header and roles" {
  rbac grant reader alice
  run rbac list
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Tenant: acme-corp" ]]
  [[ "$output" =~ "role: reader" ]]
  [[ "$output" =~ "role: developer" ]]
}

@test "check returns exit 0 for allowed command (direct)" {
  rbac grant reader alice
  run rbac check alice sprint-status
  [[ "$status" -eq 0 ]]
}

@test "check returns exit 1 for denied command" {
  rbac grant reader alice
  run rbac check alice tenant-create
  [[ "$status" -eq 1 ]]
}

@test "check supports glob patterns (spec-* matches spec-generate)" {
  rbac grant developer alice
  run rbac check alice spec-generate
  [[ "$status" -eq 0 ]]
}

@test "role inheritance: developer inherits reader commands" {
  rbac grant developer alice
  run rbac check alice sprint-status
  [[ "$status" -eq 0 ]]
}

@test "role inheritance: admin inherits developer and reader commands" {
  rbac grant admin alice
  run rbac check alice sprint-status
  [[ "$status" -eq 0 ]]
  run rbac check alice spec-generate
  [[ "$status" -eq 0 ]]
  run rbac check alice tenant-create
  [[ "$status" -eq 0 ]]
}

@test "check fails for user not in any role" {
  run rbac check ghost sprint-status
  [[ "$status" -eq 1 ]]
}

@test "missing arguments produce usage error" {
  run bash "$SCRIPT" --project-dir "$FAKE_ROOT" --tenant acme-corp grant
  [[ "$status" -eq 2 ]]
}

@test "missing tenant produces error" {
  unset SAVIA_TENANT
  run bash "$SCRIPT" --project-dir "$FAKE_ROOT" list
  [[ "$status" -eq 2 ]]
}
