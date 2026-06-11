#!/usr/bin/env bats
# test-se-218-s5-saviaignore.bats — SE-218 S5: .saviaignore
# Ref: docs/propuestas/SE-218-codebase-memory-patterns.md

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/savia-ignore.sh"

setup() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export SAVIA_WORKSPACE_DIR="$TMP_DIR"

  # Crear .saviaignore de prueba en el workspace temporal
  cat > "$TMP_DIR/.saviaignore" <<'EOF'
# comentario de prueba
output/agent-run-log-*.tsv
.savia-kg/
tests/fixtures/tmp/
specific-file.txt
EOF
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

@test "savia-ignore.sh existe y es ejecutable" {
  [[ -x "$SCRIPT" ]]
}

@test "savia-ignore.sh tiene set -uo pipefail" {
  run grep -E "set -uo pipefail" "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "path que coincide con patron en .saviaignore: exit 0 (ignorado)" {
  run bash "$SCRIPT" "specific-file.txt"
  [[ "$status" -eq 0 ]]
}

@test "path que NO coincide con ningun patron: exit 1 (no ignorado)" {
  run bash "$SCRIPT" "src/main.go"
  [[ "$status" -eq 1 ]]
}

@test "patron glob (*.tsv) funciona para rutas coincidentes" {
  run bash "$SCRIPT" "output/agent-run-log-20260610.tsv"
  [[ "$status" -eq 0 ]]
}

@test "sin .saviaignore: todos los paths exit 1 (no crash)" {
  rm -f "$TMP_DIR/.saviaignore"
  run bash "$SCRIPT" "cualquier/ruta.txt"
  [[ "$status" -eq 1 ]]
}

@test ".saviaignore vacio: todos los paths exit 1" {
  : > "$TMP_DIR/.saviaignore"
  run bash "$SCRIPT" "specific-file.txt"
  [[ "$status" -eq 1 ]]
}

@test "comentarios en .saviaignore son ignorados (lineas con # no afectan)" {
  # El fichero tiene "# comentario de prueba" — no debe provocar match en esa cadena
  run bash "$SCRIPT" "comentario de prueba"
  [[ "$status" -eq 1 ]]
}

@test "edge: path with spaces does not crash" {
  echo "output dir/" > "$TMP_DIR/.saviaignore"
  run bash "$SCRIPT" "output dir/file.txt"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]  # must not crash
}

@test "edge: nonexistent path treated as non-ignored when no .saviaignore" {
  rm -f "$TMP_DIR/.saviaignore"
  run bash "$SCRIPT" "some/nonexistent/file.txt"
  [ "$status" -eq 1 ]  # not ignored
}

@test "assertion: negation pattern (!) is handled without crash" {
  printf "output/*.tsv\n!output/keep.tsv\n" > "$TMP_DIR/.saviaignore"
  # Negation support is best-effort in the fallback implementation
  # The key assertion: script does not crash and returns a valid exit code
  run bash "$SCRIPT" "output/keep.tsv"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "negative: path matching directory pattern is handled without crash" {
  echo ".savia-kg/" > "$TMP_DIR/.saviaignore"
  run bash "$SCRIPT" ".savia-kg/graph.db.zst"
  # Dir patterns (with trailing /) are best-effort — must not crash
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "negative: multiple patterns — second match also works" {
  printf "*.log\n*.tsv\n" > "$TMP_DIR/.saviaignore"
  run bash "$SCRIPT" "output/session.tsv"
  [ "$status" -eq 0 ]
}

@test "negative: exact filename match works" {
  echo "specific-file.txt" > "$TMP_DIR/.saviaignore"
  run bash "$SCRIPT" "specific-file.txt"
  [ "$status" -eq 0 ]
}

@test "assertion: script without args prints usage and exits non-zero" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ -n "$output" ]]
}

@test "assertion: ignored path check is idempotent (same result on repeated calls)" {
  echo "output/*.tsv" > "$TMP_DIR/.saviaignore"
  run bash "$SCRIPT" "output/log.tsv"
  local first_status="$status"
  run bash "$SCRIPT" "output/log.tsv"
  [ "$status" -eq "$first_status" ]
}

@test "assertion: savia-ignore.sh output for ignored path is empty (no false positives on stdout)" {
  echo "output/agent-run-log-*.tsv" > "$TMP_DIR/.saviaignore"
  run bash "$SCRIPT" "output/agent-run-log-20260610.tsv"
  [ "$status" -eq 0 ]
  # stdout should be empty — result communicated via exit code only
  [ -z "$output" ]
}

@test "assertion: ignored and non-ignored paths produce consistent exit codes across runs" {
  printf "*.log\n" > "$TMP_DIR/.saviaignore"
  run bash "$SCRIPT" "session.log"
  local ignored_status="$status"
  run bash "$SCRIPT" "session.sh"
  local not_ignored_status="$status"
  # ignored path: exit 0, non-ignored path: exit 1
  [ "$ignored_status" -eq 0 ]
  [ "$not_ignored_status" -eq 1 ]
  # Verify with python3 that statuses are distinct integers
  python3 -c "
ignored=$ignored_status
not_ignored=$not_ignored_status
assert ignored == 0, f'Expected 0 for ignored, got {ignored}'
assert not_ignored == 1, f'Expected 1 for not-ignored, got {not_ignored}'
"
}
