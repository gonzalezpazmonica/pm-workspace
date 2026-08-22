#!/usr/bin/env bats
# L13 F1 — meta-monitor + meta-recalibrate (juicio metacognitivo)
# Linea: labs/hypotheses/l13-savia-metacognition.md

MONITOR="scripts/meta-monitor.sh"
RECAL="scripts/meta-recalibrate.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  FIXDIR=$(mktemp -d)
  CAL="$FIXDIR/cal.json"
}

teardown() {
  rm -rf "$FIXDIR"
}

@test "existe, bash -n, sin vendor cloud names, PURE_BASH" {
  [[ -x "$MONITOR" ]] && [[ -x "$RECAL" ]]
  bash -n "$MONITOR" && bash -n "$RECAL"
  run grep -niE "api\.openai\.com|api\.anthropic\.com|api\.deepseek\.com|api\.google\.com|api\.mistral\.ai" "$MONITOR" "$RECAL"
  [[ "$status" -ne 0 ]]
}

@test "M1: monitor SIN curva (calibracion default 0.5) + divergencia baja → ajusta" {
  cal_file="$FIXDIR/cal0.json"
  run bash "$MONITOR" --calibration-file "$cal_file" --task t --confidence 80 --divergence 0.2 --evidence 0.9
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'confidence_adjusted' in d
assert d['confidence_adjusted'] < d['confidence_declared']  # siempre ajusta por calibration default 0.5
"
}

@test "M1b: con calibracion 1.0 y buena evidencia → adjusted razonable (>=60)" {
  # curva perfecta: 3 success
  bash "$RECAL" --calibration-file "$CAL" --task t --predicted 80 --outcome success >/dev/null
  bash "$RECAL" --calibration-file "$CAL" --task t --predicted 85 --outcome success >/dev/null
  bash "$RECAL" --calibration-file "$CAL" --task t --predicted 90 --outcome success >/dev/null
  run bash "$MONITOR" --calibration-file "$CAL" --task t --confidence 80 --divergence 0.1 --evidence 0.9
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['calibration'] == 1.0
assert d['confidence_adjusted'] >= 60
"
}

@test "M1c: sobreconfianza + divergencia alta → POSTPONE (ajuste fuerte)" {
  # curva baja: 1 success 1 fail -> 0.5
  bash "$RECAL" --calibration-file "$CAL" --task t --predicted 80 --outcome success >/dev/null
  bash "$RECAL" --calibration-file "$CAL" --task t --predicted 80 --outcome fail >/dev/null
  run bash "$MONITOR" --calibration-file "$CAL" --task t --confidence 90 --divergence 0.8 --evidence 0.3
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'POSTPONE' in d['action_hint']
assert d['confidence_adjusted'] < 60
"
}

@test "recalibra: curva mejora con los resultados (accuracy sube al anadir success)" {
  bash "$RECAL" --calibration-file "$CAL" --task t --predicted 50 --outcome fail >/dev/null
  r1=$(bash "$RECAL" --calibration-file "$CAL" --task t --predicted 50 --outcome success 2>&1 | grep -oP 'accuracy=\K[0-9.]+')
  r2=$(bash "$RECAL" --calibration-file "$CAL" --task t --predicted 80 --outcome success 2>&1 | grep -oP 'accuracy=\K[0-9.]+')
  echo "acc tras 1: $r1 ; tras 2: $r2"
  # 1 fail + 1 success = 0.5 ; +1 success = 0.667
  python3 -c "assert abs(float('$r1')-0.5)<0.01, '$r1'"
  python3 -c "assert abs(float('$r2')-0.667)<0.01, '$r2'"
}

@test "recalibracion por tarea: tareas distintas no contaminan" {
  bash "$RECAL" --calibration-file "$CAL" --task alpha --predicted 50 --outcome fail >/dev/null
  bash "$RECAL" --calibration-file "$CAL" --task beta  --predicted 90 --outcome success >/dev/null
  bash "$RECAL" --calibration-file "$CAL" --task beta  --predicted 90 --outcome success >/dev/null
  # monitor beta: calibracion global (1 success/1 fail + 2 success = 3/4=0.75) ; por tarea beta n=2 correct=2
  run bash "$MONITOR" --calibration-file "$CAL" --task beta --confidence 85 --divergence 0.2 --evidence 0.9
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['calibration'] >= 0.7  # la curva global refleja la buena calibracion en beta
"
}

@test "input invalido → exit 2 (monitor sin args; outcome no valido)" {
  run bash "$MONITOR"
  [[ "$status" -eq 2 ]]
  run bash "$RECAL" --task x --predicted 80 --outcome nope
  [[ "$status" -eq 2 ]]
}

@test "CRIT-031: ningun script escribe a CRITERIO ni CONSTITUCION (hash invariante)" {
  h1=$(sha256sum CRITERIO.md | cut -d' ' -f1)
  h2=$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)
  bash "$RECAL" --calibration-file "$CAL" --task t --predicted 80 --outcome success >/dev/null
  bash "$MONITOR" --calibration-file "$CAL" --task t --confidence 80 --divergence 0.2 --evidence 0.9 >/dev/null
  [[ "$(sha256sum CRITERIO.md | cut -d' ' -f1)" == "$h1" ]]
  [[ "$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)" == "$h2" ]]
}