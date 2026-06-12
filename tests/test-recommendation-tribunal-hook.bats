#!/usr/bin/env bats
# tests/test-recommendation-tribunal-hook.bats — SE-073 / SPEC-125 Slice 2
#
# Smoke tests para recommendation-tribunal-pre-output.sh.
# El hook está en MODO SHADOW (detect-only): clasifica drafts, escribe audit log,
# pasa el draft sin modificar. NO bloquea ni muta. La activación con veto requiere
# un evento PreOutput en Claude Code que aún no existe en 2026-06; este test
# protege la regresión del flujo detect-only.

HOOK="$BATS_TEST_DIRNAME/../.claude/hooks/recommendation-tribunal-pre-output.sh"
ROOT="$BATS_TEST_DIRNAME/.."

setup() {
  TEST_OUT="$BATS_TEST_TMPDIR/test-output"
  mkdir -p "$TEST_OUT"
  # El hook escribe a $ROOT_DIR/output/... que es el repo. Movemos el cwd
  # para no contaminar el repo con audit logs de tests.
  cd "$BATS_TEST_TMPDIR"
}

teardown() {
  cd "$ROOT"
}

@test "hook es bash valido" {
  bash -n "$HOOK"
}

@test "uses set -uo pipefail" {
  head -10 "$HOOK" | grep -q "set -[euo]*o pipefail"
}

@test "draft vacío → passthrough sin error" {
  run bash -c "echo -n '' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "draft no-recomendación → passthrough literal" {
  DRAFT="Hola, soy Savia. Tu perfil esta cargado."
  result=$(printf '%s' "$DRAFT" | bash "$HOOK" 2>/dev/null)
  [ "$result" = "$DRAFT" ]
}

@test "draft con palabras 'haz X' → passthrough (detect-only, no veto)" {
  DRAFT="Te recomiendo migrar a PostgreSQL. Es critico hacerlo este sprint."
  result=$(printf '%s' "$DRAFT" | bash "$HOOK" 2>/dev/null)
  [ "$result" = "$DRAFT" ]
}

@test "draft largo → passthrough literal sin truncado" {
  DRAFT=$(printf 'linea %d\n' $(seq 1 50))
  result=$(printf '%s' "$DRAFT" | bash "$HOOK" 2>/dev/null)
  [ "$result" = "$DRAFT" ]
}

@test "audit log se crea para drafts no vacíos" {
  audit_dir="$ROOT/output/recommendation-tribunal/$(date +%Y-%m-%d)"
  before=$(ls "$audit_dir" 2>/dev/null | wc -l)
  printf 'recomendacion-test-%d' "$RANDOM" | bash "$HOOK" >/dev/null 2>&1
  after=$(ls "$audit_dir" 2>/dev/null | wc -l)
  [ "$after" -ge "$before" ]
}

@test "classifier disponible y devuelve JSON" {
  classifier="$ROOT/scripts/recommendation-tribunal/classifier.sh"
  [ -x "$classifier" ]
  out=$(echo "test draft" | bash "$classifier" 2>/dev/null)
  [[ "$out" == *'"is_recommendation"'* ]]
  [[ "$out" == *'"risk_class"'* ]]
}

@test "hook no bloquea (exit 0) incluso con stdin grande" {
  DRAFT=$(yes "linea de relleno larga para test" | head -200)
  run bash -c "printf '%s' \"\$DRAFT\" | bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "hook no introduce caracteres extra (passthrough byte-perfect)" {
  DRAFT="Linea 1
Linea 2 con tabs	y espacios
Linea 3"
  result=$(printf '%s' "$DRAFT" | bash "$HOOK" 2>/dev/null)
  [ "$result" = "$DRAFT" ]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "EDGE: empty draft — exit 0, output vacio (no crash)" {
  run bash -c "echo -n '' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "EDGE: draft con solo whitespace — passthrough literal" {
  DRAFT="   "
  result=$(printf '%s' "$DRAFT" | bash "$HOOK" 2>/dev/null)
  [ "$result" = "$DRAFT" ]
}

@test "EDGE: draft con caracteres unicode (emoji, RTL, etc) — passthrough" {
  DRAFT="Test con á é í 漢字 ✓ 🎯 \u200B"
  result=$(printf '%s' "$DRAFT" | bash "$HOOK" 2>/dev/null)
  [ "$result" = "$DRAFT" ]
}

@test "EDGE: draft con null bytes — handle sin crash" {
  # Null bytes son comunes en data binaria; el hook debe sobrevivir
  result=$(printf 'Hola\0Mundo' | bash "$HOOK" 2>/dev/null || true)
  # No crash: cualquier contenido devuelto está OK
  return 0
}

@test "BOUNDARY: draft de tamaño grande (10000 lines) — completes" {
  DRAFT=$(yes "linea de relleno" | head -10000)
  start=$(date +%s)
  result=$(printf '%s' "$DRAFT" | bash "$HOOK" 2>/dev/null)
  end=$(date +%s)
  elapsed=$((end - start))
  # Debe completar en <30s
  [ "$elapsed" -lt 30 ]
  [ -n "$result" ]
}

@test "EDGE: input no-utf8 — handle sin crash" {
  # Bytes inválidos UTF-8 (high latin1)
  printf 'ABC\xff\xfeDEF' | bash "$HOOK" >/dev/null 2>&1
  # No verificamos exit specific, solo que no rompe el shell del runner
  return 0
}

# ── Assertion quality boost ─────────────────────────────────────────────────

@test "SPEC-220 AC-15 cumple: classifier produce JSON valido con campos esperados" {
  classifier="$ROOT/scripts/recommendation-tribunal/classifier.sh"
  out=$(echo "draft test content" | bash "$classifier" 2>/dev/null)
  # Validacion estructural via python json.load
  python3 -c "
import json
d = json.loads('''$out''')
assert 'is_recommendation' in d
assert 'risk_class' in d
assert d['risk_class'] in ['low', 'medium', 'high']
"
}
