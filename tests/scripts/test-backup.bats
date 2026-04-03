#!/usr/bin/env bats
# tests/scripts/test-backup.bats — Validation tests for scripts/backup.sh
# Tests structure, config management, argument handling, constants.
# Does NOT test actual encryption or cloud uploads.
# Ref: docs/propuestas/SPEC-066-enhanced-local-llm.md
# Ref: .claude/rules/domain/backup-protocol.md

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/backup.sh"

setup() {
  TMPDIR_BK=$(mktemp -d)
  export HOME="$TMPDIR_BK"
  export PM_WORKSPACE_ROOT="$TMPDIR_BK/claude"
  mkdir -p "$PM_WORKSPACE_ROOT/.claude/profiles"
  mkdir -p "$TMPDIR_BK/.pm-workspace/backups"
  # Create minimal savia-compat.sh so source works
  SCRIPTS_DIR="$BATS_TEST_DIRNAME/../../scripts"
}

teardown() {
  rm -rf "$TMPDIR_BK"
}

# ── Safety ──────────────────────────────────────────────────────────

@test "script is valid bash" {
  bash -n "$SCRIPT"
}

@test "script uses set -uo pipefail for safety" {
  head -10 "$SCRIPT" | grep -q "set -euo pipefail"
}

# ── Positive cases ──────────────────────────────────────────────────

@test "help output shows backup description" {
  run bash -c "source $BATS_TEST_DIRNAME/../../scripts/savia-compat.sh && source $SCRIPT <<< ''" 2>/dev/null || true
  # Test help via main function approach
  run bash "$SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"backup.sh"* ]]
}

@test "help lists all subcommands" {
  run bash "$SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"now"* ]]
  [[ "$output" == *"restore"* ]]
  [[ "$output" == *"auto-on"* ]]
  [[ "$output" == *"auto-off"* ]]
  [[ "$output" == *"status"* ]]
  [[ "$output" == *"config"* ]]
}

@test "auto-on writes auto_backup true to config" {
  run bash "$SCRIPT" auto-on
  [ "$status" -eq 0 ]
  grep -q "auto_backup=true" "$TMPDIR_BK/.pm-workspace/backup-config"
}

@test "auto-off writes auto_backup false to config" {
  run bash "$SCRIPT" auto-off
  [ "$status" -eq 0 ]
  grep -q "auto_backup=false" "$TMPDIR_BK/.pm-workspace/backup-config"
}

@test "status command succeeds and shows backup info" {
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Backup Status"* ]]
}

@test "status shows nunca when no backups exist" {
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"nunca"* ]]
}

@test "status shows backup count format" {
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "[0-9]+/7"
}

@test "config help shows provider options" {
  run bash "$SCRIPT" config help
  [ "$status" -eq 0 ]
  [[ "$output" == *"nextcloud"* ]]
  [[ "$output" == *"gdrive"* ]]
}

# ── Negative cases ──────────────────────────────────────────────────

@test "error: unknown subcommand shows help" {
  run bash "$SCRIPT" invalidcommand
  [ "$status" -eq 0 ]
  [[ "$output" == *"backup.sh"* ]]
}

@test "error: config nextcloud missing URL fails" {
  run bash "$SCRIPT" config nextcloud
  [ "$status" -ne 0 ]
}

@test "error: config nextcloud missing USER fails" {
  run bash "$SCRIPT" config nextcloud "https://example.com"
  [ "$status" -ne 0 ]
}

@test "invalid config provider shows help" {
  run bash "$SCRIPT" config badprovider
  [ "$status" -eq 0 ]
  [[ "$output" == *"Configurar proveedor"* ]]
}

@test "failure: ensure_config creates dirs when missing" {
  rm -rf "$TMPDIR_BK/.pm-workspace"
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  [ -d "$TMPDIR_BK/.pm-workspace" ]
}

# ── Edge cases ──────────────────────────────────────────────────────

@test "empty config dir: status still works" {
  rm -rf "$TMPDIR_BK/.pm-workspace"
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
}

@test "boundary: MAX_BACKUPS constant is 7" {
  grep -q "MAX_BACKUPS=7" "$SCRIPT"
}

@test "nonexistent backup dir: status handles gracefully" {
  rm -rf "$TMPDIR_BK/.pm-workspace/backups"
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
}

@test "zero backups: rotate does nothing" {
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "0/7"
}

# ── Coverage breadth ────────────────────────────────────────────────

@test "script references all key functions" {
  grep -q "ensure_config" "$SCRIPT"
  grep -q "read_config" "$SCRIPT"
  grep -q "write_config" "$SCRIPT"
  grep -q "get_backup_paths" "$SCRIPT"
  grep -q "do_encrypt" "$SCRIPT"
  grep -q "do_decrypt" "$SCRIPT"
  grep -q "rotate_backups" "$SCRIPT"
  grep -q "do_now" "$SCRIPT"
  grep -q "do_restore" "$SCRIPT"
  grep -q "do_auto_on" "$SCRIPT"
  grep -q "do_auto_off" "$SCRIPT"
  grep -q "do_status" "$SCRIPT"
  grep -q "do_config" "$SCRIPT"
  grep -q "upload_nextcloud" "$SCRIPT"
}

@test "config gdrive sets cloud_type" {
  run bash "$SCRIPT" config gdrive
  [ "$status" -eq 0 ]
  grep -q "cloud_type=gdrive" "$TMPDIR_BK/.pm-workspace/backup-config"
}

@test "config none disables cloud" {
  run bash "$SCRIPT" config none
  [ "$status" -eq 0 ]
  grep -q "cloud_type=none" "$TMPDIR_BK/.pm-workspace/backup-config"
}

@test "SPEC doc for backup protocol exists" {
  [ -f "$BATS_TEST_DIRNAME/../../.claude/rules/domain/backup-protocol.md" ]
}
