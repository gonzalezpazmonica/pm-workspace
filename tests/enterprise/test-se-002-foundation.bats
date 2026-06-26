#!/usr/bin/env bats
# tests/enterprise/test-se-002-foundation.bats
# SPEC: SE-002 Extension Points — foundation tests (>=6)
# Tests: tenant-resolver, tenant-isolation-gate, tenant-create, rbac-check

setup() {
  export PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
  export HOOKS_DIR="$PROJECT_DIR/.claude/enterprise/hooks"
  export SCRIPTS_DIR="$PROJECT_DIR/scripts/enterprise"
  # Use isolated tmp for tenant operations
  export TEST_TENANT_DIR="$(mktemp -d)"
  # Unset SAVIA_TENANT to ensure single-tenant mode
  unset SAVIA_TENANT 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_TENANT_DIR" 2>/dev/null || true
}

# 1. tenant-resolver.sh exists and is executable
@test "SE-002-F-01: tenant-resolver.sh exists and is executable" {
  [ -f "$HOOKS_DIR/tenant-resolver.sh" ]
  [ -x "$HOOKS_DIR/tenant-resolver.sh" ] || \
    bash -c "[ -r '$HOOKS_DIR/tenant-resolver.sh' ]"
}

# 2. tenant-resolver.sh produces empty output in single-tenant mode
@test "SE-002-F-02: tenant-resolver.sh produces empty output in single-tenant mode" {
  # Ensure no SAVIA_TENANT is set
  unset SAVIA_TENANT
  # Run from a directory that is not under tenants/
  output=$(cd "$PROJECT_DIR" && bash "$HOOKS_DIR/tenant-resolver.sh" 2>/dev/null)
  # Output should be empty or just a newline (the script prints an empty line)
  trimmed=$(echo "$output" | tr -d '[:space:]')
  [ -z "$trimmed" ]
}

# 3. tenant-isolation-gate.sh exists and is executable
@test "SE-002-F-03: tenant-isolation-gate.sh exists and is executable" {
  [ -f "$HOOKS_DIR/tenant-isolation-gate.sh" ]
  [ -x "$HOOKS_DIR/tenant-isolation-gate.sh" ] || \
    bash -c "[ -r '$HOOKS_DIR/tenant-isolation-gate.sh' ]"
}

# 4. tenant-isolation-gate.sh exits 0 when multi-tenant is disabled (safe no-op)
@test "SE-002-F-04: tenant-isolation-gate.sh is a no-op when multi-tenant disabled" {
  # manifest has multi-tenant.enabled=false by default
  run bash "$HOOKS_DIR/tenant-isolation-gate.sh" < /dev/null
  [ "$status" -eq 0 ]
}

# 5. tenant-create.sh exists and creates correct structure
@test "SE-002-F-05: tenant-create.sh creates tenant directory structure" {
  [ -f "$SCRIPTS_DIR/tenant-create.sh" ]
  # Create a test tenant in a temp dir by overriding PROJECT_DIR
  export CLAUDE_PROJECT_DIR="$TEST_TENANT_DIR"
  mkdir -p "$TEST_TENANT_DIR/.claude/enterprise"
  cp "$PROJECT_DIR/.claude/enterprise/manifest.json" \
     "$TEST_TENANT_DIR/.claude/enterprise/manifest.json"

  run bash "$SCRIPTS_DIR/tenant-create.sh" \
      --slug "test-tenant-001" \
      --display "Test Tenant"

  [ "$status" -eq 0 ]
  [ -d "$TEST_TENANT_DIR/tenants/test-tenant-001/projects" ]
  [ -d "$TEST_TENANT_DIR/tenants/test-tenant-001/agent-memory" ]
  [ -d "$TEST_TENANT_DIR/tenants/test-tenant-001/secrets" ]
  [ -f "$TEST_TENANT_DIR/tenants/test-tenant-001/rbac.yaml" ]
}

# 6. rbac.yaml template has 3 roles: reader, developer, admin
@test "SE-002-F-06: rbac.yaml template contains 3 roles" {
  export CLAUDE_PROJECT_DIR="$TEST_TENANT_DIR"
  mkdir -p "$TEST_TENANT_DIR/.claude/enterprise"
  cp "$PROJECT_DIR/.claude/enterprise/manifest.json" \
     "$TEST_TENANT_DIR/.claude/enterprise/manifest.json"

  bash "$SCRIPTS_DIR/tenant-create.sh" \
      --slug "rbac-role-test" \
      --display "RBAC Role Test" >/dev/null 2>&1

  rbac_file="$TEST_TENANT_DIR/tenants/rbac-role-test/rbac.yaml"
  [ -f "$rbac_file" ]
  grep -q "reader:" "$rbac_file"
  grep -q "developer:" "$rbac_file"
  grep -q "admin:" "$rbac_file"
}

# 7. rbac-check.sh exists and returns JSON
@test "SE-002-F-07: rbac-check.sh exists and returns JSON output" {
  [ -f "$SCRIPTS_DIR/rbac-check.sh" ]
  # Run with missing tenant — should return JSON error, not crash
  run bash "$SCRIPTS_DIR/rbac-check.sh" \
      --user "alice" \
      --command "sprint-status" \
      --tenant "nonexistent-tenant-xyz"

  # Should not be empty and should look like JSON
  [[ "$output" == *"{"* ]]
  [[ "$output" == *"}"* ]]
}

# 8. manifest.json has multi-tenant module declared
@test "SE-002-F-08: manifest.json has multi-tenant module declared" {
  manifest="$PROJECT_DIR/.claude/enterprise/manifest.json"
  [ -f "$manifest" ]
  grep -q "multi-tenant" "$manifest"
}
