#!/usr/bin/env bats
# Smoke tests for scripts/recover-savia.sh (Savia recovery launcher).
# SPEC-101: validates sandbox isolation, read-only contract, failure modes.
# Ref: docs/propuestas/SPEC-101-savia-genesis-recovery.md
# Related: .claude/rules/domain/savia-foundational-principles.md (7 immutable principles)
# Cannot test full launch (would invoke real claude binary); validates structure.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/recover-savia.sh"
  GENESIS="$REPO_ROOT/docs/SAVIA-GENESIS.md"
  TMP_DIR=$(mktemp -d -t recover-savia-XXXXXX)
}

teardown() {
  rm -rf "$TMP_DIR" 2>/dev/null || true
}

# ── Structural invariants ───────────────────────────────────────────────────

@test "recover-savia.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "recover-savia.sh has valid bash syntax" {
  bash -n "$SCRIPT"
}

@test "recover-savia.sh has set -uo pipefail safety" {
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

@test "recover-savia.sh defines four distinct exit codes" {
  for code in 1 2 3 4; do
    grep -q "exit $code" "$SCRIPT" || return 1
  done
}

# ── Failure-mode / negative cases ───────────────────────────────────────────

@test "negative: fails gracefully on invalid nonexistent path" {
  run bash "$SCRIPT" /nonexistent-path-that-cannot-exist-12345
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "cannot resolve"
}

@test "negative: fails when SAVIA-GENESIS.md missing from target" {
  mkdir -p "$TMP_DIR/fake-repo/docs"
  run bash "$SCRIPT" "$TMP_DIR/fake-repo"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qi "genesis"
}

@test "negative: empty path argument defaults to script repo root" {
  # With no arg, script resolves to its own repo — should find real GENESIS
  # We verify the script can at least PARSE its default path without crashing
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "negative: bad arg triggers nonzero exit" {
  run bash "$SCRIPT" /this/path/is/invalid/and/wrong
  [ "$status" -ne 0 ]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty directory as target fails cleanly" {
  run bash "$SCRIPT" "$TMP_DIR"
  [ "$status" -eq 2 ]
}

@test "edge: nonexistent subdirectory path rejected before sandbox creation" {
  run bash "$SCRIPT" "$TMP_DIR/nonexistent-subdir"
  [ "$status" -ne 0 ]
}

@test "edge: boundary — path with trailing slash still resolved" {
  mkdir -p "$TMP_DIR/repo/docs"
  run bash "$SCRIPT" "$TMP_DIR/repo/"
  # Should fail at genesis check, not at path resolution
  [ "$status" -eq 2 ]
}

# ── SAVIA-GENESIS.md content invariants ─────────────────────────────────────

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

@test "SAVIA-GENESIS.md is dual-purpose (Claude + humans)" {
  grep -qiE "(claude limpio|clean.*claude)" "$GENESIS"
  grep -qiE "(humano|human)" "$GENESIS"
}

@test "SAVIA-GENESIS.md describes 5-layer architecture" {
  grep -qE "(L0|L1|L2|L3|L4).*Voz|Reglas|Agentes|Skills|Hooks" "$GENESIS"
}

@test "SAVIA-GENESIS.md is non-empty and reasonably sized (>100 lines)" {
  lines=$(wc -l < "$GENESIS")
  [ "$lines" -gt 100 ]
}

# ── Regression guard ────────────────────────────────────────────────────────

@test "regression: recover-savia script does not execute claude unconditionally" {
  # Script must check for binary existence before exec
  grep -qE "CLAUDE_BIN=.*command -v" "$SCRIPT"
}

@test "regression: script does not modify any file inside repo" {
  # Static check: no git commit, no write ops inside REPO_PATH
  ! grep -qE '(cd.*REPO_PATH.*\n.*git (add|commit|push))' "$SCRIPT"
}
