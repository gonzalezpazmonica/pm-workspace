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

@test "L23: cada cúpula tiene frontmatter válido (lifecycle cupula-creada, N1)" {
  for f in "$VAULT"/*/*/INDEX.md; do
    [[ -f "$f" ]] || continue
    grep -q 'lifecycle: cupula-creada' "$f"
    grep -q 'confidentiality: N1' "$f"
  done
}

@test "L23: --check sobre el vault real → OK (34 presentes)" {
  "$GEN" --check --catalog "$CATALOG" --vault "$VAULT"
}

@test "L23: CRIT-001 — generador sin red" {
  ! grep -rniE 'http://|https://|requests\.|urllib|boto3|openai|anthropic' "$GEN"
}
