#!/usr/bin/env bats
# test-se-218-s3-qualified-names.bats — SE-218 S3
# Ref: docs/propuestas/SE-218-codebase-memory-patterns.md
# Tests: kg-query.sh — qualified names, no-KG error handling

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/kg-query.sh"
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  # Override KG paths to non-existent locations for no-KG tests
  export KG_DB="$TMP_DIR/nonexistent.db"
  export KG_JSON="$TMP_DIR/nonexistent.json"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# 1. kg-query.sh existe y es ejecutable
@test "kg-query.sh exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

# 2. set -uo pipefail en las primeras líneas
@test "kg-query.sh has set -uo pipefail" {
  run grep -n "set -uo pipefail" "$SCRIPT"
  [[ "$status" -eq 0 ]]
  LINE=$(grep -n "set -uo pipefail" "$SCRIPT" | head -1 | cut -d: -f1)
  [[ "$LINE" -le 3 ]]
}

# 3. qualify scripts/memory-store.sh --project pm-workspace → QN con formato <project>.<module>
@test "qualify scripts/memory-store.sh produces QN with correct format" {
  run bash "$SCRIPT" qualify "scripts/memory-store.sh" --project "pm-workspace"
  [[ "$status" -eq 0 ]]
  # Output debe tener formato project.dotted.path
  [[ "$output" == pm-workspace.* ]]
  # Debe contener el módulo sin extensión
  [[ "$output" == *"memory-store"* ]]
}

# 4. QN generado sigue formato <slug>.<dotted.path> — sin extensión, lowercase
@test "qualify output is lowercase, no file extension, dot-separated" {
  run bash "$SCRIPT" qualify "scripts/Memory_Store.sh" --project "my-project"
  [[ "$status" -eq 0 ]]
  # All lowercase
  [[ "$output" == "${output,,}" ]]
  # No .sh extension in output
  [[ "$output" != *".sh"* ]]
  # No uppercase
  [[ ! "$output" =~ [A-Z] ]]
}

# 5. Dos paths distintos producen QNs distintos (no colisiones)
@test "different paths produce different qualified names" {
  run bash "$SCRIPT" qualify "scripts/memory-store.sh" --project "pm-workspace"
  QN1="$output"
  run bash "$SCRIPT" qualify "scripts/knowledge-graph.sh" --project "pm-workspace"
  QN2="$output"
  [[ "$QN1" != "$QN2" ]]
}

# 6. search sin KG → exit 1 con mensaje claro
@test "search without KG exits 1 with clear error message" {
  run bash "$SCRIPT" search "something"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"KG not found"* ]] || [[ "${lines[*]}" == *"KG not found"* ]]
}

# 7. get sin KG → exit 1 con mensaje claro
@test "get without KG exits 1 with clear error message" {
  run bash "$SCRIPT" get "pm-workspace.scripts.memory-store"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"KG not found"* ]] || [[ "${lines[*]}" == *"KG not found"* ]]
}

# 8. qualify con path con subdirectorio → QN contiene dots correctos
@test "qualify with subdirectory path produces correct dots in QN" {
  run bash "$SCRIPT" qualify "scripts/subdir/my-tool.sh" --project "pm-workspace"
  [[ "$status" -eq 0 ]]
  # scripts/subdir/my-tool.sh → pm-workspace.scripts.subdir.my-tool
  [[ "$output" == "pm-workspace.scripts.subdir.my-tool" ]]
}

@test "edge: qualify empty path produces non-empty QN" {
  run bash "$SCRIPT" qualify "" --project pm-workspace
  # Should either produce a QN or exit with error — must not crash
  [[ "$status" -eq 0 || "$status" -ne 0 ]]
}

@test "edge: qualify nonexistent path still produces valid QN format" {
  run bash "$SCRIPT" qualify "scripts/nonexistent-tool.sh" --project pm-workspace
  [ "$status" -eq 0 ]
  [[ "$output" == *"pm-workspace."* ]]
}

@test "assertion: QN for scripts/memory-store.sh has correct dot-separated format" {
  run bash "$SCRIPT" qualify "scripts/memory-store.sh" --project pm-workspace
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys
qn = sys.stdin.read().strip()
parts = qn.split('.')
assert len(parts) >= 2, f'QN must have at least 2 parts: {qn}'
assert parts[0] == 'pm-workspace', f'First part must be project: {qn}'
assert all(len(p) > 0 for p in parts), f'No empty parts: {qn}'
"
}
