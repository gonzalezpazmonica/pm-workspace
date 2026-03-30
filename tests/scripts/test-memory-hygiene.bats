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
  head -10 "$SCRIPT" | grep -q "set -uo pipefail"
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

@test "MEMORY.md con duplicados → deduplicado" {
  cat > "$TMPDIR_MEM/MEMORY.md" << 'EOF'
- [entry1](entry1.md) — first entry
- [entry2](entry2.md) — second entry
- [entry1](entry1.md) — duplicate of first
- [entry3](entry3.md) — third entry
EOF
  touch "$TMPDIR_MEM/entry1.md" "$TMPDIR_MEM/entry2.md" "$TMPDIR_MEM/entry3.md"

  run bash "$SCRIPT" "$TMPDIR_MEM"
  [ "$status" -eq 0 ]
  # Debería tener 3 líneas de entrada, no 4
  count=$(grep -c '\[entry' "$TMPDIR_MEM/MEMORY.md" || true)
  [ "$count" -eq 3 ]
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
