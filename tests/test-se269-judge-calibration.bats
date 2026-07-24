#!/usr/bin/env bats
# BATS tests for scripts/judge-calibration.sh (SE-269 S4)
# Ref: docs/specs/SE-269-bmad-patterns.spec.md

SCRIPT="scripts/judge-calibration.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Structure / safety ────────────────────────────────────────────────────

@test "SE269-S4: script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "SE269-S4: script has valid bash syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Dispose operation (AC-4.1) ────────────────────────────────────────────

@test "SE269-S4 AC-4.1: --dispose with valid params succeeds" {
  local cal_file; cal_file="$(mktemp)"
  run env CALIBRATION_FILE="$cal_file" bash "$SCRIPT" --dispose H001 aceptado
  [ "$status" -eq 0 ]
  rm -f "$cal_file"
}

@test "SE269-S4 AC-4.1: --dispose rejects invalid disposition" {
  run bash "$SCRIPT" --dispose H001 inventado
  [ "$status" -eq 1 ]
}

@test "SE269-S4 AC-4.1: --dispose records entry in calibration file" {
  local cal_file; cal_file="$(mktemp)"
  run env CALIBRATION_FILE="$cal_file" bash "$SCRIPT" --dispose H001 aceptado
  [ "$status" -eq 0 ]
  [[ -f "$cal_file" ]]
  run wc -l < "$cal_file"
  [[ "$output" -ge 1 ]]
  rm -f "$cal_file"
}

@test "SE269-S4 AC-4.1: all 4 dispositions are valid" {
  for d in aceptado descartado-nimiedad descartado-malentendido descartado-inexistente; do
    local cal_file; cal_file="$(mktemp)"
    run env CALIBRATION_FILE="$cal_file" bash "$SCRIPT" --dispose "T-$d" "$d"
    [ "$status" -eq 0 ]
    rm -f "$cal_file"
  done
}

# ── Report operation (AC-4.2) ─────────────────────────────────────────────

@test "SE269-S4 AC-4.2: --report with no data returns sin_datos" {
  local cal_file; cal_file="$(mktemp)"
  local fn_file; fn_file="$(mktemp)"
  run env CALIBRATION_FILE="$cal_file" FN_FILE="$fn_file" bash "$SCRIPT" --report test-judge
  [ "$status" -eq 0 ]
  [[ "$output" == *'"N": 0'* ]]
  rm -f "$cal_file" "$fn_file"
}

@test "SE269-S4 AC-4.2: --report with <25 entries returns sin_datos" {
  local cal_file; cal_file="$(mktemp)"
  local fn_file; fn_file="$(mktemp)"
  # Insert 10 dispositions
  for i in $(seq 1 10); do
    env CALIBRATION_FILE="$cal_file" bash "$SCRIPT" --dispose "H$i" aceptado 2>/dev/null
  done
  run env CALIBRATION_FILE="$cal_file" FN_FILE="$fn_file" bash "$SCRIPT" --report test-judge
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status": "sin_datos"'* ]]
  rm -f "$cal_file" "$fn_file"
}

@test "SE269-S4: FP counted as descartado-*" {
  local cal_file; cal_file="$(mktemp)"
  local fn_file; fn_file="$(mktemp)"
  for i in $(seq 1 20); do
    env CALIBRATION_FILE="$cal_file" bash "$SCRIPT" --dispose "H$i" aceptado 2>/dev/null
  done
  for i in $(seq 21 25); do
    env CALIBRATION_FILE="$cal_file" bash "$SCRIPT" --dispose "H$i" descartado-nimiedad 2>/dev/null
  done
  run env CALIBRATION_FILE="$cal_file" FN_FILE="$fn_file" bash "$SCRIPT" --report test-judge2
  [ "$status" -eq 0 ]
  rm -f "$cal_file" "$fn_file"
}

# ── FN recording (AC-4.4) ─────────────────────────────────────────────────

@test "SE269-S4 AC-4.4: --fn-record writes to FN file" {
  local cal_file; cal_file="$(mktemp)"
  local fn_file; fn_file="$(mktemp)"
  run env CALIBRATION_FILE="$cal_file" FN_FILE="$fn_file" bash "$SCRIPT" --fn-record FN001 security-judge "bug en produccion"
  [ "$status" -eq 0 ]
  [[ -f "$fn_file" ]]
  run wc -l < "$fn_file"
  [[ "$output" -ge 1 ]]
  rm -f "$cal_file" "$fn_file"
}

@test "SE269-S4 AC-4.4: FN record links to specific judge" {
  local cal_file; cal_file="$(mktemp)"
  local fn_file; fn_file="$(mktemp)"
  run env CALIBRATION_FILE="$cal_file" FN_FILE="$fn_file" bash "$SCRIPT" --fn-record FN002 correctness-judge "fallo de logica"
  [ "$status" -eq 0 ]
  run grep -q "correctness-judge" "$fn_file"
  [[ "$status" -eq 0 ]]
  rm -f "$cal_file" "$fn_file"
}

# ── Publish operation (AC-4.5: anti-Goodhart) ─────────────────────────────

@test "SE269-S4 AC-4.5: --publish includes both FP and FN data" {
  local cal_file; cal_file="$(mktemp)"
  local fn_file; fn_file="$(mktemp)"
  for i in $(seq 1 25); do
    env CALIBRATION_FILE="$cal_file" bash "$SCRIPT" --dispose "P$i" aceptado 2>/dev/null
  done
  env FN_FILE="$fn_file" bash "$SCRIPT" --fn-record FN001 pub-judge "escapo a prod" 2>/dev/null
  run env CALIBRATION_FILE="$cal_file" FN_FILE="$fn_file" bash "$SCRIPT" --publish pub-judge
  [ "$status" -eq 0 ]
  [[ "$output" == *'"fp_N"'* ]]
  rm -f "$cal_file" "$fn_file"
}

# ── Degrade / Restore (AC-4.3) ────────────────────────────────────────────

@test "SE269-S4 AC-4.3: --degrade records degradation" {
  local deg_file; deg_file="$(mktemp)"
  run env DEGRADATION_FILE="$deg_file" bash "$SCRIPT" --degrade test-judge "FP rate > 50%"
  [ "$status" -eq 0 ]
  [[ -f "$deg_file" ]]
  run grep -q '"accion": "degrade"' "$deg_file"
  [[ "$status" -eq 0 ]]
  rm -f "$deg_file"
}

@test "SE269-S4 AC-4.3: --restore records restoration" {
  local deg_file; deg_file="$(mktemp)"
  run env DEGRADATION_FILE="$deg_file" bash "$SCRIPT" --restore test-judge
  [ "$status" -eq 0 ]
  run grep -q '"accion": "restore"' "$deg_file"
  [[ "$status" -eq 0 ]]
  rm -f "$deg_file"
}

@test "SE269-S4 AC-4.3: degrade then restore is traceable" {
  local deg_file; deg_file="$(mktemp)"
  run env DEGRADATION_FILE="$deg_file" bash "$SCRIPT" --degrade cycle-judge "FP alta"
  [ "$status" -eq 0 ]
  run env DEGRADATION_FILE="$deg_file" bash "$SCRIPT" --restore cycle-judge
  [ "$status" -eq 0 ]
  run wc -l < "$deg_file"
  [[ "$output" -ge 2 ]]
  rm -f "$deg_file"
}

# ── Output JSON validity ──────────────────────────────────────────────────

@test "SE269-S4: --report output is valid JSON" {
  local cal_file; cal_file="$(mktemp)"
  local fn_file; fn_file="$(mktemp)"
  for i in $(seq 1 26); do
    env CALIBRATION_FILE="$cal_file" bash "$SCRIPT" --dispose "RJ$i" aceptado 2>/dev/null
  done
  run env CALIBRATION_FILE="$cal_file" FN_FILE="$fn_file" bash "$SCRIPT" --report json-judge
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool >/dev/null 2>&1
  [ "$?" -eq 0 ]
  rm -f "$cal_file" "$fn_file"
}
