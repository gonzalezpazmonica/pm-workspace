#!/usr/bin/env bats
# test-context-rot-strategy.bats — skill context-rot-strategy (SE-069)
# Ref: docs/propuestas/SE-069-context-rot-strategy-skill.md
# Ref: .claude/skills/context-rot-strategy/SKILL.md
# El advisor de la skill es el modo --rot de context-meter.sh (SE-219 S2):
# bandas 60/75/90 → continue | plan-cut | compact | clear.
# Entradas invalidas → exit 2 sin consejo. Sin datos → continue-with-caution.
SCRIPT="scripts/context-meter.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  unset CONTEXT_WINDOW_USED CONTEXT_WINDOW_MAX CONTEXT_PCT 2>/dev/null || true
  unset CONTEXT_ROT_YELLOW CONTEXT_ROT_RED CONTEXT_ROT_CRITICAL 2>/dev/null || true
  # Nunca leer un snapshot real del usuario: ruta controlada e inexistente
  export CONTEXT_METER_SNAPSHOT="$TMP_DIR/no-snapshot.json"
  cd "$REPO_ROOT"
}

teardown() {
  rm -rf "$TMP_DIR"
}

rot() { bash "$REPO_ROOT/$SCRIPT" --rot "$@"; }

json_field() {
  python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)"
}

# ── Seguridad del objetivo ────────────────────────────────────────────────────
@test "target script declares set -uo pipefail" {
  run grep -c '^set -uo pipefail' "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── Bandas documentadas en SKILL.md (positivos) ───────────────────────────────
@test "rot: 59 percent is verde and continue" {
  run rot --pct 59
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_ROT_BAND=verde"* ]]
  [[ "$output" == *"CONTEXT_ROT_ACTION=continue"* ]]
}

@test "rot: boundary 60 percent is amarillo and plan-cut" {
  run rot --pct 60
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_ROT_BAND=amarillo"* ]]
  [[ "$output" == *"CONTEXT_ROT_ACTION=plan-cut"* ]]
}

@test "rot: boundary 74 stays amarillo, 75 becomes rojo and compact" {
  run rot --pct 74
  [[ "$output" == *"CONTEXT_ROT_BAND=amarillo"* ]]
  run rot --pct 75
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_ROT_BAND=rojo"* ]]
  [[ "$output" == *"CONTEXT_ROT_ACTION=compact"* ]]
}

@test "rot: boundary 89 stays rojo, 90 becomes critico and clear" {
  run rot --pct 89
  [[ "$output" == *"CONTEXT_ROT_BAND=rojo"* ]]
  run rot --pct 90
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_ROT_BAND=critico"* ]]
  [[ "$output" == *"CONTEXT_ROT_ACTION=clear"* ]]
}

@test "rot: boundary zero and 100 percent are valid extremes" {
  run rot --pct 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_ROT_BAND=verde"* ]]
  run rot --pct 100
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_ROT_BAND=critico"* ]]
}

@test "rot: tokens from env compute floor pct (149999 of 200000 is 74, amarillo)" {
  run env CONTEXT_WINDOW_USED=149999 CONTEXT_WINDOW_MAX=200000 bash "$SCRIPT" --rot
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_PCT=74"* ]]
  [[ "$output" == *"CONTEXT_ROT_BAND=amarillo"* ]]
}

@test "rot: CONTEXT_PCT env is accepted and --pct wins over it" {
  run env CONTEXT_PCT=95 bash "$SCRIPT" --rot
  [[ "$output" == *"CONTEXT_ROT_BAND=critico"* ]]
  run env CONTEXT_PCT=95 bash "$SCRIPT" --rot --pct 10
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_ROT_BAND=verde"* ]]
}

@test "rot: --json emits band, action, source and thresholds" {
  run rot --pct 80 --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | json_field "['rot']['band']")" = "rojo" ]
  [ "$(echo "$output" | json_field "['rot']['action']")" = "compact" ]
  [ "$(echo "$output" | json_field "['rot']['thresholds']['red']")" = "75" ]
  [ "$(echo "$output" | json_field "['source']")" = "arg" ]
  [ "$(echo "$output" | json_field "['pct']")" = "80" ]
}

@test "rot: thresholds overridable by env, ordering respected" {
  run env CONTEXT_ROT_YELLOW=50 CONTEXT_ROT_RED=70 CONTEXT_ROT_CRITICAL=80 bash "$SCRIPT" --rot --pct 72
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_ROT_BAND=rojo"* ]]
}

# ── Sin datos: fallback documentado (SE-069 riesgos) ──────────────────────────
@test "rot: empty input without data gives unknown band and continue-with-caution" {
  run rot
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_ROT_BAND=unknown"* ]]
  [[ "$output" == *"CONTEXT_ROT_ACTION=continue-with-caution"* ]]
}

@test "rot: zero max (null window) is unknown, not verde" {
  run env CONTEXT_WINDOW_USED=500 CONTEXT_WINDOW_MAX=0 bash "$SCRIPT" --rot
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_ROT_BAND=unknown"* ]]
}

# ── Entradas invalidas: error, nunca consejo (negativos) ──────────────────────
@test "rot: invalid pct above 100 is rejected with exit 2 and no advice" {
  run rot --pct 101
  [ "$status" -eq 2 ]
  [[ "$output" != *"CONTEXT_ROT_ACTION"* ]]
  [[ "$output" == *"invalid"* ]]
}

@test "rot: invalid negative and non-integer pct are rejected" {
  run rot --pct -1
  [ "$status" -eq 2 ]
  run rot --pct 75.5
  [ "$status" -eq 2 ]
  run rot --pct abc
  [ "$status" -eq 2 ]
  run rot --pct ""
  [ "$status" -eq 2 ]
}

@test "rot: missing value for --pct is an error" {
  run rot --pct
  [ "$status" -eq 2 ]
}

@test "rot: invalid CONTEXT_PCT env is rejected, not treated as zero" {
  run env CONTEXT_PCT=ochenta bash "$SCRIPT" --rot
  [ "$status" -eq 2 ]
  [[ "$output" != *"CONTEXT_ROT_ACTION"* ]]
}

@test "rot: used greater than max is rejected instead of clamped to critico" {
  run env CONTEXT_WINDOW_USED=150 CONTEXT_WINDOW_MAX=100 bash "$SCRIPT" --rot
  [ "$status" -eq 2 ]
  [[ "$output" != *"CONTEXT_ROT_ACTION"* ]]
}

@test "rot: negative used is rejected instead of clamped to zero" {
  run env CONTEXT_WINDOW_USED=-5 CONTEXT_WINDOW_MAX=100 bash "$SCRIPT" --rot
  [ "$status" -eq 2 ]
}

@test "rot: large value beyond 15 digits is rejected (no int64 overflow)" {
  run env CONTEXT_WINDOW_USED=1 CONTEXT_WINDOW_MAX=99999999999999999999 bash "$SCRIPT" --rot
  [ "$status" -eq 2 ]
}

@test "rot: unordered thresholds are rejected" {
  run env CONTEXT_ROT_YELLOW=80 CONTEXT_ROT_RED=70 bash "$SCRIPT" --rot --pct 50
  [ "$status" -eq 2 ]
}

@test "unknown option is rejected instead of silently ignored" {
  run bash "$SCRIPT" --rott
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "non-numeric --threshold-warn is rejected with exit 2" {
  run env CONTEXT_WINDOW_USED=10 CONTEXT_WINDOW_MAX=100 bash "$SCRIPT" --threshold-warn abc
  [ "$status" -eq 2 ]
}

# ── Seguridad: los valores nunca se evaluan como codigo ───────────────────────
@test "env token values are never executed as python (reject injection)" {
  run env CONTEXT_WINDOW_USED='1e0+len(str(print("INJECTED")))' CONTEXT_WINDOW_MAX=100 \
      bash "$SCRIPT" --json
  [ "$status" -eq 2 ]
  # El error puede citar el valor; ejecutarlo imprimiria INJECTED en su propia linea
  ! printf '%s\n' "$output" | grep -qx 'INJECTED'
}

@test "snapshot with injected or non-integer fields is rejected" {
  printf '{"used": "1e3", "max": 2000}\n' > "$TMP_DIR/snap.json"
  run env CONTEXT_METER_SNAPSHOT="$TMP_DIR/snap.json" bash "$SCRIPT" --rot
  [ "$status" -eq 2 ]
}

# ── Rutas: solo el snapshot indicado, nada del cwd del usuario ────────────────
@test "snapshot path comes from CONTEXT_METER_SNAPSHOT, not the cwd" {
  mkdir -p "$TMP_DIR/cwd/output"
  printf '{"used": 950, "max": 1000}\n' > "$TMP_DIR/cwd/output/context-snapshot.json"
  printf '{"used": 100, "max": 1000}\n' > "$TMP_DIR/snap.json"
  cd "$TMP_DIR/cwd"
  run env CONTEXT_METER_SNAPSHOT="$TMP_DIR/snap.json" bash "$REPO_ROOT/$SCRIPT" --rot
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_PCT=10"* ]]
  [[ "$output" == *"CONTEXT_ROT_BAND=verde"* ]]
}

@test "script writes nothing: tmp cwd stays empty after a run" {
  mkdir -p "$TMP_DIR/empty"
  cd "$TMP_DIR/empty"
  run bash "$REPO_ROOT/$SCRIPT" --rot --pct 80 --json
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$TMP_DIR/empty")" ]
}

# ── Compatibilidad: el modo meter sin --rot no cambia ─────────────────────────
@test "meter mode without --rot keeps SE-219 output and omits rot fields" {
  run env CONTEXT_WINDOW_USED=140000 CONTEXT_WINDOW_MAX=200000 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_STATUS=warn"* ]]
  [[ "$output" != *"CONTEXT_ROT_BAND"* ]]
}
