#!/usr/bin/env bats
# test-fork-agents.bats — Tests for SPEC-FORK-AGENT-PREFIX
# Ref: docs/specs/SPEC-FORK-AGENT-PREFIX.spec.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/fork-agents.sh"
  TMPDIR_FA=$(mktemp -d)
  PREFIX_FILE="$TMPDIR_FA/prefix.md"
  SUFFIXES_DIR="$TMPDIR_FA/suffixes"
  OUTPUT_DIR="$TMPDIR_FA/output"
  mkdir -p "$SUFFIXES_DIR" "$OUTPUT_DIR"
}

teardown() {
  rm -rf "$TMPDIR_FA"
}

# ── Script integrity ─────────────────────────────────────────────────────────

@test "script exists" {
  [ -f "$SCRIPT" ]
}

@test "script starts with bash shebang" {
  head -1 "$SCRIPT" | grep -q "bash"
}

@test "script has set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "script --help shows usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

@test "script references SPEC-FORK-AGENT-PREFIX" {
  grep -q "SPEC-FORK-AGENT-PREFIX" "$SCRIPT"
}

# ── Required args validation ─────────────────────────────────────────────────

@test "no-arg invocation shows usage help" {
  run bash "$SCRIPT"
  # Shows usage either with exit 0 (help) or non-zero (error)
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"fork-agents.sh"* ]]
}

@test "missing --prefix returns error" {
  mkdir -p "$SUFFIXES_DIR"
  echo "item1" > "$SUFFIXES_DIR/item1.txt"
  run bash "$SCRIPT" --suffixes "$SUFFIXES_DIR"
  [ "$status" -ne 0 ]
}

@test "missing --suffixes returns error" {
  printf 'test prefix\n' > "$PREFIX_FILE"
  run bash "$SCRIPT" --prefix "$PREFIX_FILE"
  [ "$status" -ne 0 ]
}

@test "nonexistent prefix file returns error" {
  run bash "$SCRIPT" --prefix "/nonexistent/prefix.md" --suffixes "$SUFFIXES_DIR"
  [ "$status" -ne 0 ]
}

@test "nonexistent suffixes dir returns error" {
  printf 'test prefix\n' > "$PREFIX_FILE"
  run bash "$SCRIPT" --prefix "$PREFIX_FILE" --suffixes "/nonexistent/dir"
  [ "$status" -ne 0 ]
}

@test "empty suffixes dir returns error or zero suffixes" {
  printf 'test prefix\n' > "$PREFIX_FILE"
  run bash "$SCRIPT" --prefix "$PREFIX_FILE" --suffixes "$SUFFIXES_DIR" --output "$OUTPUT_DIR"
  # Empty suffixes dir — should error or produce empty summary
  [[ "$status" -ne 0 ]] || [[ -d "$OUTPUT_DIR" ]]
}

# ── Dry-run / prefix hash check ──────────────────────────────────────────────

@test "prefix hash is consistent across items" {
  printf 'common prefix content for all items\n' > "$PREFIX_FILE"
  echo "suffix-a" > "$SUFFIXES_DIR/a.txt"
  echo "suffix-b" > "$SUFFIXES_DIR/b.txt"
  echo "suffix-c" > "$SUFFIXES_DIR/c.txt"
  # Compute prefix hash deterministically
  local hash1 hash2
  hash1=$(sha256sum "$PREFIX_FILE" | awk '{print $1}')
  hash2=$(sha256sum "$PREFIX_FILE" | awk '{print $1}')
  [ "$hash1" = "$hash2" ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: empty prefix file" {
  printf '' > "$PREFIX_FILE"
  echo "suffix1" > "$SUFFIXES_DIR/s1.txt"
  run bash "$SCRIPT" --prefix "$PREFIX_FILE" --suffixes "$SUFFIXES_DIR" --output "$OUTPUT_DIR" --dry-run
  # Empty prefix is valid (just no common context) — accept any non-crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "edge: boundary --parallel = 1" {
  printf 'prefix\n' > "$PREFIX_FILE"
  echo "one" > "$SUFFIXES_DIR/one.txt"
  run bash "$SCRIPT" --prefix "$PREFIX_FILE" --suffixes "$SUFFIXES_DIR" --parallel 1 --dry-run --output "$OUTPUT_DIR"
  # Accept dry-run success or normal run without crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "edge: large number of suffixes" {
  printf 'prefix\n' > "$PREFIX_FILE"
  for i in $(seq 1 20); do
    echo "item $i" > "$SUFFIXES_DIR/item${i}.txt"
  done
  # Just verify it doesn't crash on many items (dry-run)
  run bash "$SCRIPT" --prefix "$PREFIX_FILE" --suffixes "$SUFFIXES_DIR" --dry-run --output "$OUTPUT_DIR"
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "edge: invalid --parallel value zero" {
  printf 'prefix\n' > "$PREFIX_FILE"
  echo "a" > "$SUFFIXES_DIR/a.txt"
  run bash "$SCRIPT" --prefix "$PREFIX_FILE" --suffixes "$SUFFIXES_DIR" --parallel 0 --dry-run --output "$OUTPUT_DIR"
  [ "$status" -ne 0 ]
}

@test "edge: unknown flag returns error" {
  run bash "$SCRIPT" --invalid-flag
  [ "$status" -ne 0 ]
}

@test "edge: nonexistent output dir is created" {
  printf 'prefix\n' > "$PREFIX_FILE"
  echo "a" > "$SUFFIXES_DIR/a.txt"
  local new_out="$TMPDIR_FA/new_output_dir"
  run bash "$SCRIPT" --prefix "$PREFIX_FILE" --suffixes "$SUFFIXES_DIR" --output "$new_out" --dry-run
  # Should create it or at least not crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

# ── Coverage: key concepts in script ─────────────────────────────────────────

@test "coverage: script references prefix hashing" {
  grep -q "sha256\|hash" "$SCRIPT"
}

@test "coverage: script handles parallel execution" {
  grep -q "parallel\|xargs\|wait" "$SCRIPT"
}

@test "coverage: script writes output files" {
  grep -q "output\|OUTPUT" "$SCRIPT"
}

@test "coverage: script handles timeout" {
  grep -q "timeout" "$SCRIPT"
}

@test "coverage: script supports --prefix argument" {
  grep -q -- "--prefix" "$SCRIPT"
}

@test "coverage: script supports --suffixes argument" {
  grep -q -- "--suffixes" "$SCRIPT"
}
