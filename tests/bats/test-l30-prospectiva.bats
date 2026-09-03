#!/usr/bin/env bats
# L30-F1 — micro-MICMAC + micro-MACTOR (P1/P2 preregistradas)
# Ref: labs/roadmaps/l30-prospectiva-sistemica.md (F1)
# CRIT-001: todo local, fixtures deterministas, sin red.

FIXTURES="tests/fixtures/l30-prospectiva"

@test "L30 P1: micmac clasifica V1-V2 como motrices y V9-V10 como dependientes" {
    run python3 scripts/micmac.py --matrix "$FIXTURES/micmac-fixture.json"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"motrices": \[' || fail "sin campo motrices"
    MOT=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['motrices'])")
    DEP=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['dependientes'])")
    [ "$MOT" == "['V1', 'V2']" ]
    [ "$DEP" == "['V9', 'V10']" ]
}

@test "L30 P1b: micmac converge a estabilidad en <= MAX_ITER iteraciones" {
    run python3 scripts/micmac.py --matrix "$FIXTURES/micmac-fixture.json"
    IT=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['stability_iterations'])")
    [ "$IT" -ge 1 ] && [ "$IT" -le 8 ]
}

@test "L30: micmac es determinista (dos ejecuciones identicas)" {
    A=$(python3 scripts/micmac.py --matrix "$FIXTURES/micmac-fixture.json")
    B=$(python3 scripts/micmac.py --matrix "$FIXTURES/micmac-fixture.json")
    [ "$A" == "$B" ]
}

@test "L30: micmac --json escribe JSON valido" {
    OUT="$(mktemp)"
    python3 scripts/micmac.py --matrix "$FIXTURES/micmac-fixture.json" --json "$OUT" >/dev/null
    python3 -c "import json; json.load(open('$OUT'))"
    rm -f "$OUT"
}

@test "L30: micmac rechaza matriz no cuadrada (exit 2)" {
    BAD="$(mktemp)"
    echo '{"variables":["A","B"],"matrix":[[0,1,2],[0,0,1],[0,0,0]]}' > "$BAD"
    run python3 scripts/micmac.py --matrix "$BAD"
    [ "$status" -eq 2 ]
    rm -f "$BAD"
}

@test "L30: micmac rechaza valores fuera de escala (exit 2)" {
    BAD="$(mktemp)"
    echo '{"variables":["A","B"],"matrix":[[0,9],[0,0]]}' > "$BAD"
    run python3 scripts/micmac.py --matrix "$BAD"
    [ "$status" -eq 2 ]
    rm -f "$BAD"
}

@test "L30 P2: mactor detecta divergencia A-B (>= 0.5) en fixture" {
    run python3 scripts/mactor.py --actors "$FIXTURES/mactor-fixture.json"
    [ "$status" -eq 0 ]
    DIV=$(echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(next(p['divergence'] for p in d['pairs'] if p['pair']=='A-agente-B-operadora'))")
    DET=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['divergence_detected'])")
    python3 -c "assert float('$DIV') >= 0.5, '$DIV'"
    [ "$DET" == "True" ]
}

@test "L30 P2b: mactor detecta alianza A-C (convergencia >= 0.7)" {
    run python3 scripts/mactor.py --actors "$FIXTURES/mactor-fixture.json"
    ALL=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['alliances'])")
    [ "$ALL" == "['A-agente-C-cliente']" ]
}

@test "L30: mactor produce zona de acuerdo con centroide en 0..1" {
    run python3 scripts/mactor.py --actors "$FIXTURES/mactor-fixture.json"
    Z=$(echo "$output" | python3 -c "
import json,sys
z=json.load(sys.stdin)['agreement_zone']['center']
assert all(0.0 <= v <= 1.0 for v in z.values()), z
print('ok')")
    [ "$Z" == "ok" ]
}

@test "L30: mactor es determinista (dos ejecuciones identicas)" {
    A=$(python3 scripts/mactor.py --actors "$FIXTURES/mactor-fixture.json")
    B=$(python3 scripts/mactor.py --actors "$FIXTURES/mactor-fixture.json")
    [ "$A" == "$B" ]
}

@test "L30: mactor rechaza actor con posicion fuera de rango (exit 2)" {
    BAD="$(mktemp)"
    echo '{"axes":["x"],"actors":[{"name":"A","positions":{"x":1.5}},{"name":"B","positions":{"x":0.1}}]}' > "$BAD"
    run python3 scripts/mactor.py --actors "$BAD"
    [ "$status" -eq 2 ]
    rm -f "$BAD"
}

@test "L30: mactor rechaza JSON invalido (exit 2)" {
    BAD="$(mktemp)"
    echo '{no-json' > "$BAD"
    run python3 scripts/mactor.py --actors "$BAD"
    [ "$status" -eq 2 ]
    rm -f "$BAD"
}

@test "L30: self-tests de micmac y mactor en verde" {
    run python3 scripts/micmac.py --self-test
    [ "$status" -eq 0 ]
    run python3 scripts/mactor.py --self-test
    [ "$status" -eq 0 ]
}
