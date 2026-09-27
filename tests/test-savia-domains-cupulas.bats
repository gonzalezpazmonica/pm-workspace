#!/usr/bin/env bats
# Ref: Labs L23 — apertura de cúpulas N1 por dominio (SaviaDomains)
# Catálogo: docs/domains/savia-domains-catalog.md

SCRIPT="scripts/savia-domains-cupulas.py"

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

@test "L23: missing catalog → exit 2 con error claro, sin traceback" {
  run python3 "$GEN" --catalog "$TMPD/no-existe.md" --vault "$TMPD/vault"
  [ "$status" -eq 2 ]
  [[ "$output" == *"catálogo no encontrado"* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "L23: empty catalog (sin dominios) → exit 2" {
  : > "$TMPD/vacio.md"
  run python3 "$GEN" --catalog "$TMPD/vacio.md" --vault "$TMPD/vault"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no se extrajeron dominios"* ]]
}

@test "L23: --check sobre un vault vacío falla (STALE, exit 1)" {
  mkdir -p "$TMPD/empty"
  run python3 "$GEN" --check --catalog "$CATALOG" --vault "$TMPD/empty"
  [ "$status" -eq 1 ]
  [[ "$output" == *"STALE: 34"* ]]
}

@test "L23: idempotente — la segunda generación no crea nada (zero)" {
  python3 "$GEN" --catalog "$CATALOG" --vault "$TMPD/vault" >/dev/null
  run python3 "$GEN" --catalog "$CATALOG" --vault "$TMPD/vault"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 cúpulas creadas"* ]]
}

@test "L23: invalid argument rejected (exit 2)" {
  run python3 "$GEN" --bogus
  [ "$status" -eq 2 ]
}

# Unit tests over the generator's functions (module has a dash: load by path).
load_gen() {
  python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('gen', '$GEN')
gen = importlib.util.module_from_spec(spec); spec.loader.exec_module(gen)
$1
"
}

@test "L23: parse_catalog extrae 34 dominios con id de 2-3 mayúsculas" {
  run load_gen "
rows = gen.parse_catalog('$CATALOG')
assert len(rows) == 34, len(rows)
assert all(2 <= len(r['id']) <= 3 and r['id'].isupper() for r in rows)
assert {'id', 'category', 'name', 'topics', 'capacity'} <= set(rows[0])
print('ok')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "L23: parse_catalog ignora cabecera, separador y filas con id inválido" {
  printf '| ID | Cat | Nombre | Temas |\n|---|---|---|---|\n| abc | X | Y | Z |\n| QQ | Cat | Nombre | Temas |\n' > "$TMPD/mini.md"
  run load_gen "
rows = gen.parse_catalog('$TMPD/mini.md')
assert [r['id'] for r in rows] == ['QQ'], rows
print('ok')"
  [ "$status" -eq 0 ]
}

@test "L23: index_content emite frontmatter N1 cupula-creada y '—' con temas vacíos" {
  run load_gen "
txt = gen.index_content({'id': 'QQ', 'category': 'Cat', 'name': 'Nombre', 'topics': '', 'capacity': ''})
assert 'lifecycle: cupula-creada' in txt and 'confidentiality: N1' in txt
assert 'id: cupula-qq' in txt and '\n—\n' in txt
assert 'T' in gen.iso_now() and gen.iso_now().endswith('Z')
print('ok')"
  [ "$status" -eq 0 ]
}

@test "L23: nonexistent vault path anidado se crea al generar" {
  run python3 "$GEN" --catalog "$CATALOG" --vault "$TMPD/a/b/vault"
  [ "$status" -eq 0 ]
  [ "$(find "$TMPD/a/b/vault" -mindepth 2 -name INDEX.md | wc -l)" -eq 34 ]
}
