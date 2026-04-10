#!/usr/bin/env bats
# Ref: scripts/savia-bridge.py, scripts/savia-bridge.service
# Tests for savia-bridge installation artifacts (lint-only, no sudo).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "start-bridge.sh exists and is executable" {
  [[ -x "$REPO_ROOT/scripts/start-bridge.sh" ]]
}

@test "start-bridge.sh has set -uo pipefail" {
  head -5 "$REPO_ROOT/scripts/start-bridge.sh" | grep -q 'set -uo pipefail'
}

@test "start-bridge.sh handles both system and user units" {
  run cat "$REPO_ROOT/scripts/start-bridge.sh"
  [[ "$output" == *"sudo -n systemctl restart savia-bridge"* ]]
  [[ "$output" == *"systemctl --user restart savia-bridge"* ]]
}

@test "start-bridge.sh logs to a non-repo path" {
  grep -q 'HOME/.savia/bridge' "$REPO_ROOT/scripts/start-bridge.sh"
}

@test "install-savia-bridge-system.sh exists and is executable" {
  [[ -x "$REPO_ROOT/scripts/install-savia-bridge-system.sh" ]]
}

@test "install-savia-bridge-system.sh requires root" {
  grep -q 'EUID -ne 0' "$REPO_ROOT/scripts/install-savia-bridge-system.sh"
}

@test "install-savia-bridge-system.sh has set -euo pipefail" {
  head -30 "$REPO_ROOT/scripts/install-savia-bridge-system.sh" | grep -q 'set -euo pipefail'
}

@test "install-savia-bridge-system.sh writes the unit to /etc/systemd/system" {
  grep -q '/etc/systemd/system/savia-bridge.service' "$REPO_ROOT/scripts/install-savia-bridge-system.sh"
}

@test "install-savia-bridge-system.sh stops the user unit first (idempotent)" {
  grep -q 'systemctl --user stop savia-bridge' "$REPO_ROOT/scripts/install-savia-bridge-system.sh"
}

@test "install-savia-bridge-system.sh verifies health post-start" {
  grep -q 'https://localhost:8922/health' "$REPO_ROOT/scripts/install-savia-bridge-system.sh"
}

@test "savia-bridge.service points to the correct repo path" {
  grep -q '/home/monica/claude/scripts/savia-bridge.py' "$REPO_ROOT/scripts/savia-bridge.service"
}

@test "savia-bridge.service has hardening options" {
  local unit="$REPO_ROOT/scripts/savia-bridge.service"
  grep -q 'ProtectSystem=strict' "$unit"
  grep -q 'ProtectHome=read-only' "$unit"
  grep -q 'NoNewPrivileges=true' "$unit"
  grep -q 'MemoryMax=512M' "$unit"
}

@test "savia-bridge.service runs as monica (not root)" {
  grep -q '^User=monica' "$REPO_ROOT/scripts/savia-bridge.service"
}
