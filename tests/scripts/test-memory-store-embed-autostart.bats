#!/usr/bin/env bats
# Ref: SPEC-018 — memory-store.sh embedding-server lazy start.
# Regression: `search --mode grep` launched the server anyway, and the
# background process inherited stdin and bats' fd 3, so test suites hung
# until the timeout (test-memory-vector.bats: 900 s).

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/memory-store.sh"
  export PROJECT_ROOT="$BATS_TEST_TMPDIR/ws"
  mkdir -p "$PROJECT_ROOT/output"
  export STORE_FILE="$PROJECT_ROOT/output/.memory-store.jsonl"
  export SAVIA_VERIFIED_MEMORY_DISABLED=true
  SAVIA_TEST_MODE=true bash "$SCRIPT" save --type decision --title "Use Redis" --content "Cache layer" >/dev/null
  unset SAVIA_TEST_MODE SAVIA_EMBED_AUTOSTART
  # Stub interpreter: health check fails (exit 1); a server launch records the
  # fds it inherited and returns at once. Nothing real is started.
  LOG="$BATS_TEST_TMPDIR/stub.log"
  export LOG
  STUB="$BATS_TEST_TMPDIR/python-stub"
  cat > "$STUB" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  *embedding-server.py) { echo "launch"; ls -l /proc/$$/fd/; } >> "$LOG"; exit 0 ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$STUB"
  export SAVIA_MEMORY_PYTHON="$STUB"
  export SAVIA_EMBED_PORT=1
}

teardown() { cd /; }

wait_for_launch() {
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -s "$LOG" ]] && return 0
    sleep 0.3
  done
  return 1
}

@test "grep mode never launches the embedding server" {
  run bash "$SCRIPT" search "Redis" --mode grep
  [ "$status" -eq 0 ]
  [[ "$output" == *"Redis"* ]]
  sleep 0.5
  [ ! -e "$LOG" ]
}

@test "grep mode given as --mode=grep also skips the server" {
  run bash "$SCRIPT" search "Redis" --mode=grep
  sleep 0.5
  [ ! -e "$LOG" ]
}

@test "auto mode launches the server detached from stdin and fd 3" {
  run bash "$SCRIPT" search "Redis"
  wait_for_launch
  grep -q '^launch' "$LOG"
  grep -E ' 0 -> /dev/null$' "$LOG"
  ! grep -E ' 3 -> ' "$LOG"
}

@test "SAVIA_EMBED_AUTOSTART=false disables the launch (boundary)" {
  SAVIA_EMBED_AUTOSTART=false run bash "$SCRIPT" search "Redis"
  sleep 0.5
  [ ! -e "$LOG" ]
}

@test "empty query in grep mode does not launch the server" {
  run bash "$SCRIPT" search "" --mode grep
  sleep 0.5
  [ ! -e "$LOG" ]
}

@test "nonexistent server script is tolerated without launch" {
  grep -q '\[\[ -f "\$server_script" \]\] || return 0' "$SCRIPT"
}

@test "memory-store.sh keeps strict mode (set -euo pipefail)" {
  head -15 "$SCRIPT" | grep -qE 'set -e?uo pipefail'
}
