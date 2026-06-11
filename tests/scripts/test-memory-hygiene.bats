#!/usr/bin/env bats
# tests/scripts/test-memory-hygiene.bats — SPEC-142: memory hygiene

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/memory-hygiene.sh"

setup() {
  TMPDIR_MEM="$BATS_TEST_TMPDIR/memory"
  mkdir -p "$TMPDIR_MEM"
  export DRY_RUN=false
}

teardown() {
  rm -rf "$TMPDIR_MEM"
}

@test "script es bash valido" {
  bash -n "$SCRIPT"
}

@test "script uses set -uo pipefail" {
  head -10 "$SCRIPT" | grep -q "set -[euo]*o pipefail"
}

@test "error: invalid path argument handled gracefully" {
  run bash "$SCRIPT" "/nonexistent/path/$$"
  [ "$status" -eq 0 ]
}

@test "directorio inexistente → exit 0 sin error" {
  run bash "$SCRIPT" "/tmp/nonexistent-$$-memory"
  [ "$status" -eq 0 ]
}

@test "directorio vacio → exit 0" {
  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
}

@test "archivo antiguo → archivado" {
  # Crear fichero con fecha antigua (>90 dias)
  old_file="$TMPDIR_MEM/old-memory.md"
  echo "# Old Memory" > "$old_file"
  touch -d "100 days ago" "$old_file"

  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
  [[ -f "$TMPDIR_MEM/archive/old-memory.md" ]]
  [[ ! -f "$old_file" ]]
}

@test "archivo reciente → no archivado" {
  recent_file="$TMPDIR_MEM/recent-memory.md"
  echo "# Recent Memory" > "$recent_file"

  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
  [[ -f "$recent_file" ]]
}

@test "MEMORY.md con duplicados por topic_key → deduplicado" {
  # Formato canónico actual: "- {type}: {title} [{topic_key}]"
  # El bloque ENTRIES_START/END acota el área dedupada (resto del fichero intacto).
  cat > "$TMPDIR_MEM/MEMORY.md" << 'EOF'
# Header
<!-- ENTRIES_START -->
- decision: first save [decision/use-redis]
- decision: another decision [decision/use-postgres]
- decision: same key again [decision/use-redis]
- discovery: third entry [discovery/coverage-gap]
- decision: same key once more [decision/use-redis]
<!-- ENTRIES_END -->
EOF

  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
  # Tras dedup: 3 topic_keys únicos (use-redis, use-postgres, coverage-gap)
  unique_keys=$(grep -oE '\[[^]]+\]' "$TMPDIR_MEM/MEMORY.md" | sort -u | wc -l)
  [ "$unique_keys" -eq 3 ]
  # El total de líneas con entries debe ser 3 (no 5)
  entry_count=$(grep -c '^- ' "$TMPDIR_MEM/MEMORY.md" || true)
  [ "$entry_count" -eq 3 ]
  # El bloque ENTRIES_START/END sigue presente
  grep -q '<!-- ENTRIES_START -->' "$TMPDIR_MEM/MEMORY.md"
  grep -q '<!-- ENTRIES_END -->' "$TMPDIR_MEM/MEMORY.md"
}

@test "MEMORY.md sin duplicados → sin cambios" {
  cat > "$TMPDIR_MEM/MEMORY.md" << 'EOF'
# Header
<!-- ENTRIES_START -->
- decision: first [decision/a]
- decision: second [decision/b]
- discovery: third [discovery/c]
<!-- ENTRIES_END -->
EOF
  before=$(md5sum "$TMPDIR_MEM/MEMORY.md" | cut -d' ' -f1)
  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
  after=$(md5sum "$TMPDIR_MEM/MEMORY.md" | cut -d' ' -f1)
  [ "$before" = "$after" ]
}

@test "MEMORY.md con duplicados → mantiene la primera aparición (más reciente)" {
  # Las nuevas entries se insertan al inicio del bloque por memory-store.sh,
  # así que la PRIMERA aparición de un topic_key es la más reciente y debe sobrevivir.
  cat > "$TMPDIR_MEM/MEMORY.md" << 'EOF'
<!-- ENTRIES_START -->
- decision: NEW (rev 3) [decision/k]
- decision: middle (rev 2) [decision/k]
- decision: OLD (rev 1) [decision/k]
<!-- ENTRIES_END -->
EOF
  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
  # Solo debe quedar la línea con "NEW (rev 3)"
  grep -q "NEW (rev 3)" "$TMPDIR_MEM/MEMORY.md"
  ! grep -q "OLD (rev 1)" "$TMPDIR_MEM/MEMORY.md"
  ! grep -q "middle (rev 2)" "$TMPDIR_MEM/MEMORY.md"
}

@test "MEMORY.md con referencia rota → eliminada" {
  cat > "$TMPDIR_MEM/MEMORY.md" << 'EOF'
- [exists](exists.md) — this file exists
- [broken](nonexistent.md) — this file is gone
EOF
  touch "$TMPDIR_MEM/exists.md"
  # nonexistent.md no se crea

  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
  grep -q "exists.md" "$TMPDIR_MEM/MEMORY.md"
  ! grep -q "nonexistent.md" "$TMPDIR_MEM/MEMORY.md"
}

@test "dry-run no modifica ficheros" {
  old_file="$TMPDIR_MEM/old-memory.md"
  echo "# Old" > "$old_file"
  touch -d "100 days ago" "$old_file"

  export DRY_RUN=true
  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
  # Fichero no debería moverse en dry-run
  [[ -f "$old_file" ]]
}

@test "idempotente: ejecutar dos veces produce el mismo resultado" {
  touch "$TMPDIR_MEM/entry1.md" "$TMPDIR_MEM/entry2.md"
  cat > "$TMPDIR_MEM/MEMORY.md" << 'EOF'
- [entry1](entry1.md) — first
- [entry2](entry2.md) — second
EOF

  bash "$SCRIPT" "$TMPDIR_MEM"
  first=$(cat "$TMPDIR_MEM/MEMORY.md")
  bash "$SCRIPT" "$TMPDIR_MEM"
  second=$(cat "$TMPDIR_MEM/MEMORY.md")
  [ "$first" = "$second" ]
}

@test "edge: empty MEMORY.md handled gracefully" {
  touch "$TMPDIR_MEM/MEMORY.md"
  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
  [[ -f "$TMPDIR_MEM/MEMORY.md" ]]
}

@test "edge: large number of files still completes" {
  for i in $(seq 1 20); do echo "# Entry $i" > "$TMPDIR_MEM/entry-$i.md"; done
  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
}

@test "archive directory created on first archival" {
  old_file="$TMPDIR_MEM/archived-entry.md"
  echo "# Old" > "$old_file"
  touch -d "100 days ago" "$old_file"
  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
  [[ -d "$TMPDIR_MEM/archive" ]]
}
