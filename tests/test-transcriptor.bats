#!/usr/bin/env bats
# test-transcriptor.bats — SE-308 Savia Transcriptor: integracion de scripts

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  export SAVIA_TRANSCRIPTOR_DIR="$(mktemp -d)"
  mkdir -p "$SAVIA_TRANSCRIPTOR_DIR/reuniones/2026-08-04-09-15"
  mkdir -p "$SAVIA_TRANSCRIPTOR_DIR/reuniones/2026-08-04-11-00"
  echo '{"digested": false, "transcribed": true}' > "$SAVIA_TRANSCRIPTOR_DIR/reuniones/2026-08-04-09-15/meta.json"
  echo '{"digested": true, "transcribed": true}' > "$SAVIA_TRANSCRIPTOR_DIR/reuniones/2026-08-04-11-00/meta.json"
}

teardown() {
  rm -rf "$SAVIA_TRANSCRIPTOR_DIR"
}

@test "SE-308: scan lista solo reuniones sin digerir" {
  run bash "$REPO_ROOT/scripts/transcriptor-scan.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-08-04-09-15"* ]]
  [[ "$output" != *"2026-08-04-11-00"* ]]
}

@test "SE-308: scan --all lista todas con estado" {
  run bash "$REPO_ROOT/scripts/transcriptor-scan.sh" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-08-04-09-15 digested=False"* ]]
  [[ "$output" == *"2026-08-04-11-00 digested=True"* ]]
}

@test "SE-308: scan sin directorio no falla" {
  export SAVIA_TRANSCRIPTOR_DIR="/tmp/inexistente-transcriptor-$RANDOM"
  run bash "$REPO_ROOT/scripts/transcriptor-scan.sh"
  [ "$status" -eq 0 ]
}

@test "SE-308: mark-digested marca la reunion" {
  bash "$REPO_ROOT/scripts/transcriptor-mark-digested.sh" 2026-08-04-09-15
  run bash "$REPO_ROOT/scripts/transcriptor-scan.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == "" ]] || [[ "$output" == *"No hay reuniones"* ]]
}

@test "SE-308: mark-digested requiere argumento" {
  run bash "$REPO_ROOT/scripts/transcriptor-mark-digested.sh"
  [ "$status" -ne 0 ]
}

@test "SE-308: mark-digested falla con carpeta inexistente" {
  run bash "$REPO_ROOT/scripts/transcriptor-mark-digested.sh" 2099-01-01-00-00
  [ "$status" -ne 0 ]
}
