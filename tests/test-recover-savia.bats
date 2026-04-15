#!/usr/bin/env bats
# Smoke tests for scripts/recover-savia.sh
# Cannot test full launch (would invoke real claude binary); validates structure.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/recover-savia.sh"
  GENESIS="$REPO_ROOT/docs/SAVIA-GENESIS.md"
}

@test "recover-savia.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "recover-savia.sh has valid bash syntax" {
  bash -n "$SCRIPT"
}

@test "recover-savia.sh has set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "recover-savia.sh references SAVIA-GENESIS.md" {
  grep -q "SAVIA-GENESIS.md" "$SCRIPT"
}

@test "recover-savia.sh uses TMPDIR-based sandbox (never inside repo)" {
  grep -qE 'SANDBOX=.*(TMPDIR|/tmp)' "$SCRIPT"
}

@test "recover-savia.sh detects missing claude binary" {
  grep -q "command -v claude" "$SCRIPT"
}

@test "recover-savia.sh declares read-only access intent in prompt" {
  grep -qiE "read.only|MAY NOT (write|modify)" "$SCRIPT"
}

@test "recover-savia.sh blocks destructive git commands in prompt" {
  grep -qE "MAY NOT.*(commit|push|reset|checkout)" "$SCRIPT"
}

@test "recover-savia.sh exits with distinct error codes" {
  # Verify all 4 exit codes are referenced
  for code in 1 2 3 4; do
    grep -q "exit $code" "$SCRIPT" || return 1
  done
}

@test "recover-savia.sh fails gracefully on bad path" {
  run bash "$SCRIPT" /nonexistent-path-that-cannot-exist-12345
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "cannot resolve"
}

@test "SAVIA-GENESIS.md exists at expected location" {
  [ -f "$GENESIS" ]
}

@test "SAVIA-GENESIS.md declares the 7 immutable principles" {
  grep -qE "(7 principios|7 principles)" "$GENESIS"
}

@test "SAVIA-GENESIS.md contains recovery playbook" {
  grep -qiE "recovery playbook|playbook de recuperaci" "$GENESIS"
}

@test "SAVIA-GENESIS.md references critical rules 1-25" {
  grep -qE "(Rule #|Regla #|reglas críticas|critical rules)" "$GENESIS"
}

@test "SAVIA-GENESIS.md is dual-purpose (mentions both Claude and humans)" {
  grep -qiE "(claude limpio|clean.*claude)" "$GENESIS"
  grep -qiE "(humano|human)" "$GENESIS"
}

@test "SAVIA-GENESIS.md describes the 5-layer architecture" {
  grep -qE "(L0|L1|L2|L3|L4).*Voz|Reglas|Agentes|Skills|Hooks" "$GENESIS"
}
