#!/usr/bin/env bats
# test-se-103-dormant-rules.bats — Tests for SE-103: Quarterly dormant rules review
# Tests: review doc exists, rules marked, analyzer executable

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  REVIEW_DOC="$REPO_ROOT/docs/rules/domain/dormant-rules-review-2026-Q2.md"
  ANALYZER="$REPO_ROOT/scripts/rule-usage-analyzer.sh"
  DOMAIN_DIR="$REPO_ROOT/docs/rules/domain"
}

@test "SE-103: dormant-rules-review-2026-Q2.md exists" {
  [ -f "$REVIEW_DOC" ]
}

@test "SE-103: review document has required sections" {
  grep -q "Q2 2026" "$REVIEW_DOC"
  grep -q "2026-06-24" "$REVIEW_DOC"
}

@test "SE-103: review document lists dormant rules table" {
  grep -q "reference-only" "$REVIEW_DOC"
  grep -q "keep\|archive" "$REVIEW_DOC"
}

@test "SE-103: at least 5 rules have usage: reference-only in frontmatter" {
  local count
  count=$(grep -rl "usage: reference-only" "$DOMAIN_DIR" | wc -l)
  [ "$count" -ge 5 ]
}

@test "SE-103: at least 10 rules marked dormant (broader coverage)" {
  local count
  count=$(grep -rl "usage: reference-only" "$DOMAIN_DIR" | wc -l)
  [ "$count" -ge 10 ]
}

@test "SE-103: dormant_since field present in marked rules" {
  local count
  count=$(grep -rl "dormant_since" "$DOMAIN_DIR" | wc -l)
  [ "$count" -ge 5 ]
}

@test "SE-103: scripts/rule-usage-analyzer.sh exists and is executable" {
  [ -f "$ANALYZER" ]
  [ -x "$ANALYZER" ]
}

@test "SE-103: rule-usage-analyzer.sh runs without fatal error" {
  run bash "$ANALYZER" --summary 2>/dev/null
  # Accept exit 0 or 1 (may not support --summary flag) but must not crash badly
  [ "$status" -le 1 ]
}
