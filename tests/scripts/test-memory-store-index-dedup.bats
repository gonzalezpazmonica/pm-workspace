#!/usr/bin/env bats
# tests/scripts/test-memory-store-index-dedup.bats
#
# Tests para _update_memory_index en scripts/memory-store.sh.
#
# Garantiza que MEMORY.md no acumule duplicados por topic_key.
# Defensa contra memory-poisoning style attacks (AgentPoison, Chen 2024).
# Ref: SE-073, SPEC-142.

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
