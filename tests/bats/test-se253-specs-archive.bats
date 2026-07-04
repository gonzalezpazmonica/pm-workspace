#!/usr/bin/env bats
# tests/bats/test-se253-specs-archive.bats
# SE-253 Slice 6 -- Specs archive structure + changelog spec-field check
# ACs: 6.1 (archive dir), 6.2 (script), 6.3 (README gap doc), 6.4 (backfill >= 5), 6.5 (procedure section)

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ARCHIVE_DIR="$REPO_ROOT/docs/specs-archive"
ARCHIVE_2026="$REPO_ROOT/docs/specs-archive/2026"
README="$REPO_ROOT/docs/specs-archive/README.md"
SCRIPT="$REPO_ROOT/scripts/changelog-spec-field-check.sh"

# -- AC-6.1: docs/specs-archive/2026/ exists with at least 1 file ----------------
@test "SE-253 AC-6.1: docs/specs-archive/2026/ exists" {
  [[ -d "$ARCHIVE_2026" ]]
}

@test "SE-253 AC-6.1: docs/specs-archive/2026/ has at least 1 archived spec" {
  count=$(find "$ARCHIVE_2026" -maxdepth 1 -name "SE-*.md" | wc -l)
  [[ "$count" -ge 1 ]]
}

# -- AC-6.2: changelog-spec-field-check.sh exists and is executable ---------------
@test "SE-253 AC-6.2: changelog-spec-field-check.sh exists" {
  [[ -f "$SCRIPT" ]]
}

@test "SE-253 AC-6.2: changelog-spec-field-check.sh is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "SE-253 AC-6.2: changelog-spec-field-check.sh exits 0 in --warn mode" {
  run bash "$SCRIPT" --warn
  [ "$status" -eq 0 ]
}

@test "SE-253 AC-6.2: changelog-spec-field-check.sh exits 2 with unknown mode" {
  run bash "$SCRIPT" --invalid-mode
  [ "$status" -eq 2 ]
}

# -- AC-6.3: README documents gap (contains "SE-143" and "SE-252") ----------------
@test "SE-253 AC-6.3: specs-archive/README.md exists" {
  [[ -f "$README" ]]
}

@test "SE-253 AC-6.3: README.md mentions SE-143 (gap start)" {
  grep -q "SE-143" "$README"
}

@test "SE-253 AC-6.3: README.md mentions SE-252 (gap end)" {
  grep -q "SE-252" "$README"
}

# -- AC-6.4: At least 5 specs from last 30 days are in the archive ---------------
@test "SE-253 AC-6.4: at least 5 specs archived in 2026/" {
  count=$(find "$ARCHIVE_2026" -maxdepth 1 -name "SE-*.md" | wc -l)
  [[ "$count" -ge 5 ]]
}

@test "SE-253 AC-6.4: archived specs have closed_date frontmatter" {
  found=0
  while IFS= read -r -d '' f; do
    if grep -q "closed_date:" "$f" 2>/dev/null; then
      found=$((found + 1))
    fi
  done < <(find "$ARCHIVE_2026" -maxdepth 1 -name "SE-*.md" -print0)
  [[ "$found" -ge 5 ]]
}

@test "SE-253 AC-6.4: archived specs have closed_by_pr frontmatter" {
  found=0
  while IFS= read -r -d '' f; do
    if grep -q "closed_by_pr:" "$f" 2>/dev/null; then
      found=$((found + 1))
    fi
  done < <(find "$ARCHIVE_2026" -maxdepth 1 -name "SE-*.md" -print0)
  [[ "$found" -ge 5 ]]
}

# -- Extra AC-6.5: README has Procedimiento section -------------------------------
@test "SE-253 AC-6.5: README.md has Procedimiento section" {
  grep -qi "Procedimiento" "$README"
}

@test "SE-253 AC-6.5: README.md documents mv step in Procedimiento" {
  grep -q "mv docs/propuestas" "$README"
}
