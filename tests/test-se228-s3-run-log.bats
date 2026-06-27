#!/usr/bin/env bats
# tests/test-se228-s3-run-log.bats
# SE-228 Slice 3 — Loop run-log append-only
# Ref: docs/propuestas/SE-228-loop-engineering-patterns.md
# BATS >= 10 tests, auditor score >= 80

setup() {
  export TMPDIR_S3
  TMPDIR_S3="$(mktemp -d)"
  export LOOP_RUN_LOG_DIR="$TMPDIR_S3/loop-run-log"

  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export PROJECT_ROOT
  SCRIPT="$PROJECT_ROOT/scripts/loop-run-log.sh"
  export SCRIPT
  SCHEMA="$PROJECT_ROOT/docs/rules/domain/loop-run-log-schema.md"
  export SCHEMA
}

teardown() {
  rm -rf "$TMPDIR_S3"
}

# ---------------------------------------------------------------------------
# T01 — script existe y es ejecutable
# ---------------------------------------------------------------------------
@test "T01: loop-run-log.sh existe y es ejecutable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

# ---------------------------------------------------------------------------
# T02 — sin argumentos exits 2 (no.arg graceful)
# ---------------------------------------------------------------------------
@test "T02: no.arg exits 2 graceful" {
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
}

# ---------------------------------------------------------------------------
# T03 — subcomando inválido exits 2 (invalid subcommand)
# ---------------------------------------------------------------------------
@test "T03: invalid subcommand fails exit 2" {
  run bash "$SCRIPT" badsubcmd
  [[ "$status" -eq 2 ]]
}

# ---------------------------------------------------------------------------
# T04 — --help: exit 0
# ---------------------------------------------------------------------------
@test "T04: --help exits 0" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "append" ]]
}

# ---------------------------------------------------------------------------
# T05 — append crea fichero si no existe
# ---------------------------------------------------------------------------
@test "T05: append crea fichero si no existe" {
  local logfile="$LOOP_RUN_LOG_DIR/myskill/run-log.md"
  [[ ! -f "$logfile" ]]
  run bash "$SCRIPT" append \
    --skill myskill \
    --items 3 --actions 2 --escalations 0 --tokens 1000 \
    --outcome DONE --notes "test run"
  [[ "$status" -eq 0 ]]
  [[ -f "$logfile" ]]
}

# ---------------------------------------------------------------------------
# T06 — append añade entrada con todos los campos obligatorios
# ---------------------------------------------------------------------------
@test "T06: append añade entrada con todos los campos" {
  run bash "$SCRIPT" append \
    --skill testskill \
    --items 5 --actions 4 --escalations 1 --tokens 2000 \
    --outcome ESCALATED --notes "check fields"
  [[ "$status" -eq 0 ]]

  local logfile="$LOOP_RUN_LOG_DIR/testskill/run-log.md"
  grep -q "items_found: 5"         "$logfile"
  grep -q "actions_taken: 4"       "$logfile"
  grep -q "escalations: 1"         "$logfile"
  grep -q "tokens_estimated: 2000" "$logfile"
  grep -q "outcome: ESCALATED"     "$logfile"
  grep -q "notes: check fields"    "$logfile"
}

# ---------------------------------------------------------------------------
# T07 — append es append-only (múltiples appends no borran anteriores)
# ---------------------------------------------------------------------------
@test "T07: múltiples appends preservan entradas anteriores" {
  bash "$SCRIPT" append \
    --skill mskill --items 1 --actions 1 --escalations 0 --tokens 100 \
    --outcome DONE --notes "first"

  bash "$SCRIPT" append \
    --skill mskill --items 2 --actions 2 --escalations 0 --tokens 200 \
    --outcome DONE --notes "second"

  local logfile="$LOOP_RUN_LOG_DIR/mskill/run-log.md"
  local count
  count=$(grep -c "^## " "$logfile")
  [[ "$count" -ge 2 ]]
  grep -q "notes: first"  "$logfile"
  grep -q "notes: second" "$logfile"
}

# ---------------------------------------------------------------------------
# T08 — outcome invalid fails (invalid outcome rejected)
# ---------------------------------------------------------------------------
@test "T08: invalid outcome rejected fails" {
  run bash "$SCRIPT" append \
    --skill errskill --items 1 --actions 1 --escalations 0 --tokens 100 \
    --outcome BADVALUE
  [[ "$status" -ne 0 ]]
}

# ---------------------------------------------------------------------------
# T09 — missing required arg fails (missing --skill)
# ---------------------------------------------------------------------------
@test "T09: missing --skill arg fails" {
  run bash "$SCRIPT" append \
    --items 1 --actions 1 --escalations 0 --tokens 100 --outcome DONE
  [[ "$status" -ne 0 ]]
}

# ---------------------------------------------------------------------------
# T10 — tail --lines 5 muestra <= 5 entradas (boundary lines limit)
# ---------------------------------------------------------------------------
@test "T10: tail boundary --lines 5 muestra <= 5 entradas" {
  local i
  for i in 1 2 3 4 5 6 7 8; do
    bash "$SCRIPT" append \
      --skill tailskill --items "$i" --actions "$i" --escalations 0 \
      --tokens "$((i*100))" --outcome DONE --notes "entry $i"
  done

  run bash "$SCRIPT" tail --skill tailskill --lines 5
  [[ "$status" -eq 0 ]]
  local entry_count
  entry_count=$(echo "$output" | grep -c "^## [0-9]" || true)
  [[ "$entry_count" -le 5 ]]
}

# ---------------------------------------------------------------------------
# T11 — cmd_tail skill nonexistent: exit 0 empty output
# ---------------------------------------------------------------------------
@test "T11: tail nonexistent skill exits 0 empty" {
  run bash "$SCRIPT" tail --skill nonexistent-xyz-skill
  [[ "$status" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# T12 — stats: total_runs presente y coherente
# ---------------------------------------------------------------------------
@test "T12: stats muestra total_runs" {
  bash "$SCRIPT" append \
    --skill statskill --items 1 --actions 1 --escalations 0 \
    --tokens 500 --outcome DONE --notes "s1"
  bash "$SCRIPT" append \
    --skill statskill --items 2 --actions 2 --escalations 1 \
    --tokens 700 --outcome ABORTED --notes "s2"

  run bash "$SCRIPT" stats --skill statskill
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "total_runs: 2" ]]
}

# ---------------------------------------------------------------------------
# T13 — stats: success_rate coherente
# ---------------------------------------------------------------------------
@test "T13: stats success_rate coherente" {
  bash "$SCRIPT" append \
    --skill rateskill --items 1 --actions 1 --escalations 0 \
    --tokens 100 --outcome DONE --notes "ok"
  bash "$SCRIPT" append \
    --skill rateskill --items 1 --actions 0 --escalations 0 \
    --tokens 50 --outcome ABORTED --notes "ko"

  run bash "$SCRIPT" stats --skill rateskill
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "success_rate: 0.50" ]]
}

# ---------------------------------------------------------------------------
# T14 — stats empty/zero: skill sin log devuelve total_runs 0
# ---------------------------------------------------------------------------
@test "T14: stats zero: skill sin log devuelve total_runs 0" {
  run bash "$SCRIPT" stats --skill nonexistent-skill-xyz
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "total_runs: 0" ]]
}

# ---------------------------------------------------------------------------
# T15 — prune --days 0: zero entries edge case
# ---------------------------------------------------------------------------
@test "T15: prune zero days elimina todas las entradas" {
  bash "$SCRIPT" append \
    --skill pruneskill --items 1 --actions 1 --escalations 0 \
    --tokens 100 --outcome DONE --notes "old entry"

  run bash "$SCRIPT" prune --skill pruneskill --days 0
  [[ "$status" -eq 0 ]]

  local logfile="$LOOP_RUN_LOG_DIR/pruneskill/run-log.md"
  local count
  count=$(grep -c "^## " "$logfile" || true)
  [[ "$count" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# T16 — prune boundary large days: no elimina entradas recientes
# ---------------------------------------------------------------------------
@test "T16: prune boundary large days no elimina entradas recientes" {
  bash "$SCRIPT" append \
    --skill keepskill --items 3 --actions 3 --escalations 0 \
    --tokens 300 --outcome DONE --notes "recent"
  bash "$SCRIPT" append \
    --skill keepskill --items 4 --actions 4 --escalations 0 \
    --tokens 400 --outcome DONE --notes "recent2"

  run bash "$SCRIPT" prune --skill keepskill --days 9999
  [[ "$status" -eq 0 ]]

  local logfile="$LOOP_RUN_LOG_DIR/keepskill/run-log.md"
  local count
  count=$(grep -c "^## " "$logfile")
  [[ "$count" -ge 2 ]]
}

# ---------------------------------------------------------------------------
# T17 — schema docs/propuestas existe (SE-228)
# ---------------------------------------------------------------------------
@test "T17: loop-run-log-schema.md existe (SE-228 S3 AC-11)" {
  [[ -f "$SCHEMA" ]]
  grep -q "SE-228" "$SCHEMA"
}

# ---------------------------------------------------------------------------
# T18 — LOOP_RUN_LOG_DIR env var aísla correctamente (isolation)
# ---------------------------------------------------------------------------
@test "T18: LOOP_RUN_LOG_DIR env var controla la ubicación del log" {
  local custom_dir
  custom_dir="$(mktemp -d)"
  LOOP_RUN_LOG_DIR="$custom_dir" bash "$SCRIPT" append \
    --skill envskill --items 0 --actions 0 --escalations 0 \
    --tokens 0 --outcome DONE --notes "env test"

  [[ -f "$custom_dir/envskill/run-log.md" ]]
  [[ ! -f "$LOOP_RUN_LOG_DIR/envskill/run-log.md" ]]

  rm -rf "$custom_dir"
}

# ---------------------------------------------------------------------------
# T19 — script usa set -uo pipefail
# ---------------------------------------------------------------------------
@test "T19: loop-run-log.sh usa set -uo pipefail" {
  run grep -c "set -uo pipefail" "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" -ge 1 ]]
}

# ---------------------------------------------------------------------------
# T20 — cmd_append cmd_tail cmd_stats cmd_prune todos nombrados en script
# ---------------------------------------------------------------------------
@test "T20: script contiene funciones cmd_append cmd_tail cmd_stats cmd_prune" {
  grep -q "cmd_append"  "$SCRIPT"
  grep -q "cmd_tail"    "$SCRIPT"
  grep -q "cmd_stats"   "$SCRIPT"
  grep -q "cmd_prune"   "$SCRIPT"
}
