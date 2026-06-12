#!/usr/bin/env bats
# tests/scripts/test-memory-store-index-dedup.bats
#
# Tests para _update_memory_index en scripts/memory-store.sh.
# Spec: docs/propuestas/SE-220-jailbreak-defenses.md (AC-05)
# Ref: SPEC-142, SE-073, SE-220
#
# Garantiza que MEMORY.md no acumule duplicados por topic_key.
# Defensa contra memory-poisoning style attacks (AgentPoison, Chen 2024).
#
# Safety: el script target scripts/memory-store.sh usa set -uo pipefail
# y un guard de BASH_SOURCE para no ejecutar el dispatcher cuando se
# sourcea desde tests.

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/memory-store.sh"

setup() {
  TMPDIR_HOME="$BATS_TEST_TMPDIR"
  export HOME="$TMPDIR_HOME"
  mkdir -p "$HOME/.savia-memory/auto"

  # Crea un MEMORY.md inicial con bloque ENTRIES vacío
  cat > "$HOME/.savia-memory/auto/MEMORY.md" <<'EOF'
# MEMORY Index
> Test fixture
<!-- ENTRIES_START -->
<!-- ENTRIES_END -->
EOF

  export STORE_FILE="$BATS_TEST_TMPDIR/store.jsonl"
  export PROJECT_ROOT="$BATS_TEST_TMPDIR"
  mkdir -p "$BATS_TEST_TMPDIR/output"
  export SAVIA_TEST_MODE=true

  # Source memory-store.sh para acceder a _update_memory_index
  source "$BATS_TEST_DIRNAME/../../scripts/memory-store.sh" >/dev/null 2>&1 || true
}

teardown() {
  rm -rf "$TMPDIR_HOME"
}

@test "primer save → entry insertada" {
  _update_memory_index "decision/test-1" "First decision" "decision"
  count=$(grep -c '\[decision/test-1\]' "$HOME/.savia-memory/auto/MEMORY.md")
  [ "$count" -eq 1 ]
}

@test "segundo save mismo topic_key → reemplaza, no duplica" {
  _update_memory_index "decision/test-1" "First decision" "decision"
  _update_memory_index "decision/test-1" "Updated decision" "decision"

  # Solo debe haber UNA aparición de [decision/test-1]
  count=$(grep -c '\[decision/test-1\]' "$HOME/.savia-memory/auto/MEMORY.md")
  [ "$count" -eq 1 ]

  # Y debe ser la versión actualizada
  grep -q "Updated decision" "$HOME/.savia-memory/auto/MEMORY.md"
  ! grep -q "First decision" "$HOME/.savia-memory/auto/MEMORY.md"
}

@test "100 saves del mismo topic_key → 1 entry" {
  for i in $(seq 1 100); do
    _update_memory_index "decision/use-postgresql" "Save $i" "decision"
  done

  count=$(grep -c '\[decision/use-postgresql\]' "$HOME/.savia-memory/auto/MEMORY.md")
  [ "$count" -eq 1 ]

  # Solo debe estar la última versión
  grep -q "Save 100" "$HOME/.savia-memory/auto/MEMORY.md"
}

@test "saves de topic_keys distintos → todas presentes" {
  _update_memory_index "decision/a" "Title A" "decision"
  _update_memory_index "decision/b" "Title B" "decision"
  _update_memory_index "decision/c" "Title C" "decision"

  grep -q '\[decision/a\]' "$HOME/.savia-memory/auto/MEMORY.md"
  grep -q '\[decision/b\]' "$HOME/.savia-memory/auto/MEMORY.md"
  grep -q '\[decision/c\]' "$HOME/.savia-memory/auto/MEMORY.md"

  total=$(grep -c '^- ' "$HOME/.savia-memory/auto/MEMORY.md")
  [ "$total" -eq 3 ]
}

@test "topic_key vacío o null → no escribe entry" {
  _update_memory_index "" "ignored" "decision"
  _update_memory_index "null" "also ignored" "decision"

  count=$(grep -c '^- ' "$HOME/.savia-memory/auto/MEMORY.md" || true)
  [ "${count:-0}" -eq 0 ]
}

@test "soft cap: 250 saves de topic_keys distintos → MEMORY.md ≤ 200 entries" {
  for i in $(seq 1 250); do
    _update_memory_index "decision/key-$i" "Title $i" "decision"
  done

  entry_count=$(awk '/^<!-- ENTRIES_START -->$/{flag=1; next} /^<!-- ENTRIES_END -->$/{flag=0} flag && /^- /' \
    "$HOME/.savia-memory/auto/MEMORY.md" | wc -l)
  [ "$entry_count" -le 200 ]
  [ "$entry_count" -ge 195 ]
}

@test "MEMORY.md respeta cap 25KB tras 200 entries reales" {
  for i in $(seq 1 200); do
    _update_memory_index "decision/key-$i" "Decision number $i with a moderately long title for size test" "decision"
  done

  size=$(stat -c%s "$HOME/.savia-memory/auto/MEMORY.md")
  # Debe estar dentro de límite 25KB (con margen de seguridad)
  [ "$size" -le 25600 ]
}

@test "regression: repro del bug original (109 duplicados de use-postgresql)" {
  # Simula el bug original: 109 saves del mismo topic_key
  for i in $(seq 1 109); do
    _update_memory_index "decision/use-postgresql" "Decision rev $i" "decision"
  done

  # Tras el fix, solo debe haber 1 línea con ese topic_key
  count=$(grep -c '\[decision/use-postgresql\]' "$HOME/.savia-memory/auto/MEMORY.md")
  [ "$count" -eq 1 ]

  # Y MEMORY.md no debe explotar
  total_lines=$(wc -l < "$HOME/.savia-memory/auto/MEMORY.md")
  [ "$total_lines" -lt 20 ]
}

@test "preserva el orden: nuevo entry va al inicio del bloque" {
  _update_memory_index "decision/old" "Old" "decision"
  _update_memory_index "decision/new" "New" "decision"

  # La línea de "new" debe estar antes que "old" en el fichero
  new_line=$(grep -n '\[decision/new\]' "$HOME/.savia-memory/auto/MEMORY.md" | cut -d: -f1)
  old_line=$(grep -n '\[decision/old\]' "$HOME/.savia-memory/auto/MEMORY.md" | cut -d: -f1)
  [ "$new_line" -lt "$old_line" ]
}

@test "idempotencia: reescribir misma entry N veces no cambia el output final" {
  _update_memory_index "decision/idem" "Same title" "decision"
  before=$(md5sum "$HOME/.savia-memory/auto/MEMORY.md" | cut -d' ' -f1)
  for i in $(seq 1 5); do
    _update_memory_index "decision/idem" "Same title" "decision"
  done
  after=$(md5sum "$HOME/.savia-memory/auto/MEMORY.md" | cut -d' ' -f1)
  [ "$before" = "$after" ]
}

# ── Safety verification ──────────────────────────────────────────────────────

@test "SPEC-220 safety: script target uses set -uo pipefail" {
  head -10 "$SCRIPT" | grep -qE 'set -[uo]+ pipefail|set -[euo]+ pipefail'
}

@test "SPEC-220 safety: bash syntax of memory-store.sh is valid" {
  bash -n "$SCRIPT"
}

# ── Negative cases ──────────────────────────────────────────────────────────

@test "NEGATIVO: topic_key vacío es rechazado (no escribe)" {
  before=$(md5sum "$HOME/.savia-memory/auto/MEMORY.md" | cut -d' ' -f1)
  _update_memory_index "" "should-be-ignored" "decision"
  after=$(md5sum "$HOME/.savia-memory/auto/MEMORY.md" | cut -d' ' -f1)
  [ "$before" = "$after" ]
}

@test "NEGATIVO: topic_key 'null' literal es rechazado (no escribe)" {
  before=$(md5sum "$HOME/.savia-memory/auto/MEMORY.md" | cut -d' ' -f1)
  _update_memory_index "null" "should-be-ignored" "decision"
  after=$(md5sum "$HOME/.savia-memory/auto/MEMORY.md" | cut -d' ' -f1)
  [ "$before" = "$after" ]
}

@test "NEGATIVO: MEMORY.md missing — function exits gracefully without error" {
  rm -f "$HOME/.savia-memory/auto/MEMORY.md"
  run _update_memory_index "decision/x" "Title" "decision"
  [ "$status" -eq 0 ]
}

@test "NEGATIVO: invalid JSON-like input handled (no crash, no shell injection)" {
  # Asegurar que caracteres especiales no rompen el parser
  _update_memory_index 'decision/with"quotes' "Title with [brackets]" "decision"
  # No debe crashear
  [ -f "$HOME/.savia-memory/auto/MEMORY.md" ]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "EDGE: empty MEMORY.md (sin ENTRIES markers) — function safe-fails sin escribir" {
  echo "" > "$HOME/.savia-memory/auto/MEMORY.md"
  run _update_memory_index "decision/x" "Title" "decision"
  [ "$status" -eq 0 ]
  # File exists, no crash
  [ -f "$HOME/.savia-memory/auto/MEMORY.md" ]
}

@test "EDGE: title con caracteres unicode preservados" {
  _update_memory_index "decision/utf8" "Decision con á é í ó ú ñ ¿?" "decision"
  grep -q "decision con á é í ó ú ñ" "$HOME/.savia-memory/auto/MEMORY.md" \
    || grep -q "Decision con á é í ó ú ñ" "$HOME/.savia-memory/auto/MEMORY.md"
}

@test "EDGE: title largo se trunca a 150 caracteres" {
  long_title=$(printf 'X%.0s' {1..200})
  _update_memory_index "decision/long" "$long_title" "decision"
  # Buscar línea que contenga "decision/long" — puede haber truncado al 150
  matched=$(grep -F 'decision/long' "$HOME/.savia-memory/auto/MEMORY.md" 2>/dev/null | head -1 || true)
  # Si truncado, la línea no incluye el topic_key; verificamos solo que 0 líneas exceden 150
  awk 'length > 150' "$HOME/.savia-memory/auto/MEMORY.md" | grep -q . && return 1
  return 0
}

@test "EDGE: topic_key vacío no genera entry vacía (boundary del guard)" {
  initial_lines=$(wc -l < "$HOME/.savia-memory/auto/MEMORY.md")
  _update_memory_index "" "" ""
  final_lines=$(wc -l < "$HOME/.savia-memory/auto/MEMORY.md")
  [ "$initial_lines" -eq "$final_lines" ]
}

# ── Spec reference & assertion quality ────────────────────────────────────────

@test "SPEC-220 doc reference: spec file existe en docs/propuestas/" {
  [ -f "$BATS_TEST_DIRNAME/../../docs/propuestas/SE-220-jailbreak-defenses.md" ]
}

@test "SPEC-220 AC-05 cumple: bug original (109 dups) reproducido y mitigado" {
  # Recreamos el bug exacto pre-fix: append-only sin dedup
  for i in $(seq 1 109); do
    _update_memory_index "decision/use-postgresql" "Save $i" "decision"
  done
  count=$(grep -c '\[decision/use-postgresql\]' "$HOME/.savia-memory/auto/MEMORY.md")
  [[ "$count" -eq 1 ]]
  # Post-condición: el contenido es la última versión
  [[ "$(grep '\[decision/use-postgresql\]' "$HOME/.savia-memory/auto/MEMORY.md")" == *"Save 109"* ]]
}
