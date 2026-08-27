#!/usr/bin/env bats
# Ref: L27 E3/E5 — hechos vs humo (facts-ledger) + score sintético (gate)

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "L27-E3: facts-ledger extrae hechos verificados y marca humo" {
  run python3 "$ROOT_DIR/scripts/l27-facts-ledger.py" --vault "$ROOT_DIR/vaults/Fronesia"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys
r=json.load(sys.stdin)
assert r['hechos'] >= 6, r   # seed verificado
assert 'ratio_hechos' in r
assert isinstance(r['humo_ids'], list)
"
  [ -f "$ROOT_DIR/output/l27-facts-ledger.jsonl" ]
  [ "$(wc -l < "$ROOT_DIR/output/l27-facts-ledger.jsonl")" -ge 6 ]
}

@test "L27-E3: una afirmación sin consecuencia verificada es humo (no evidencia)" {
  # registrar un caso draft (pending) → debe aparecer como humo
  V=$(mktemp -d)
  python3 "$ROOT_DIR/scripts/fronema.py" register --tension t --decision d --razon r --limites l \
    --senal s --pregunta p --dominio SFT --fuente f --vault "$V" >/dev/null
  run python3 "$ROOT_DIR/scripts/l27-facts-ledger.py" --vault "$V" --out "$V/ledger.jsonl"
  [ "$status" -eq 1 ]  # GATE E3: sin hechos → FAIL
  echo "$output" | grep -q '"hechos": 0'
  echo "$output" | grep -q '"humo": 1'
}

@test "L27-E5: score sintético determinista y gate PASS por defecto" {
  a=$(python3 "$ROOT_DIR/scripts/l27-score-synthetic.py" --seed 42)
  b=$(python3 "$ROOT_DIR/scripts/l27-score-synthetic.py" --seed 42)
  [ "$a" == "$b" ]
  echo "$a" | grep -q '"gate_E3_pass": true'
  echo "$a" | grep -q '"auc_score_vs_latent": 0.794'
}

@test "L27-E5: AUC en [0.5,1] y Brier calibrado mejora a la tasa base" {
  out=$(python3 "$ROOT_DIR/scripts/l27-score-synthetic.py" --seed 7 2>/dev/null)
  [ -n "$out" ]
  echo "$out" | python3 -c "
import json,sys
r=json.load(sys.stdin)
assert 0.5 <= r['auc_score_vs_latent'] <= 1.0
assert r['brier_calibrado'] < r['brier_base_rate']
assert r['mejora_calibracion_vs_base'] > 0
"
}

@test "L27 E3/E5: CRIT-001 — sin librerías de red" {
  ! grep -nE "import (urllib|requests|socket)|http://|https://" "$ROOT_DIR/scripts/l27-facts-ledger.py" "$ROOT_DIR/scripts/l27-score-synthetic.py"
}
