#!/usr/bin/env bats
# Ref: L27 E3/E5 — hechos vs humo (facts-ledger) + score sintético (gate)

SCRIPT="scripts/l27-facts-ledger.py"

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  LEDGER="$ROOT_DIR/scripts/l27-facts-ledger.py"
  TMPD="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPD" 2>/dev/null || true
}

# Synthetic vault: one verified case with a result (hecho), one draft (humo),
# one non-case note and one non-markdown file.
make_vault() {
  local v="$TMPD/vault"
  mkdir -p "$v"
  printf -- '---\nentity: {type: phronesis-case, id: fr-001}\nmadurez: verified\nconsequence: {resultado: ok}\ndominio:\n- SFT\n---\n' > "$v/a.md"
  printf -- '---\nentity: {type: phronesis-case, id: fr-002}\nmadurez: draft\n---\n' > "$v/b.md"
  printf -- '---\nentity: {type: nota, id: n-1}\n---\n' > "$v/c.md"
  echo "ignored" > "$v/d.txt"
  echo "$v"
}

load_ledger() {
  python3 -c "
import importlib.util
spec = importlib.util.spec_from_file_location('ledger', '$LEDGER')
ledger = importlib.util.module_from_spec(spec); spec.loader.exec_module(ledger)
$1
"
}

@test "L27-E3: facts-ledger extrae hechos verificados y marca humo" {
  # vaults/ está gitignored: el seed verificado solo existe en el checkout local.
  [[ -d "$ROOT_DIR/vaults/Fronesia" ]] || skip "vault local Fronesia no presente (gitignored)"
  local out="$BATS_TEST_TMPDIR/l27-facts-ledger.jsonl"
  run python3 "$ROOT_DIR/scripts/l27-facts-ledger.py" --vault "$ROOT_DIR/vaults/Fronesia" --out "$out"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys
r=json.load(sys.stdin)
assert r['hechos'] >= 6, r   # seed verificado
assert 'ratio_hechos' in r
assert isinstance(r['humo_ids'], list)
"
  [ -f "$out" ]
  [ "$(wc -l < "$out")" -ge 6 ]
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

@test "L27-E3: vault sintético → 1 hecho, 1 humo; el ledger solo guarda hechos" {
  v=$(make_vault)
  run python3 "$LEDGER" --vault "$v" --out "$TMPD/ledger.jsonl"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
r = json.load(sys.stdin)
assert r['hechos'] == 1 and r['humo'] == 1, r
assert r['humo_ids'] == ['fr-002'], r
assert r['ratio_hechos'] == 0.5, r
"
  [ "$(wc -l < "$TMPD/ledger.jsonl")" -eq 1 ]
  grep -q '"id": "fr-001"' "$TMPD/ledger.jsonl"
}

@test "L27-E3: nonexistent vault → exit 1 con error" {
  run python3 "$LEDGER" --vault "$TMPD/no-existe" --out "$TMPD/o.jsonl"
  [ "$status" -eq 1 ]
  [[ "$output" == *"sin fronemas"* ]]
  [ ! -e "$TMPD/o.jsonl" ]
}

@test "L27-E3: empty vault → exit 1" {
  mkdir -p "$TMPD/empty"
  run python3 "$LEDGER" --vault "$TMPD/empty" --out "$TMPD/o.jsonl"
  [ "$status" -eq 1 ]
}

@test "L27: invalid arguments rejected (exit 2)" {
  run python3 "$LEDGER" --bogus
  [ "$status" -eq 2 ]
  run python3 "$ROOT_DIR/scripts/l27-score-synthetic.py" --seed abc
  [ "$status" -eq 2 ]
}

@test "L27-E3: parse_frontmatter lee dict inline y listas; sin frontmatter → {}" {
  run load_ledger "
text = '---\nentity: {type: x, id: y}\ndominio:\n- A\n- B\nmadurez: verified\n---\nbody'
c = ledger.parse_frontmatter(text)
assert c['entity'] == {'type': 'x', 'id': 'y'}, c
assert c['dominio'] == ['A', 'B'], c
assert c['madurez'] == 'verified', c
assert ledger.parse_frontmatter('sin frontmatter') == {}
print('ok')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "L27-E3: cid usa entity.id, luego id, luego '?' (empty case)" {
  run load_ledger "
assert ledger.cid({'entity': {'id': 'e1'}, 'id': 'x'}) == 'e1'
assert ledger.cid({'id': 'x'}) == 'x'
assert ledger.cid({}) == '?'
assert ledger.iso_now().endswith('Z')
print('ok')"
  [ "$status" -eq 0 ]
}

@test "L27-E3: scan ignora no-markdown, notas que no son casos y dirs nonexistent" {
  v=$(make_vault)
  run load_ledger "
cases = ledger.scan('$v')
assert sorted(c['_file'] for c in cases) == ['a.md', 'b.md'], cases
assert ledger.scan('$TMPD/nope') == []
print('ok')"
  [ "$status" -eq 0 ]
}
