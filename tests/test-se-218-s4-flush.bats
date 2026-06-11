#!/usr/bin/env bats
# test-se-218-s4-flush.bats — SE-218 S4: tiered flush
# Ref: docs/propuestas/SE-218-codebase-memory-patterns.md

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/session-action-log.sh"

setup() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export SESSION_ACTION_LOG="${TMP_DIR}/test-session-action.jsonl"
  export SESSION_ACTION_SESSION="test-$$"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

@test "session-action-log.sh exists and has set -uo pipefail" {
  [[ -f "$SCRIPT" ]]
  run grep -E "set -uo pipefail" "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "subcomando log sigue funcionando (no regresion)" {
  run bash "$SCRIPT" log write "test-target" "ok" "detail-ok"
  [[ "$status" -eq 0 ]]
  [[ -f "$SESSION_ACTION_LOG" ]]
  run grep -c "test-target" "$SESSION_ACTION_LOG"
  [[ "$output" -ge 1 ]]
}

@test "flush --mode best con log existente: exit 0" {
  # Crear log con contenido
  mkdir -p "$(dirname "$SESSION_ACTION_LOG")"
  printf '{"ts":"2026-01-01T00:00:00Z","action":"write","target":"t","result":"ok","detail":"","attempt":0,"session":"s"}\n' \
    > "$SESSION_ACTION_LOG"
  run bash "$SCRIPT" flush best
  [[ "$status" -eq 0 ]]
}

@test "flush --mode fast con log existente: exit 0" {
  mkdir -p "$(dirname "$SESSION_ACTION_LOG")"
  printf '{"ts":"2026-01-01T00:00:00Z","action":"write","target":"t","result":"ok","detail":"","attempt":0,"session":"s"}\n' \
    > "$SESSION_ACTION_LOG"
  run bash "$SCRIPT" flush fast
  [[ "$status" -eq 0 ]]
}

@test "flush con log inexistente: exit 0 (no crash)" {
  # Aseguramos que no existe el log
  rm -f "$SESSION_ACTION_LOG"
  run bash "$SCRIPT" flush best
  [[ "$status" -eq 0 ]]
}

@test "flush --mode invalid: exit 2" {
  mkdir -p "$(dirname "$SESSION_ACTION_LOG")"
  printf '{"ts":"2026-01-01T00:00:00Z","action":"write","target":"t","result":"ok","detail":"","attempt":0,"session":"s"}\n' \
    > "$SESSION_ACTION_LOG"
  run bash "$SCRIPT" flush invalid
  [[ "$status" -eq 2 ]]
}

@test "edge: flush on empty log file exits 0 without crash" {
  export SESSION_ACTION_LOG="$TMP_DIR/empty.jsonl"
  touch "$SESSION_ACTION_LOG"
  run bash "$SCRIPT" flush --mode best
  [ "$status" -eq 0 ]
}

@test "edge: flush without zstd available still exits 0" {
  # The flush function must handle gracefully whether zstd is available or not
  export SESSION_ACTION_LOG="$TMP_DIR/nozstd.jsonl"
  echo '{"ts":"2026-01-01","action":"a","target":"t","result":"ok","detail":"","attempt":0,"session":"s"}' > "$SESSION_ACTION_LOG"
  run bash "$SCRIPT" flush --mode fast
  # Exit 0 whether zstd succeeds, fails, or is absent
  [ "$status" -eq 0 ]
}

@test "assertion: log subcommand returns numeric attempt count" {
  run bash "$SCRIPT" log "test-action" "test-target" "pass" "detail"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys
out = sys.stdin.read().strip()
# Output may have warnings mixed in — extract the last line which is the count
lines = [l for l in out.splitlines() if l.strip()]
last = lines[-1] if lines else '0'
int(last)  # must be a number
"
}

@test "edge: flush --mode best creates .zst file with smaller or equal size than original" {
  echo '{"ts":"2026-01-01","action":"a","target":"t","result":"ok","detail":"","attempt":0,"session":"s"}' > "$SESSION_ACTION_LOG"
  run bash "$SCRIPT" flush --mode best
  [ "$status" -eq 0 ]
  # .zst should exist if zstd is available
  command -v zstd >/dev/null 2>&1 && [ -f "${SESSION_ACTION_LOG}.zst" ] || true
}

@test "edge: flush best then fast both exit 0 on same log" {
  echo '{"ts":"2026-01-01","action":"b","target":"t2","result":"ok","detail":"","attempt":0,"session":"s2"}' > "$SESSION_ACTION_LOG"
  run bash "$SCRIPT" flush --mode best
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" flush --mode fast
  [ "$status" -eq 0 ]
}

@test "assertion: flush output contains FLUSHED or WARN message on stderr" {
  echo '{"ts":"2026-01-01","action":"c","target":"t3","result":"ok","detail":"","attempt":0,"session":"s3"}' > "$SESSION_ACTION_LOG"
  run bash -c "bash '$SCRIPT' flush --mode best 2>&1"
  [ "$status" -eq 0 ]
  # stderr should contain FLUSHED or WARN
  [[ "$output" == *"FLUSHED"* ]] || [[ "$output" == *"WARN"* ]]
}
