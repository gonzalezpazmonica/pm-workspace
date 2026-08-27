#!/usr/bin/env bats
# Ref: L27 E13/E14 — auditor del auditor + matriz de frónesis

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "L27-E13: el auditor distingue revisor bueno de sello-de-goma (AUC)" {
  out=$(python3 "$ROOT_DIR/scripts/l27-auditor-auditor.py" --synthetic 2>/dev/null)
  echo "$out" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['revisor_good']['auc'] > d['revisor_rubber']['auc'], d
assert d['revisor_good']['auc'] >= 0.6
"
}

@test "L27-E13: piloto real sobre audit log de savia-gates (resumen sin contenido)" {
  out=$(python3 "$ROOT_DIR/scripts/l27-auditor-auditor.py" 2>/dev/null)
  echo "$out" | python3 -c "
import json,sys
d=json.load(sys.stdin)
g=d.get('gates_savia')
assert g, 'sin audit'
assert g['total_eventos_gate'] > 0
assert 'bloqueos' in g and 'avisos' in g
assert 'concentracion_top_tool' in g
"
}

@test "L27-E14: matriz de frónesis generada con los 3 tipos y conteo" {
  run python3 "$ROOT_DIR/scripts/l27-fronesis-matrix.py" --out "$ROOT_DIR/output/l27-fronesis-matrix.md"
  [ "$status" -eq 0 ]
  [ -f "$ROOT_DIR/output/l27-fronesis-matrix.md" ]
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['puntos'] >= 10
assert set(d['por_tipo']) == {'retenida','delegada-con-precedentes','automatizada'}
"
  grep -q "Frónesis retenida" "$ROOT_DIR/output/l27-fronesis-matrix.md"
  grep -q "automatizada" "$ROOT_DIR/output/l27-fronesis-matrix.md"
}

@test "L27 E13/E14: CRIT-001 — sin librerías de red" {
  ! grep -nE "import (urllib|requests|socket)|http://|https://" \
    "$ROOT_DIR/scripts/l27-auditor-auditor.py" "$ROOT_DIR/scripts/l27-fronesis-matrix.py"
}
