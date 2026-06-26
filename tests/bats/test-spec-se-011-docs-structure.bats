#!/usr/bin/env bats
# test-spec-se-011-docs-structure.bats — SPEC-SE-011: docs restructuring tests
#
# Tests:
# 1. docs-audit.sh exists and is executable
# 2. --json produces valid JSON with required keys
# 3. docs/STRUCTURE.md exists with required sections (Nivel 1, Subcarpetas)
# 4. docs/INDEX.md exists with top 10 documents
# 5. audit detects root-level docs as candidates (>10 candidates expected)

setup() {
  REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"
  SCRIPT="$REPO_ROOT/scripts/docs-audit.sh"
  STRUCTURE="$REPO_ROOT/docs/STRUCTURE.md"
  INDEX="$REPO_ROOT/docs/INDEX.md"
  DOCS_DIR="$REPO_ROOT/docs"
}

# Test 1: docs-audit.sh exists and is executable
@test "docs-audit.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# Test 2: --json produces valid JSON with required top-level keys
@test "--json produces valid JSON with required keys" {
  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ]

  # Output must be valid JSON parseable by python3
  echo "$output" | python3 -m json.tool > /dev/null

  # Must contain required top-level keys
  [[ "$output" =~ '"date"' ]]
  [[ "$output" =~ '"summary"' ]]
  [[ "$output" =~ '"top_level_dirs"' ]]
  [[ "$output" =~ '"orphan_files"' ]]
  [[ "$output" =~ '"candidates_for_subdir"' ]]
  [[ "$output" =~ '"large_subdirs"' ]]
}

# Test 3: docs/STRUCTURE.md exists with required sections
@test "docs/STRUCTURE.md exists with Nivel 1 and Subcarpetas sections" {
  [ -f "$STRUCTURE" ]

  # Must contain "Nivel 1" section
  grep -q "Nivel 1" "$STRUCTURE"

  # Must contain Subcarpetas section
  grep -q "Subcarpetas\|## docs/core\|### \`docs/core" "$STRUCTURE"

  # Must mention official root files
  grep -q "ROADMAP.md" "$STRUCTURE"
  grep -q "RESOLVER.md" "$STRUCTURE"
  grep -q "ARCHITECTURE.md" "$STRUCTURE"
}

# Test 4: docs/INDEX.md exists and contains at least 10 top documents
@test "docs/INDEX.md exists with top 10 documents" {
  [ -f "$INDEX" ]

  # Must have a section for top documents
  grep -q "10\|top 10\|más importantes" "$INDEX"

  # Count markdown links — must have at least 10
  link_count=$(grep -c '\[.*\](.*\.md)' "$INDEX" || true)
  [ "$link_count" -ge 10 ]

  # Must mention key documents
  grep -q "CLAUDE.md" "$INDEX"
  grep -q "ROADMAP" "$INDEX"
  grep -q "RESOLVER" "$INDEX"
}

# Test 5: audit detects root-level docs as candidates (>10 expected given current state)
@test "audit detects >10 candidate docs in docs/ root for subcategory migration" {
  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ]

  # Extract candidates_for_subdir count from JSON
  candidate_count=$(echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['summary']['candidates_for_subdir'])
")
  # docs/ root has 109 files — all non-official ones are candidates
  [ "$candidate_count" -gt 10 ]
}
