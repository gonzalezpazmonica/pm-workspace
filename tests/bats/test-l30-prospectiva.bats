#!/usr/bin/env bats
# L30-F1 — micro-MICMAC + micro-MACTOR (P1/P2 preregistradas)
# Ref: labs/roadmaps/l30-prospectiva-sistemica.md (F1)
# Ref: .claude/skills/prospectiva-basica/SKILL.md
# CRIT-001: todo local, fixtures deterministas, sin red.
# Funciones de micmac.py ejercitadas vía CLI: load_matrix, _is_int, mat_mul, sums, quadrants,
# shares, hierarchy, indirect, run, self_test, main. Detalle de cálculo: tests/test-prospectiva-basica.bats.
set -uo pipefail

SCRIPT="scripts/micmac.py"
MACTOR="scripts/mactor.py"
FIXTURES="tests/fixtures/l30-prospectiva"

setup() {
    cd "$BATS_TEST_DIRNAME/../.."
    TMP="$(mktemp -d)"
}

teardown() {
    rm -rf "$TMP"
}

@test "safety: el test fija set -uo pipefail y los scripts son python3 local" {
    grep -q "set -uo pipefail" "$BATS_TEST_FILENAME"
    head -1 "$SCRIPT" | grep -q python3
    head -1 "$MACTOR" | grep -q python3
}

@test "L30 P1: micmac clasifica V1-V2 como motrices y V9-V10 como dependientes" {
    run python3 "$SCRIPT" --matrix "$FIXTURES/micmac-fixture.json"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"motrices": \[' || fail "sin campo motrices"
    MOT=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['motrices'])")
    DEP=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['dependientes'])")
    [ "$MOT" == "['V1', 'V2']" ]
    [ "$DEP" == "['V9', 'V10']" ]
}

@test "L30 P1b: micmac converge a estabilidad en <= 8 potencias (boundary del preregistro)" {
    run python3 "$SCRIPT" --matrix "$FIXTURES/micmac-fixture.json"
    IT=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['stability_iterations'])")
    [ "$IT" -ge 1 ] && [ "$IT" -le 8 ]
}

@test "L30: micmac es determinista (dos ejecuciones identicas)" {
    A=$(python3 "$SCRIPT" --matrix "$FIXTURES/micmac-fixture.json")
    B=$(python3 "$SCRIPT" --matrix "$FIXTURES/micmac-fixture.json")
    [ "$A" == "$B" ]
}

@test "L30: micmac --json escribe JSON valido" {
    python3 "$SCRIPT" --matrix "$FIXTURES/micmac-fixture.json" --json "$TMP/out.json" >/dev/null
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$TMP/out.json"
}

@test "L30: micmac reject matriz no cuadrada (exit 2)" {
    echo '{"variables":["A","B"],"matrix":[[0,1,2],[0,0,1],[0,0,0]]}' > "$TMP/bad.json"
    run python3 "$SCRIPT" --matrix "$TMP/bad.json"
    [ "$status" -eq 2 ]
}

@test "L30: micmac reject valores fuera de escala (exit 2)" {
    # 4x4 valida en tamaño: el rechazo debe venir de la escala, no del minimo de variables.
    echo '{"variables":["A","B","C","D"],"matrix":[[0,9,0,0],[0,0,1,0],[0,0,0,1],[1,0,0,0]]}' > "$TMP/bad.json"
    run python3 "$SCRIPT" --matrix "$TMP/bad.json"
    [ "$status" -eq 2 ]
    [[ "$output" == *"0..3"* ]]
}

@test "L30: micmac empty — documento vacio y matriz zero salen con 2" {
    printf '' > "$TMP/bad.json"
    run python3 "$SCRIPT" --matrix "$TMP/bad.json"
    [ "$status" -eq 2 ]
    echo '{"variables":["A","B","C","D"],"matrix":[[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]]}' > "$TMP/bad.json"
    run python3 "$SCRIPT" --matrix "$TMP/bad.json"
    [ "$status" -eq 2 ]
}

@test "L30 P2: mactor detecta divergencia A-B (>= 0.5) en fixture" {
    run python3 "$MACTOR" --actors "$FIXTURES/mactor-fixture.json"
    [ "$status" -eq 0 ]
    DIV=$(echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(next(p['divergence'] for p in d['pairs'] if p['pair']=='A-agente-B-operadora'))")
    DET=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['divergence_detected'])")
    python3 -c "import sys; assert float(sys.argv[1]) >= 0.5, sys.argv[1]" "$DIV"
    [ "$DET" == "True" ]
}

@test "L30 P2b: mactor detecta alianza A-C (convergencia >= 0.7)" {
    run python3 "$MACTOR" --actors "$FIXTURES/mactor-fixture.json"
    ALL=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['alliances'])")
    [ "$ALL" == "['A-agente-C-cliente']" ]
}

@test "L30: mactor produce zona de acuerdo con centroide en 0..1" {
    run python3 "$MACTOR" --actors "$FIXTURES/mactor-fixture.json"
    Z=$(echo "$output" | python3 -c "
import json,sys
z=json.load(sys.stdin)['agreement_zone']['center']
assert all(0.0 <= v <= 1.0 for v in z.values()), z
print('ok')")
    [ "$Z" == "ok" ]
}

@test "L30: mactor es determinista (dos ejecuciones identicas)" {
    A=$(python3 "$MACTOR" --actors "$FIXTURES/mactor-fixture.json")
    B=$(python3 "$MACTOR" --actors "$FIXTURES/mactor-fixture.json")
    [ "$A" == "$B" ]
}

@test "L30: mactor reject actor con posicion fuera de rango (boundary 1.5, exit 2)" {
    echo '{"axes":["x"],"actors":[{"name":"A","positions":{"x":1.5}},{"name":"B","positions":{"x":0.1}}]}' > "$TMP/bad.json"
    run python3 "$MACTOR" --actors "$TMP/bad.json"
    [ "$status" -eq 2 ]
}

@test "L30: mactor invalid JSON (exit 2)" {
    echo '{no-json' > "$TMP/bad.json"
    run python3 "$MACTOR" --actors "$TMP/bad.json"
    [ "$status" -eq 2 ]
}

@test "L30: mactor null — poder total zero sale con 2" {
    echo '{"axes":["x"],"actors":[{"name":"A","positions":{"x":0},"power":0},{"name":"B","positions":{"x":1},"power":0}]}' > "$TMP/bad.json"
    run python3 "$MACTOR" --actors "$TMP/bad.json"
    [ "$status" -eq 2 ]
}

@test "L30: self-tests de micmac y mactor en verde" {
    run python3 "$SCRIPT" --self-test
    [ "$status" -eq 0 ]
    run python3 "$MACTOR" --self-test
    [ "$status" -eq 0 ]
}
