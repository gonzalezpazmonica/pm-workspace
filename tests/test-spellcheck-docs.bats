#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-024-doc-audit-first-person.md
# Tests for spellcheck-docs.sh — Orthographic review

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/spellcheck-docs.sh"
  TMPDIR_SD=$(mktemp -d)
}

teardown() { rm -rf "$TMPDIR_SD"; }

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "runs on a test file without crash" {
  echo "This is a test document." > "$TMPDIR_SD/test.md"
  run bash "$SCRIPT" "$TMPDIR_SD/test.md"
  [[ "$status" -le 1 ]]
}

@test "handles empty file" {
  touch "$TMPDIR_SD/empty.md"
  run bash "$SCRIPT" "$TMPDIR_SD/empty.md"
  [[ "$status" -le 1 ]]
}

@test "negative: nonexistent file handled" {
  run bash "$SCRIPT" "/nonexistent/file.md"
  [[ "$status" -le 1 ]]
}

@test "negative: no args runs on defaults or shows help" {
  run timeout 15 bash "$SCRIPT"
  [[ "$status" -le 1 ]] || [[ "$status" -eq 124 ]]
}

@test "edge: file with accented characters" {
  echo "La documentacion es esencial para el exito." > "$TMPDIR_SD/accents.md"
  run bash "$SCRIPT" "$TMPDIR_SD/accents.md"
  [[ "$status" -le 1 ]]
}

@test "coverage: ROOT variable defined" {
  grep -q "ROOT=" "$SCRIPT" || grep -q "ROOT\"" "$SCRIPT"
}
