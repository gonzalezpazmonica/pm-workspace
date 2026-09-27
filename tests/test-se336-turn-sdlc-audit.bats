#!/usr/bin/env bats
# SE-336 S1 — Turn-SDLC audit: matriz fase→hook
# Spec: docs/specs/SE-336-turn-sdlc.spec.md
# Ref: docs/specs/SE-336-turn-sdlc.spec.md

SCRIPT="scripts/turn-sdlc-audit.sh"
MATRIX="output/turn-sdlc-matrix.md"

setup() {
  set -o pipefail
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
}

teardown() {
  cd /
}

@test "AC-01a: el auditor clasifica el 100% de hooks (0 unclassified fuera de F0)" {
  run bash "$SCRIPT" --json
  [[ "$status" -eq 0 ]]
  # unclassified_f0 cuenta hooks F0 (infra), que NO son 'sin clasificar':
  # todos los hooks caen en alguna fase o en F0. Verificamos que el total
  # cuadra con la suma de fases+F0.
  TOTAL=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['total'])")
  SUM=$(echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(sum(d['phases'].values()))")
  [[ "$TOTAL" -eq "$SUM" ]]
}

@test "AC-01b: la matriz markdown se genera con resumen y tabla por hook" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -f "$MATRIX" ]]
  grep -q "## Resumen" "$MATRIX"
  grep -q "## Matriz por hook" "$MATRIX"
  grep -q "| F5 |" "$MATRIX"
}

@test "AC-01c: fases F1-F6 presentes en la matriz" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  for p in F1 F2 F3 F4 F5 F6; do
    grep -q "^| $p |" "$MATRIX"
  done
}

@test "RN-07: clasificación fina F5 vs F6 (stop-memory-extract es F6, stop-quality-gate es F5)" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  grep -q "F6.*stop-memory-extract" "$MATRIX"
  grep -q "F5.*stop-quality-gate" "$MATRIX"
}

@test "settings.json inválido → exit 2" {
  local tmp
  tmp=$(mktemp -d)
  echo "not-json" > "$tmp/bad.json"
  run bash -c "ROOT='' ; cd $tmp && bash '$PWD/$SCRIPT'" 2>/dev/null
  # el script usa ROOT relativo al propio script; invalidamos copiando
  rm -rf "$tmp"
  skip "cobertura de error cubierta por guard interno python3; ver test json-mode"
}

@test "edge: matcher empty no desplaza el comando al campo hook (JSON valido)" {
  local fx="$BATS_TEST_TMPDIR/settings.json"
  printf '%s' '{"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR\"/.opencode/hooks/x-gate.sh"}]}]}}' > "$fx"
  run env TURN_SDLC_SETTINGS="$fx" bash "$SCRIPT" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import json,sys; h=json.load(sys.stdin)['hooks'][0]; assert h['hook']=='x-gate.sh' and h['matcher']=='-', h"
}

@test "edge: comillas en el matcher se escapan (boundary JSON)" {
  local fx="$BATS_TEST_TMPDIR/settings.json"
  printf '%s' '{"hooks":{"PreToolUse":[{"matcher":"Bash(echo \"hi\")","hooks":[{"type":"command","command":"bash hooks/y.sh"}]}]}}' > "$fx"
  run env TURN_SDLC_SETTINGS="$fx" bash "$SCRIPT" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import json,sys; h=json.load(sys.stdin)['hooks'][0]; assert h['matcher']=='Bash(echo \"hi\")', h"
}

@test "settings nonexistent → error exit 2" {
  run env TURN_SDLC_SETTINGS="$BATS_TEST_TMPDIR/nope.json" bash "$SCRIPT" --json
  [[ "$status" -eq 2 ]]
}

@test "settings JSON invalid → error exit 2" {
  printf '{bad' > "$BATS_TEST_TMPDIR/bad.json"
  run env TURN_SDLC_SETTINGS="$BATS_TEST_TMPDIR/bad.json" bash "$SCRIPT" --json
  [[ "$status" -eq 2 ]]
}

@test "evento missing del mapa de fases cae en F0 sin romper el JSON" {
  local fx="$BATS_TEST_TMPDIR/settings.json"
  printf '%s' '{"hooks":{"FutureEvent":[{"hooks":[{"type":"command","command":"bash hooks/z.sh"}]}]}}' > "$fx"
  run env TURN_SDLC_SETTINGS="$fx" bash "$SCRIPT" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hooks'][0]['phase']=='F0' and d['unclassified_f0']==1"
}
