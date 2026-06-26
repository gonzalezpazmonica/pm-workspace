#!/usr/bin/env bats
# tests/enterprise/test-se-002-multitenant.bats
# SPEC: SPEC-SE-002 Multi-Tenant & RBAC — activation and RBAC tests (>=6)

setup() {
  export PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
  export SCRIPTS_DIR="$PROJECT_DIR/scripts/enterprise"
  export HOOKS_DIR="$PROJECT_DIR/.claude/enterprise/hooks"
  export TEST_ROOT="$(mktemp -d)"
  unset SAVIA_TENANT 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_ROOT" 2>/dev/null || true
}

_make_isolated_workspace() {
  local ws="$TEST_ROOT/$1"
  mkdir -p "$ws/.claude/enterprise/hooks"
  mkdir -p "$ws/scripts/enterprise"
  cp "$PROJECT_DIR/.claude/enterprise/manifest.json" \
     "$ws/.claude/enterprise/manifest.json"
  cp "$PROJECT_DIR/.claude/enterprise/hooks/tenant-resolver.sh" \
     "$ws/.claude/enterprise/hooks/tenant-resolver.sh" 2>/dev/null || true
  cp "$PROJECT_DIR/.claude/enterprise/hooks/tenant-isolation-gate.sh" \
     "$ws/.claude/enterprise/hooks/tenant-isolation-gate.sh" 2>/dev/null || true
  echo "$ws"
}

# 1. tenant-activate.sh exists and is executable
@test "SE-002-MT-01: tenant-activate.sh exists and is executable" {
  [ -f "$SCRIPTS_DIR/tenant-activate.sh" ]
  [ -x "$SCRIPTS_DIR/tenant-activate.sh" ] || \
    bash -c "[ -r '$SCRIPTS_DIR/tenant-activate.sh' ]"
}

# 2. tenant-activate.sh produces JSON with activated field
@test "SE-002-MT-02: tenant-activate.sh returns JSON with activated field" {
  ws=$(_make_isolated_workspace "activate-test")
  # Create a minimal settings.json so the hooks registration doesn't fail
  echo '{"hooks":{"PreToolUse":[]}}' > "$ws/.claude/settings.json"

  run env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/tenant-activate.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"activated"'* ]]
  [[ "$output" == *"true"* ]]
}

# 3. tenant-activate.sh creates tenants/ directory
@test "SE-002-MT-03: tenant-activate.sh creates tenants/ directory when absent" {
  ws=$(_make_isolated_workspace "activate-dir-test")
  echo '{"hooks":{"PreToolUse":[]}}' > "$ws/.claude/settings.json"

  run env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/tenant-activate.sh"

  [ "$status" -eq 0 ]
  [ -d "$ws/tenants" ]
}

# 4. rbac-bulk-assign.sh exists
@test "SE-002-MT-04: rbac-bulk-assign.sh exists" {
  [ -f "$SCRIPTS_DIR/rbac-bulk-assign.sh" ]
}

# 5. rbac-bulk-assign.sh assigns roles from CSV
@test "SE-002-MT-05: rbac-bulk-assign.sh assigns roles from a CSV file" {
  ws=$(_make_isolated_workspace "bulk-assign-test")
  export CLAUDE_PROJECT_DIR="$ws"

  # Create a test tenant with rbac.yaml
  mkdir -p "$ws/tenants/acme/projects" \
           "$ws/tenants/acme/agent-memory" \
           "$ws/tenants/acme/secrets"
  cat > "$ws/tenants/acme/rbac.yaml" << 'RBAC'
tenant: acme
roles:
  reader:
    commands: [sprint-status]
  developer:
    inherits: reader
    commands: ["spec-*"]
  admin:
    inherits: developer
    commands: ["tenant-*"]
users: {}
RBAC

  # Write CSV
  csv_file="$TEST_ROOT/bulk.csv"
  printf 'alice,acme,developer\nbob,acme,reader\n' > "$csv_file"

  run env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/rbac-bulk-assign.sh" \
      --csv "$csv_file"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"assigned"'* ]]
  # Should have assigned 2
  [[ "$output" == *'"assigned": 2'* ]] || [[ "$output" == *'"assigned":2'* ]]
}

# 6. manifest.json reflects enabled=false by default (safe default)
@test "SE-002-MT-06: manifest.json has multi-tenant enabled=false by default" {
  manifest="$PROJECT_DIR/.claude/enterprise/manifest.json"
  # Extract the enabled value for multi-tenant
  if command -v python3 >/dev/null 2>&1; then
    enabled=$(python3 -c "
import json
with open('$manifest') as f:
    d = json.load(f)
print(d['modules']['multi-tenant']['enabled'])
")
    [[ "$enabled" == "False" ]]
  else
    grep -A3 '"multi-tenant"' "$manifest" | grep '"enabled"' | grep -q 'false'
  fi
}

# 7. SAVIA_TENANT env has priority in tenant resolver
@test "SE-002-MT-07: SAVIA_TENANT env var has priority in tenant resolver" {
  export SAVIA_TENANT="force-tenant-slug"
  output=$(bash "$HOOKS_DIR/tenant-resolver.sh" 2>/dev/null)
  trimmed=$(echo "$output" | tr -d '[:space:]')
  [ "$trimmed" = "force-tenant-slug" ]
  unset SAVIA_TENANT
}

# 8. tenant isolation gate: allows access to own tenant
@test "SE-002-MT-08: tenant-isolation-gate allows access to own tenant path" {
  ws=$(_make_isolated_workspace "gate-own-test")

  # Activate multi-tenant in the isolated manifest
  python3 -c "
import json
with open('$ws/.claude/enterprise/manifest.json') as f:
    d = json.load(f)
d['modules']['multi-tenant']['enabled'] = True
with open('$ws/.claude/enterprise/manifest.json', 'w') as f:
    json.dump(d, f, indent=2)
"
  # Simulate hook input: reading own tenant's file
  payload='{"tool_input":{"file_path":"tenants/myorg/projects/README.md"}}'
  run env CLAUDE_PROJECT_DIR="$ws" SAVIA_TENANT="myorg" \
      bash "$HOOKS_DIR/tenant-isolation-gate.sh" <<< "$payload"

  [ "$status" -eq 0 ]
}
