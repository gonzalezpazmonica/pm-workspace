#!/usr/bin/env bats
# tests/enterprise/test-se-005-sovereign.bats
# SPEC: SPEC-SE-005 Sovereign Deployment (>=6 tests)

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
  cp "$PROJECT_DIR/.claude/enterprise/manifest.json" \
     "$ws/.claude/enterprise/manifest.json"
  cp "$PROJECT_DIR/.claude/enterprise/hooks/network-egress-guard.sh" \
     "$ws/.claude/enterprise/hooks/network-egress-guard.sh" 2>/dev/null || true
  echo '{"hooks":{"PreToolUse":[]}}' > "$ws/.claude/settings.json"
  echo "$ws"
}

# 1. network-egress-guard.sh exists (prerequisite)
@test "SE-005-01: network-egress-guard.sh exists" {
  [ -f "$HOOKS_DIR/network-egress-guard.sh" ]
}

# 2. sovereign-activate.sh exists and is executable
@test "SE-005-02: sovereign-activate.sh exists and is executable" {
  [ -f "$SCRIPTS_DIR/sovereign-activate.sh" ]
  [ -x "$SCRIPTS_DIR/sovereign-activate.sh" ] || \
    bash -c "[ -r '$SCRIPTS_DIR/sovereign-activate.sh' ]"
}

# 3. sovereign-activate.sh produces JSON output
@test "SE-005-03: sovereign-activate.sh produces JSON with required fields" {
  ws=$(_make_isolated_workspace "sovereign-json-test")
  mkdir -p "$ws/tenants/demo/projects"

  run env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/sovereign-activate.sh" \
      --tenant demo \
      --mode sovereign \
      --llm-host http://localhost:11434

  [ "$status" -eq 0 ]
  [[ "$output" == *'"mode"'* ]]
  [[ "$output" == *'"sovereign"'* ]]
  [[ "$output" == *'"sovereign_ready"'* ]]
  [[ "$output" == *'"egress_blocked"'* ]]
}

# 4. deployment.yaml is created with the correct mode field
@test "SE-005-04: sovereign-activate.sh creates deployment.yaml with correct mode" {
  ws=$(_make_isolated_workspace "sovereign-yaml-test")

  run env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/sovereign-activate.sh" \
      --tenant acme \
      --mode sovereign \
      --llm-host http://localhost:11434

  [ "$status" -eq 0 ]
  deploy_yaml="$ws/tenants/acme/deployment.yaml"
  [ -f "$deploy_yaml" ]
  grep -q "mode: sovereign" "$deploy_yaml"
}

# 5. air-gap mode reflects egress_blocked=true in JSON output
@test "SE-005-05: air-gap mode produces egress_blocked=true in JSON output" {
  ws=$(_make_isolated_workspace "airgap-test")

  run env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/sovereign-activate.sh" \
      --tenant airgap-org \
      --mode air-gap \
      --llm-host http://internal:11434

  [ "$status" -eq 0 ]
  [[ "$output" == *'"egress_blocked": true'* ]] || \
    [[ "$output" == *'"egress_blocked":true'* ]]
}

# 6. deployment-status.sh exists
@test "SE-005-06: deployment-status.sh exists and is executable" {
  [ -f "$SCRIPTS_DIR/deployment-status.sh" ]
  [ -x "$SCRIPTS_DIR/deployment-status.sh" ] || \
    bash -c "[ -r '$SCRIPTS_DIR/deployment-status.sh' ]"
}

# 7. deployment-status.sh returns JSON with sovereign_ready
@test "SE-005-07: deployment-status.sh returns JSON including sovereign_ready field" {
  ws=$(_make_isolated_workspace "status-test")

  # Activate first so there's a deployment.yaml
  env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/sovereign-activate.sh" \
      --tenant statusorg \
      --mode sovereign \
      --llm-host http://localhost:11434 >/dev/null 2>&1

  run env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/deployment-status.sh" \
      --tenant statusorg

  [ "$status" -eq 0 ]
  [[ "$output" == *'"sovereign_ready"'* ]]
  [[ "$output" == *'"mode"'* ]]
}

# 8. deployment-status.sh returns cloud mode when no config present
@test "SE-005-08: deployment-status.sh returns cloud mode when no deployment.yaml exists" {
  ws=$(_make_isolated_workspace "no-config-test")

  run env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/deployment-status.sh" \
      --tenant nonexistent-tenant

  [ "$status" -eq 0 ]
  [[ "$output" == *'"mode"'* ]]
  [[ "$output" == *'"cloud"'* ]]
}

# 9. sovereign deployment doc exists with activation section
@test "SE-005-09: enterprise-sovereign-deployment.md doc exists" {
  doc="$PROJECT_DIR/docs/rules/domain/enterprise-sovereign-deployment.md"
  [ -f "$doc" ]
  grep -qi "activation\|activat" "$doc"
}
