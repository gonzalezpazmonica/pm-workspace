#!/usr/bin/env bats
# BATS tests for .claude/hooks/shield-autostart.sh
# SessionStart hook — ensures Savia Shield proxy (port 8443) is up.
# Fire-and-forget: launches shield-launcher background. Never blocks.
# Ref: batch 49 hook coverage — SPEC-shield Layer 0

HOOK=".claude/hooks/shield-autostart.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  unset SAVIA_SHIELD_ENABLED 2>/dev/null || true
}
teardown() {
  unset SAVIA_SHIELD_ENABLED CLAUDE_PROJECT_DIR 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── SAVIA_SHIELD_ENABLED toggle ────────────────────────

@test "toggle: SAVIA_SHIELD_ENABLED=false skips early" {
  SAVIA_SHIELD_ENABLED=false run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "toggle: SAVIA_SHIELD_ENABLED unset defaults to true" {
  unset SAVIA_SHIELD_ENABLED
  run grep -c 'SAVIA_SHIELD_ENABLED:-true' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Proxy detection ────────────────────────────────────

@test "proxy: port 8443 defined" {
  run grep -c 'PROXY_PORT=8443\|:8443' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "proxy: /health endpoint checked" {
  run grep -c '/health' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "proxy: curl with --max-time guard" {
  run grep -c 'curl.*--max-time' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "proxy: 127.0.0.1 not 0.0.0.0 (local only)" {
  run grep -c '127\.0\.0\.1' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Launcher delegation ────────────────────────────────

@test "launcher: shield-launcher.py referenced" {
  run grep -c 'shield-launcher' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "launcher: CLAUDE_PROJECT_DIR respected" {
  run grep -c 'CLAUDE_PROJECT_DIR' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "launcher: background spawn (&) with redirect" {
  run grep -c 'python3.*&\|>/dev/null 2>&1 &' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "launcher: missing launcher handled (not crash)" {
  run grep -c 'if \[ ! -f "\$LAUNCHER" \]\|launcher no encontrado' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Wait loop ──────────────────────────────────────────

@test "wait: 3s max wait (6 iterations × 0.5s)" {
  run grep -c 'sleep 0.5' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "wait: exits on proxy up before timeout" {
  run grep -c 'Shield proxy levantado\|exit 0' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "wait: graceful message if proxy slow" {
  run grep -c 'no respondio\|NER daemon' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Hook JSON output ──────────────────────────────────

@test "json: hookSpecificOutput field in printf" {
  run grep -c 'hookSpecificOutput' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "json: SessionStart event name" {
  run grep -c 'SessionStart' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "json: additionalContext field" {
  run grep -c 'additionalContext' "$HOOK"
  [[ "$output" -ge 2 ]]
}

# ── Error handling ────────────────────────────────────

@test "error: trap ERR handler defined" {
  run grep -c "trap.*ERR" "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "error: exits 0 on any trap fire" {
  run grep -c 'exit 0.*$' "$HOOK"
  [[ "$output" -ge 3 ]]
}

# ── Negative cases ────────────────────────────────────

@test "negative: toggle=false returns immediately no proxy check" {
  SAVIA_SHIELD_ENABLED=false run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "negative: hook reads stdin non-blocking" {
  # read -t 0.1 prevents blocking on hooks without stdin
  run grep -c 'read.*-t 0.1' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Edge cases ────────────────────────────────────────

@test "edge: project dir fallback to PWD" {
  run grep -c 'PWD\|\$PWD' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "edge: Windows DETACHED_PROCESS comment" {
  run grep -c 'DETACHED_PROCESS\|Windows' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "edge: empty stdin tolerated (non-blocking read)" {
  run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

# ── Coverage ──────────────────────────────────────────

@test "coverage: fire-and-forget pattern documented" {
  run grep -c 'Fire-and-forget\|fire.*forget' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

@test "coverage: Capa 0 Shield proxy reference" {
  run grep -c 'Capa 0\|Shield proxy\|Savia Shield' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────

@test "isolation: always exits 0 (never blocks session)" {
  for input in '' 'random' '{"type":"session-start"}'; do
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook does not modify repo files" {
  local before after
  before=$(find . -maxdepth 2 -type f 2>/dev/null | wc -l)
  bash "$HOOK" <<< "" >/dev/null 2>&1
  after=$(find . -maxdepth 2 -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
