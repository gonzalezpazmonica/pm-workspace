#!/usr/bin/env bats
# Ref: Labs L23 — apertura de cúpulas N1 por dominio (SaviaDomains)

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  GEN="$ROOT_DIR/scripts/savia-domains-cupulas.py"
  CATALOG="$ROOT_DIR/docs/domains/savia-domains-catalog.md"
  VAULT="$ROOT_DIR/vaults/SaviaDomains"
  TMPD="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPD" 2>/dev/null || true
}

@test "L23: dome SaviaDomains registrado en savia-vaults.domes.json (N1)" {
  python3 -c "
import json
d=json.load(open('$ROOT_DIR/projects/savia-vaults/savia-vaults.domes.json'))
dom=d['domes'].get('SaviaDomains')
assert dom, 'SaviaDomains no registrado'
assert dom['confidentiality']=='N1', dom
"
}

@test "L23: generador existe y crea cúpulas para los 34 dominios del catálogo" {
  # en un vault temporal, sin tocar el real
  mkdir -p "$TMPD/vault"
  "$GEN" --catalog "$CATALOG" --vault "$TMPD/vault" >/dev/null
  n=$(find "$TMPD/vault" -mindepth 2 -name INDEX.md | wc -l)
  [ "$n" -eq 34 ]
}

@test "L23: el generador crea cada cúpula con lifecycle cupula-creada y N1" {
  mkdir -p "$TMPD/vault"
  "$GEN" --catalog "$CATALOG" --vault "$TMPD/vault" >/dev/null
  for f in "$TMPD/vault"/*/*/INDEX.md; do
    grep -q '^lifecycle: cupula-creada$' "$f"
    grep -q '^confidentiality: N1$' "$f"
  done
}

@test "L23: cada cúpula del vault real tiene lifecycle válido y N1" {
  [[ -d "$VAULT" ]] || skip "vault local SaviaDomains no presente (gitignored)"
  # Una cúpula nace cupula-creada y pasa a digerida al procesar su dominio
  # (ej. RBT, docs/domains/savia-domains-catalog.md).
  for f in "$VAULT"/*/*/INDEX.md; do
    grep -qE '^lifecycle: (cupula-creada|digerida)$' "$f"
    grep -q '^confidentiality: N1$' "$f"
  done
}

@test "L23: --check sobre el vault real → OK (34 presentes)" {
  # vaults/ está gitignored: solo existe en el checkout local de la operadora.
  [[ -d "$VAULT" ]] || skip "vault local SaviaDomains no presente (gitignored)"
  "$GEN" --check --catalog "$CATALOG" --vault "$VAULT"
}

@test "L23: CRIT-001 — generador sin red" {
  ! grep -rniE 'http://|https://|requests\.|urllib|boto3|openai|anthropic' "$GEN"
}
