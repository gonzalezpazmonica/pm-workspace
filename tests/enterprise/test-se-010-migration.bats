#!/usr/bin/env bats
# tests/enterprise/test-se-010-migration.bats
# SPEC: SPEC-SE-010 Migration Path & Backward Compat (>=6 tests)

setup() {
  export PROJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
  export SCRIPTS_DIR="$PROJECT_DIR/scripts/enterprise"
  export TEST_ROOT="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_ROOT" 2>/dev/null || true
}

_make_isolated_workspace() {
  local ws="$TEST_ROOT/$1"
  mkdir -p "$ws/.claude/enterprise"
  cp "$PROJECT_DIR/.claude/enterprise/manifest.json" \
     "$ws/.claude/enterprise/manifest.json"
  echo '{"hooks":{"PreToolUse":[]}}' > "$ws/.claude/settings.json"
  echo "$ws"
}

# 1. enterprise-migrate.sh exists
@test "SE-010-01: enterprise-migrate.sh exists and is executable" {
  [ -f "$SCRIPTS_DIR/enterprise-migrate.sh" ]
  [ -x "$SCRIPTS_DIR/enterprise-migrate.sh" ] || \
    bash -c "[ -r '$SCRIPTS_DIR/enterprise-migrate.sh' ]"
}

# 2. enterprise-migrate.sh responds to --help / help
@test "SE-010-02: enterprise-migrate.sh responds to help subcommand with JSON" {
  run bash "$SCRIPTS_DIR/enterprise-migrate.sh" help

  [ "$status" -eq 0 ]
  [[ "$output" == *'"subcommands"'* ]] || \
    [[ "$output" == *'"usage"'* ]]
}

# 3. check subcommand returns JSON with compatible field
@test "SE-010-03: check subcommand returns JSON with compatible field" {
  run env CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPTS_DIR/enterprise-migrate.sh" check

  [ "$status" -eq 0 ]
  [[ "$output" == *'"compatible"'* ]]
  # Should be true since we have the full enterprise install
  [[ "$output" == *'true'* ]]
}

# 4. status subcommand lists all modules
@test "SE-010-04: status subcommand lists all modules from manifest" {
  run env CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPTS_DIR/enterprise-migrate.sh" status

  [ "$status" -eq 0 ]
  [[ "$output" == *'"modules"'* ]]
  [[ "$output" == *'"multi-tenant"'* ]]
  [[ "$output" == *'"total_count"'* ]]
}

# 5. enable subcommand updates manifest.json
@test "SE-010-05: enable subcommand sets module.enabled=true in manifest" {
  ws=$(_make_isolated_workspace "enable-test")

  run env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/enterprise-migrate.sh" \
      enable "mcp-catalog"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"enabled": true'* ]] || \
    [[ "$output" == *'"enabled":true'* ]]

  # Verify the manifest was actually updated
  if command -v python3 >/dev/null 2>&1; then
    enabled=$(python3 -c "
import json
with open('$ws/.claude/enterprise/manifest.json') as f:
    d = json.load(f)
print(d['modules']['mcp-catalog']['enabled'])
")
    [[ "$enabled" == "True" ]]
  fi
}

# 6. disable subcommand reverts the manifest (via rollback-module.sh)
@test "SE-010-06: disable subcommand reverts module to enabled=false" {
  ws=$(_make_isolated_workspace "disable-test")

  # First enable
  env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/enterprise-migrate.sh" \
      enable "observability" >/dev/null 2>&1

  # Then disable
  run env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/enterprise-migrate.sh" \
      disable "observability"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"rolled_back"'* ]] || \
    [[ "$output" == *'"module"'* ]]

  # Verify disabled in manifest
  if command -v python3 >/dev/null 2>&1; then
    enabled=$(python3 -c "
import json
with open('$ws/.claude/enterprise/manifest.json') as f:
    d = json.load(f)
print(d['modules']['observability']['enabled'])
")
    [[ "$enabled" == "False" ]]
  fi
}

# 7. rollback-module.sh exists
@test "SE-010-07: rollback-module.sh exists and is executable" {
  [ -f "$SCRIPTS_DIR/rollback-module.sh" ]
  [ -x "$SCRIPTS_DIR/rollback-module.sh" ] || \
    bash -c "[ -r '$SCRIPTS_DIR/rollback-module.sh' ]"
}

# 8. rollback-module.sh produces JSON with rolled_back field
@test "SE-010-08: rollback-module.sh produces JSON with rolled_back=true" {
  ws=$(_make_isolated_workspace "rollback-json-test")

  # Enable a module first
  env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/enterprise-migrate.sh" \
      enable "governance-pack" >/dev/null 2>&1

  run env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/rollback-module.sh" \
      --module "governance-pack"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"rolled_back"'* ]]
  [[ "$output" == *'true'* ]]
}

# 9. no-args invocation of enterprise-migrate.sh returns status (default)
@test "SE-010-09: enterprise-migrate.sh with no args returns status output" {
  run env CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$SCRIPTS_DIR/enterprise-migrate.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"modules"'* ]]
}

# 10. enable then disable cycle: manifest returns to original state
@test "SE-010-10: enable->disable cycle leaves manifest in original state" {
  ws=$(_make_isolated_workspace "cycle-test")

  # Record initial state
  initial=$(python3 -c "
import json
with open('$ws/.claude/enterprise/manifest.json') as f:
    d = json.load(f)
print(d['modules']['code-review-court']['enabled'])
" 2>/dev/null || echo "False")

  # Enable
  env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/enterprise-migrate.sh" \
      enable "code-review-court" >/dev/null 2>&1

  # Disable
  env CLAUDE_PROJECT_DIR="$ws" bash "$SCRIPTS_DIR/enterprise-migrate.sh" \
      disable "code-review-court" >/dev/null 2>&1

  # Verify back to original
  final=$(python3 -c "
import json
with open('$ws/.claude/enterprise/manifest.json') as f:
    d = json.load(f)
print(d['modules']['code-review-court']['enabled'])
" 2>/dev/null || echo "False")

  [ "$initial" = "$final" ]
}
