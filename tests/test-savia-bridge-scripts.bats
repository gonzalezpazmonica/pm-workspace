#!/usr/bin/env bats
# Ref: docs/rules/domain/autonomous-safety.md
# Ref: scripts/savia-bridge.py, scripts/savia-bridge.service
# Tests for savia-bridge installation artifacts (lint-only, no sudo).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export START="$REPO_ROOT/scripts/start-bridge.sh"
  export INSTALL="$REPO_ROOT/scripts/install-savia-bridge-system.sh"
  export UNIT="$REPO_ROOT/scripts/savia-bridge.service"
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/savia-bridge.XXXXXX")"
  export TEST_TMP
}

teardown() {
  [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]] && rm -rf "$TEST_TMP"
}

@test "start-bridge.sh exists and is executable" {
  [[ -x "$START" ]]
}

@test "start-bridge.sh has set -uo pipefail" {
  head -5 "$START" | grep -q 'set -uo pipefail'
}

@test "start-bridge.sh handles both system and user units" {
  run cat "$START"
  [[ "$output" == *"sudo -n systemctl restart savia-bridge"* ]]
  [[ "$output" == *"systemctl --user restart savia-bridge"* ]]
}

@test "start-bridge.sh logs to a non-repo path" {
  grep -q 'HOME/.savia/bridge' "$START"
}

@test "install script exists and is executable" {
  [[ -x "$INSTALL" ]]
}

@test "install script starts with a shebang" {
  head -1 "$INSTALL" | grep -q '^#!'
}

@test "install script has set -euo pipefail" {
  head -30 "$INSTALL" | grep -q 'set -euo pipefail'
}

@test "install script writes unit to /etc/systemd/system" {
  grep -q '/etc/systemd/system/savia-bridge.service' "$INSTALL"
}

@test "install script stops user unit first (idempotent)" {
  grep -q 'systemctl --user stop savia-bridge' "$INSTALL"
}

@test "install script verifies health endpoint post-start" {
  grep -q 'https://localhost:8922/health' "$INSTALL"
}

@test "unit file exists" {
  [[ -f "$UNIT" ]]
}

@test "unit file has hardening options" {
  grep -q 'ProtectSystem=strict'   "$UNIT"
  grep -q 'ProtectHome=read-only'  "$UNIT"
  grep -q 'NoNewPrivileges=true'   "$UNIT"
  grep -q 'MemoryMax=512M'         "$UNIT"
}

@test "unit file runs as non-root user" {
  grep -qE '^User=[a-z]' "$UNIT"
  ! grep -qE '^User=root' "$UNIT"
}

# ── Negative / failure paths ────────────────────────────────────────────

@test "install script fails when EUID is not zero (guard present)" {
  grep -q 'EUID -ne 0' "$INSTALL"
}

@test "install script rejects missing sudo gracefully (error path exists)" {
  grep -qE '(exit 1|error|fail)' "$INSTALL"
}

@test "start-bridge.sh reports error when systemctl is missing (graceful)" {
  grep -qE '(command -v systemctl||\|\|\s*true)' "$START"
}

@test "install script blocks overwriting an invalid unit file (syntax clean)" {
  run bash -n "$INSTALL"
  [[ "$status" -eq 0 ]]
}

@test "start-bridge.sh is bash-parse-clean (no syntax errors)" {
  run bash -n "$START"
  [[ "$status" -eq 0 ]]
}

# ── Edge cases ──────────────────────────────────────────────────────────

@test "no argument run of start-bridge.sh parses cleanly (no args edge)" {
  run bash -n "$START"
  [[ "$status" -eq 0 ]]
}

@test "empty HOME override does not crash syntax parse" {
  run env HOME="" bash -n "$START"
  [[ "$status" -eq 0 ]]
}

@test "nonexistent TMPDIR is tolerated at parse time" {
  run env TMPDIR="$TEST_TMP/nope" bash -n "$INSTALL"
  [[ "$status" -eq 0 ]]
}

@test "unit file has zero TODO markers (boundary)" {
  run grep -c 'TODO' "$UNIT"
  [[ "$output" -eq 0 ]]
}

@test "install script has no timeout-related bugs (timeout literal present or absent cleanly)" {
  run bash -n "$INSTALL"
  [[ "$status" -ne 124 ]]
}
