#!/usr/bin/env bats
# SE-407 S1 — frescura de artefactos generados en validate-ci-local.sh (gate G10 de pr-plan).
# Ref: docs/specs/SE-407-consistent-state-predicate.spec.md
set -uo pipefail

SCRIPT="scripts/validate-ci-local.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
}

# Tabla falsa: nombre|comprobación|cómo regenerar (override solo para tests).
fake_table() {
  printf '%s\n' \
    "rule-manifest.json|$1|bash scripts/rule-manifest-generate.sh" \
    "settings-hooks pin|true|bash scripts/contract-pin.sh pin settings-hooks --path .claude/settings.json" \
    ".scm/sam.json|$2 # sam.py check|python3 scripts/sam.py generate" \
    "docs/propuestas/INDEX.md|true|bash scripts/propuestas-index-gen.sh" \
    "planning-state.json|true|bash scripts/roadmap.sh render"
}

@test "safety: el script mantiene set -uo pipefail" {
  grep -q "set -uo pipefail" "$REPO_ROOT/$SCRIPT"
}

@test "AC1: un artefacto desfasado hace fallar el script y nombra el artefacto y su comando" {
  run env SAVIA_FRESH_CHECKS_FOR_TESTS="$(fake_table false true)" bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL Generado desfasado: rule-manifest.json → regenerar: bash scripts/rule-manifest-generate.sh"* ]]
  [[ "$output" == *"OK Generado al día: docs/propuestas/INDEX.md"* ]]
}

@test "AC1: varios desfasados se informan por separado" {
  run env SAVIA_FRESH_CHECKS_FOR_TESTS="$(fake_table false false)" bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"desfasado: rule-manifest.json"* ]]
  [[ "$output" == *"desfasado: .scm/sam.json → regenerar: python3 scripts/sam.py generate"* ]]
  [ "$(grep -c '^  FAIL Generado desfasado' <<<"$output")" -eq 2 ]
}

@test "AC2: todo al día ⇒ ninguna línea de desfasado y cinco comprobaciones al día" {
  run env SAVIA_FRESH_CHECKS_FOR_TESTS="$(fake_table true true)" bash "$REPO_ROOT/$SCRIPT"
  [[ "$output" != *"Generado desfasado"* ]]
  [ "$(grep -c 'Generado al día' <<<"$output")" -eq 5 ]
}

@test "AC3: --quick omite solo sam.py check, nunca los otros cuatro" {
  run env SAVIA_FRESH_CHECKS_FOR_TESTS="$(fake_table true false)" bash "$REPO_ROOT/$SCRIPT" --quick
  [[ "$output" != *".scm/sam.json"* ]]
  [ "$(grep -c 'Generado al día' <<<"$output")" -eq 4 ]
  run env SAVIA_FRESH_CHECKS_FOR_TESTS="$(fake_table false true)" bash "$REPO_ROOT/$SCRIPT" --quick
  [ "$status" -ne 0 ]
  [[ "$output" == *"desfasado: rule-manifest.json"* ]]
}

@test "la tabla por defecto ejecuta los cinco --check existentes, sin reimplementarlos" {
  for c in "rule-manifest-generate.sh --check" "contract-pin.sh check settings-hooks" "sam.py check" \
           "propuestas-index-gen.sh --check" "roadmap.sh validate"; do
    grep -qF "$c" "$REPO_ROOT/$SCRIPT"
  done
}

@test "edge: empty override ⇒ cero comprobaciones de frescura, sin error del script" {
  run env SAVIA_FRESH_CHECKS_FOR_TESTS=" " bash "$REPO_ROOT/$SCRIPT" --quick
  [[ "$output" != *"Generado"* ]]
  [[ "$output" == *"Results:"* ]]
}

@test "integración: en un clon con INDEX.md y rule-manifest desfasados, los detecta con las comprobaciones reales" {
  git clone -q --shared --depth 1 "file://$REPO_ROOT" "$TMP/repo"
  # Copia de trabajo: el script y sus dependencias son los del working tree (incluye cambios sin commit).
  cp "$REPO_ROOT/$SCRIPT" "$TMP/repo/$SCRIPT"
  printf '\n<!-- desfase de prueba -->\n' >> "$TMP/repo/docs/propuestas/INDEX.md"
  printf '# Regla de prueba\n\nTexto.\n' > "$TMP/repo/docs/rules/domain/zz-regla-de-prueba.md"
  run bash -c "cd '$TMP/repo' && bash $SCRIPT --quick"
  [ "$status" -ne 0 ]
  [[ "$output" == *"desfasado: docs/propuestas/INDEX.md → regenerar: bash scripts/propuestas-index-gen.sh"* ]]
  [[ "$output" == *"desfasado: rule-manifest.json → regenerar: bash scripts/rule-manifest-generate.sh"* ]]
  [[ "$output" == *"OK Generado al día: settings-hooks pin"* ]]
}
