#!/usr/bin/env bats
# SCL-001 S1 — Captura canónica del bucle de aprendizaje
# Ref: docs/specs/SCL-001-aprendizaje-continuo.spec.md (AC-1.1..1.5)

set -uo pipefail

setup_file() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  export REPO_ROOT
}

setup() {
  SCRIPT="$REPO_ROOT/scripts/learning-proposal.sh"
  TMPD="$(mktemp -d -t scl-s1-XXXXXX)"
  PROPOSALS="$TMPD/proposals"
  GRAPH="$TMPD/graph.jsonl"
  echo "evidence-one" > "$TMPD/evidence1.txt"
  echo "evidence-two" > "$TMPD/evidence2.txt"
  mkdir -p "$PROPOSALS"
}

teardown() {
  [ -n "${TMPD:-}" ] && rm -rf "$TMPD"
}

@test "AC-1.1: error reconocido genera UNA propuesta con evidencia+diagnostico+cambio no vacios" {
  run bash "$SCRIPT" --origin "ledger reconoce error X" \
    --evidence "$TMPD/evidence1.txt" \
    --diagnosis "misma causa raiz en dos tareas" \
    --change "anadir regla de revision de cause-root" \
    --target criterio --output-dir "$PROPOSALS" --graph-index "$GRAPH"
  [ "$status" -eq 0 ]
  file=$(echo "$output" | grep -oP 'CREATED: \K.*' | head -1)
  [ -f "$file" ]
  grep -q "^## Evidencia" "$file"
  grep -q "^## Diagnóstico" "$file"
  grep -q "^## Cambio propuesto" "$file"
  grep -qE "^id: LP-[0-9]{8}-[0-9a-f]{8}" "$file"
  grep -q "^provenance: INFERRED" "$file"
  grep -q "^lifecycle: proposed" "$file"
  # diagnóstico y cambio no vacíos
  awk '/^## Diagnóstico/{f=1;next}/^## Cambio propuesto/{f=0} f && NF{g=1} END{exit !g}' "$file"
  awk '/^## Cambio propuesto/{f=1;next}/^## Destino/{f=0} f && NF{g=1} END{exit !g}' "$file"
}

@test "AC-1.2: decision que contradice CRIT genera propuesta de evolucion marcando origen" {
  run bash "$SCRIPT" --origin "operadora decide X contrario a CRIT-007" \
    --evidence "$TMPD/evidence2.txt" \
    --diagnosis "CRIT-007 impide el flujo observado" \
    --change "evolucionar CRIT-007 (no sobrescribir)" \
    --target criterio --trigger contradiction --output-dir "$PROPOSALS" --graph-index "$GRAPH"
  [ "$status" -eq 0 ]
  file=$(echo "$output" | grep -oP 'CREATED: \K.*' | head -1)
  grep -q "CRIT-007" "$file"
  grep -q "evolucionar" "$file"
  grep -q "^origin: operadora decide X contrario a CRIT-007" "$file"
}

@test "AC-1.3: idempotencia — mismo hash de evidencia en 24h produce como maximo 1 propuesta" {
  run bash "$SCRIPT" --origin "a" --evidence "$TMPD/evidence1.txt" \
    --diagnosis "d" --change "c" --target skill \
    --output-dir "$PROPOSALS" --graph-index "$GRAPH"
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" --origin "a" --evidence "$TMPD/evidence1.txt" \
    --diagnosis "d" --change "c" --target skill \
    --output-dir "$PROPOSALS" --graph-index "$GRAPH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"DUPLICATE"* ]]
  count=$(ls "$PROPOSALS"/*.md | wc -l | tr -d ' ')
  [ "$count" -eq 1 ]
}

@test "AC-1.4: propuesta registrada en el grafo como learning_proposal con relaciones tipadas" {
  run bash "$SCRIPT" --origin "a" --evidence "$TMPD/evidence1.txt" \
    --diagnosis "d" --change "c" --target memoria \
    --output-dir "$PROPOSALS" --graph-index "$GRAPH"
  [ "$status" -eq 0 ]
  [ -f "$GRAPH" ]
  python3 - "$GRAPH" <<'PY'
import json, sys
entry = [json.loads(l) for l in open(sys.argv[1]) if l.strip()][0]
assert entry["type"] == "learning_proposal", entry
assert entry["provenance"] == "INFERRED"
assert "proposes_change" in entry["relations"]
assert "evidence_from" in entry["relations"]
assert entry["relations"]["evidence_from"], "evidence_from no debe estar vacio"
PY
}

@test "AC-1.5: propuesta legible con cat — id, origen y cambio sin ejecutar scripts" {
  run bash "$SCRIPT" --origin "cat-test" --evidence "$TMPD/evidence1.txt" \
    --diagnosis "d" --change "cambio visible por cat" --target spec \
    --output-dir "$PROPOSALS" --graph-index "$GRAPH"
  [ "$status" -eq 0 ]
  file=$(echo "$output" | grep -oP 'CREATED: \K.*' | head -1)
  content=$(cat "$file")
  [[ "$content" == *"id: LP-"* ]]
  [[ "$content" == *"origin: cat-test"* ]]
  [[ "$content" == *"## Cambio propuesto"* ]]
  [[ "$content" == *"cambio visible por cat"* ]]
}
