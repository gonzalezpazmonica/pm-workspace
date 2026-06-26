#!/usr/bin/env bats
# test-se-096-orphan-rules-archive.bats — SE-096: Archive 9 orphan rules
# Verifies that the 9 rules listed in SE-096 are marked archived and excluded
# from the orphan detector.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
RULES_DIR="$REPO_ROOT/docs/rules/domain"
ARCHIVE_DIR="$REPO_ROOT/docs/archive/rules"

# All 9 rules that SE-096 archives
SE096_ORPHANS=(
  "hook-event-equivalence.md"
  "image-relevance-filter.md"
  "portfolio-as-graph.en.md"
  "receipts-protocol.en.md"
  "savia-memory-architecture.md"
  "session-state-location.md"
  "slm-consolidation-pattern.md"
  "slm-training-pipeline.en.md"
  "vault-frontmatter.md"
)

@test "SE-096: all 9 orphan rules have archived:true in frontmatter" {
  for fname in "${SE096_ORPHANS[@]}"; do
    rule="$RULES_DIR/$fname"
    [ -f "$rule" ] || fail "Rule file missing: $rule"
    grep -qE '^archived: true' "$rule" || fail "Missing 'archived: true' in: $fname"
  done
}

@test "SE-096: all 9 orphan rules are copied to docs/archive/rules/" {
  [ -d "$ARCHIVE_DIR" ] || fail "Archive directory missing: $ARCHIVE_DIR"
  for fname in "${SE096_ORPHANS[@]}"; do
    # At least one archive copy matching the filename must exist
    count=$(ls "$ARCHIVE_DIR" 2>/dev/null | grep "$fname" | wc -l)
    [ "$count" -ge 1 ] || fail "No archive copy found for: $fname"
  done
}

@test "SE-096: rule-orphan-detector.sh excludes archived rules from orphan list" {
  run bash "$REPO_ROOT/scripts/rule-orphan-detector.sh" 2>/dev/null
  # Each of the 9 archived rules must NOT appear in detector output
  for fname in "${SE096_ORPHANS[@]}"; do
    echo "$output" | grep -qF "$fname" && fail "Archived rule still listed as orphan: $fname"
  done
  # Script should not report these 9 in its orphan list
  :
}
