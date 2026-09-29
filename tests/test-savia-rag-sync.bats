#!/usr/bin/env bats
# BATS tests for scripts/savia-rag-sync.sh — disparador programado de Savia RAG.
# Ref: SE-410 P3 (cron 6 h + checkpoint semanal) y P7 (status --check).

SCRIPT="scripts/savia-rag-sync.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  TMP="$(mktemp -d)"
  export SAVIA_RAG_LOG="$TMP/calls.log"
  # CLI falso: registra argumentos y simula códigos de salida.
  cat > "$TMP/fake-cli.sh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$SAVIA_RAG_LOG"
case "$*" in
  *"rag sync"*) exit "${FAKE_SYNC_RC:-0}" ;;
  *"rag status"*) exit "${FAKE_STATUS_RC:-0}" ;;
esac
EOF
  chmod +x "$TMP/fake-cli.sh"
  export SAVIA_RAG_CLI="$TMP/fake-cli.sh"
  export SAVIA_RAG_DOMES_FILE="$TMP/domes.json"
  echo '{"version":1,"domes":{}}' > "$SAVIA_RAG_DOMES_FILE"
}

teardown() {
  rm -rf "$TMP"
}

@test "script exists, is executable and uses set -uo pipefail" {
  [[ -x "$SCRIPT" ]]
  run grep -c 'set -uo pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "passes bash -n syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "--help documents usage and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--rebuild"* ]]
}

@test "default run: incremental sync --all then status --check" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run cat "$SAVIA_RAG_LOG"
  [[ "${lines[0]}" == *"rag sync --domes-file $SAVIA_RAG_DOMES_FILE --all"* ]]
  [[ "${lines[0]}" != *"--rebuild"* ]]
  [[ "${lines[1]}" == *"rag status --domes-file $SAVIA_RAG_DOMES_FILE --check"* ]]
}

@test "--rebuild forwards the weekly checkpoint flag" {
  run bash "$SCRIPT" --rebuild
  [ "$status" -eq 0 ]
  run grep -c -- "--all --rebuild" "$SAVIA_RAG_LOG"
  [ "$output" -eq 1 ]
}

@test "SLO alert from status --check propagates exit 2" {
  FAKE_STATUS_RC=2 run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "sync failure exits non-zero and still reports status" {
  FAKE_SYNC_RC=1 run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  run grep -c "rag status" "$SAVIA_RAG_LOG"
  [ "$output" -eq 1 ]
}

@test "lock held by another process (exit 3) is not a failure" {
  FAKE_SYNC_RC=3 run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"en curso"* ]]
}

@test "missing domes file fails with a clear message" {
  SAVIA_RAG_DOMES_FILE="$TMP/nope.json" run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no encontrado"* ]]
}

@test "unknown option is rejected" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 1 ]
}
