#!/usr/bin/env bats
# SE-376 — calibración de la skill prospectiva-basica: micro-MICMAC y micro-MACTOR.
# Casos calculados a mano o por la definición publicada de MICMAC (Godet): clasificación
# indirecta por potencias sucesivas de la matriz de influencias directas, diagonal nula.
# Ref: .claude/skills/prospectiva-basica/SKILL.md
# Ref: docs/rules/domain/skill-maturity-kanban.md
# Funciones cubiertas (micmac.py): load_matrix, _is_int, mat_mul, sums, quadrants, shares,
# hierarchy, indirect, run, self_test, main. MACTOR: tests/test_mactor.py y los casos de abajo.
set -uo pipefail

SCRIPT="scripts/micmac.py"
MACTOR="scripts/mactor.py"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d)"
  cd "$REPO_ROOT"
}

teardown() {
  rm -rf "$TMP"
}

# Escribe una matriz 4x4 con variables A..D y ejecuta micmac.
micmac4() {
  printf '{"variables":["A","B","C","D"],"matrix":%s}\n' "$1" > "$TMP/m.json"
  run python3 "$SCRIPT" --matrix "$TMP/m.json"
}

field() {
  python3 -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1], {}, {'d': d}))" "$1"
}

mactor_doc() {
  printf '%s\n' "$1" > "$TMP/a.json"
  run python3 "$MACTOR" --actors "$TMP/a.json" "${@:2}"
}

@test "safety: los scripts son python3 local, sin red (CRIT-001) y el test fija set -uo pipefail" {
  head -1 "$SCRIPT" | grep -q "python3"
  head -1 "$MACTOR" | grep -q "python3"
  ! grep -Eq "^(import|from) (urllib|socket|http|requests)" "$SCRIPT" "$MACTOR"
  grep -q "set -uo pipefail" "$BATS_TEST_FILENAME"
}

@test "indirect: cadena A->B->C->D da S = M+M^2+M^3 calculada a mano" {
  micmac4 '[[0,1,0,0],[0,0,1,0],[0,0,0,1],[0,0,0,0]]'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | field "d['power']")" = "3" ]
  [ "$(echo "$output" | field "d['converged']")" = "True" ]
  [ "$(echo "$output" | field "d['detail']['A']['influence']")" = "50.0" ]
  [ "$(echo "$output" | field "d['detail']['D']['dependence']")" = "50.0" ]
}

@test "quadrants: la clasificación indirecta difiere de la directa en la cadena" {
  micmac4 '[[0,1,0,0],[0,0,1,0],[0,0,0,1],[0,0,0,0]]'
  [ "$(echo "$output" | field "d['motrices']")" = "['A', 'B']" ]
  [ "$(echo "$output" | field "d['dependientes']")" = "['C', 'D']" ]
  [ "$(echo "$output" | field "d['detail']['B']['direct_quadrant']")" = "enlace" ]
}

@test "regresión: un sistema con ciclos no se aplana a enlace (antes, tope de saturación)" {
  micmac4 '[[0,3,3,3],[1,0,1,0],[1,0,0,1],[1,1,0,0]]'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | field "d['motrices']")" = "['A']" ]
  [ "$(echo "$output" | field "d['enlace']")" = "[]" ]
  [ "$(echo "$output" | field "d['dependientes']")" = "['B', 'C', 'D']" ]
}

@test "shares: influencia y dependencia suman 100% del total" {
  micmac4 '[[0,3,3,3],[1,0,1,0],[1,0,0,1],[1,1,0,0]]'
  python3 -c "
import json,sys
d=json.loads(sys.argv[1])['detail']
assert abs(sum(v['influence'] for v in d.values())-100) < 0.05
assert abs(sum(v['dependence'] for v in d.values())-100) < 0.05
" "$output"
}

@test "fixture L30: solución conocida V1-V2 motrices y V9-V10 dependientes se mantiene" {
  run python3 "$SCRIPT" --matrix tests/fixtures/l30-prospectiva/micmac-fixture.json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | field "d['motrices']")" = "['V1', 'V2']" ]
  [ "$(echo "$output" | field "d['dependientes']")" = "['V9', 'V10']" ]
}

@test "reject: diagonal no nula (Godet: sin auto-influencia) sale con 2" {
  micmac4 '[[0,1,0,0],[0,2,1,0],[0,0,0,1],[1,0,0,0]]'
  [ "$status" -eq 2 ]
  [[ "$output" == *"diagonal"* ]]
}

@test "reject: valor fuera de escala 0..3 en matriz de tamaño válido sale con 2" {
  micmac4 '[[0,4,0,0],[0,0,1,0],[0,0,0,1],[1,0,0,0]]'
  [ "$status" -eq 2 ]
  [[ "$output" == *"0..3"* ]]
}

@test "invalid: decimales, booleanos y texto se rechazan sin traceback" {
  for v in 2.5 true '"x"' null; do
    micmac4 "[[0,$v,0,0],[0,0,1,0],[0,0,0,1],[1,0,0,0]]"
    [ "$status" -eq 2 ]
    [[ "$output" != *"Traceback"* ]]
  done
}

@test "boundary: 1x1, 3x3 y no cuadrada se rechazan; 4x4 es el mínimo aceptado" {
  printf '{"variables":["A"],"matrix":[[0]]}' > "$TMP/m.json"
  run python3 "$SCRIPT" --matrix "$TMP/m.json"
  [ "$status" -eq 2 ]
  printf '{"variables":["A","B","C"],"matrix":[[0,1,0],[0,0,1],[1,0,0]]}' > "$TMP/m.json"
  run python3 "$SCRIPT" --matrix "$TMP/m.json"
  [ "$status" -eq 2 ]
  printf '{"variables":["A","B","C","D"],"matrix":[[0,1,0,0],[0,0,1],[0,0,0,1],[1,0,0,0]]}' > "$TMP/m.json"
  run python3 "$SCRIPT" --matrix "$TMP/m.json"
  [ "$status" -eq 2 ]
  micmac4 '[[0,1,0,0],[0,0,1,0],[0,0,0,1],[1,0,0,0]]'
  [ "$status" -eq 0 ]
}

@test "zero: matriz toda a cero se rechaza (nada que clasificar)" {
  micmac4 '[[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]]'
  [ "$status" -eq 2 ]
  [[ "$output" == *"sin influencias"* ]]
}

@test "empty: documento vacío, lista o nombres duplicados salen con 2" {
  printf '' > "$TMP/m.json"
  run python3 "$SCRIPT" --matrix "$TMP/m.json"
  [ "$status" -eq 2 ]
  printf '[1,2]' > "$TMP/m.json"
  run python3 "$SCRIPT" --matrix "$TMP/m.json"
  [ "$status" -eq 2 ]
  printf '{"variables":["A","A","B","C"],"matrix":[[0,1,0,0],[0,0,1,0],[0,0,0,1],[1,0,0,0]]}' > "$TMP/m.json"
  run python3 "$SCRIPT" --matrix "$TMP/m.json"
  [ "$status" -eq 2 ]
}

@test "large: 20 variables densas convergen y el JSON de --json es idéntico al de stdout" {
  python3 -c "
import json
n=20
m=[[0 if i==j else (i*7+j*3)%4 for j in range(n)] for i in range(n)]
json.dump({'variables':[f'V{i+1}' for i in range(n)],'matrix':m}, open('$TMP/big.json','w'))"
  run python3 "$SCRIPT" --matrix "$TMP/big.json" --json "$TMP/out.json"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | field "d['converged']")" = "True" ]
  [ "$(echo "$output" | field "d['variables']")" -eq 20 ]
  [ "$output" = "$(cat "$TMP/out.json")" ]
}

@test "error: --json a ruta no escribible sale con 2, sin traceback" {
  micmac4 '[[0,1,0,0],[0,0,1,0],[0,0,0,1],[1,0,0,0]]'
  run python3 "$SCRIPT" --matrix "$TMP/m.json" --json "$TMP/no-existe/out.json"
  [ "$status" -eq 2 ]
  [[ "$output" != *"Traceback"* ]]
}

@test "no-arg: sin --matrix sale con 2 (argparse)" {
  run python3 "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "self_test: micmac y mactor en verde" {
  run python3 "$SCRIPT" --self-test
  [ "$status" -eq 0 ]
  [[ "$output" == *"SELF-TEST OK"* ]]
  run python3 "$MACTOR" --self-test
  [ "$status" -eq 0 ]
}

@test "mactor: divergencia ponderada por stake común calculada a mano (0.75)" {
  mactor_doc '{"axes":["x","y"],"actors":[{"name":"A","positions":{"x":0,"y":0},"stake":{"x":1,"y":0.5}},{"name":"B","positions":{"x":1,"y":0.5},"stake":{"x":0.5,"y":1}}]}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | field "d['pairs'][0]['divergence']")" = "0.75" ]
  [ "$(echo "$output" | field "d['divergences']")" = "['A-B']" ]
}

@test "mactor null: sin stake común el par no es alianza ni conflicto" {
  mactor_doc '{"axes":["x","y"],"actors":[{"name":"A","positions":{"x":0,"y":0},"stake":{"x":1,"y":0}},{"name":"B","positions":{"x":1,"y":1},"stake":{"x":0,"y":1}}]}'
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | field "d['pairs'][0]['divergence']")" = "None" ]
  [ "$(echo "$output" | field "d['alliances']")" = "[]" ]
}

@test "mactor zero: poder total 0 se rechaza con 2 (antes ZeroDivisionError, exit 1)" {
  mactor_doc '{"axes":["x"],"actors":[{"name":"A","positions":{"x":0},"power":0},{"name":"B","positions":{"x":1},"power":0}]}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"poder"* ]]
}

@test "mactor reject: actores duplicados, ejes vacíos y umbral fuera de 0..1 salen con 2" {
  mactor_doc '{"axes":["x"],"actors":[{"name":"A","positions":{"x":0}},{"name":"A","positions":{"x":1}}]}'
  [ "$status" -eq 2 ]
  mactor_doc '{"axes":[],"actors":[{"name":"A","positions":{}},{"name":"B","positions":{}}]}'
  [ "$status" -eq 2 ]
  mactor_doc '{"axes":["x"],"actors":[{"name":"A","positions":{"x":0}},{"name":"B","positions":{"x":1}}]}' --threshold 1.5
  [ "$status" -eq 2 ]
}

@test "unittest: suites python de micmac y mactor en verde" {
  run python3 -m unittest tests/test_micmac.py tests/test_mactor.py
  [ "$status" -eq 0 ]
}
