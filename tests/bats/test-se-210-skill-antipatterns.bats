#!/usr/bin/env bats
# test-se-210-skill-antipatterns.bats — Tests for SE-210: Explicit anti-patterns in critical skills

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SKILLS_DIR="$REPO_ROOT/.opencode/skills"
  CANONICAL="$REPO_ROOT/docs/rules/domain/skill-antipatterns.md"
}

@test "SE-210: tdd-vertical-slices/SKILL.md contains Anti-patterns section" {
  grep -q "## Anti-patterns" "$SKILLS_DIR/tdd-vertical-slices/SKILL.md"
}

@test "SE-210: tdd-vertical-slices has at least 2 anti-patterns documented" {
  local count
  count=$(grep -c "^\\*\\*.*❌" "$SKILLS_DIR/tdd-vertical-slices/SKILL.md" || true)
  [ "$count" -ge 2 ]
}

@test "SE-210: tdd-vertical-slices has horizontal-slicing anti-pattern" {
  grep -qi "horizontal" "$SKILLS_DIR/tdd-vertical-slices/SKILL.md"
}

@test "SE-210: tdd-vertical-slices has over-mocking anti-pattern" {
  grep -qi "mocking\|mock" "$SKILLS_DIR/tdd-vertical-slices/SKILL.md"
}

@test "SE-210: tdd-vertical-slices has test-after anti-pattern" {
  grep -qi "test-after\|Test-after" "$SKILLS_DIR/tdd-vertical-slices/SKILL.md"
}

@test "SE-210: grill-me/SKILL.md contains Anti-patterns section" {
  grep -q "## Anti-patterns" "$SKILLS_DIR/grill-me/SKILL.md"
}

@test "SE-210: grill-me has at least 2 anti-patterns documented" {
  local count
  count=$(grep -c "^\\*\\*.*❌" "$SKILLS_DIR/grill-me/SKILL.md" || true)
  [ "$count" -ge 2 ]
}

@test "SE-210: grill-me has praise-sandwich anti-pattern" {
  grep -qi "praise-sandwich\|Praise-sandwich" "$SKILLS_DIR/grill-me/SKILL.md"
}

@test "SE-210: grill-me has rubber-stamp anti-pattern" {
  grep -qi "rubber-stamp\|Rubber-stamp" "$SKILLS_DIR/grill-me/SKILL.md"
}

@test "SE-210: savia-memory/SKILL.md contains Anti-patterns section" {
  grep -q "## Anti-patterns" "$SKILLS_DIR/savia-memory/SKILL.md"
}

@test "SE-210: savia-memory has at least 3 anti-patterns" {
  local count
  count=$(grep -c "^\\*\\*.*❌" "$SKILLS_DIR/savia-memory/SKILL.md" || true)
  [ "$count" -ge 3 ]
}

@test "SE-210: savia-memory has bulk-dump anti-pattern" {
  grep -qi "bulk-dump\|Bulk-dump" "$SKILLS_DIR/savia-memory/SKILL.md"
}

@test "SE-210: savia-memory has stale-reads anti-pattern" {
  grep -qi "stale-reads\|Stale-reads" "$SKILLS_DIR/savia-memory/SKILL.md"
}

@test "SE-210: spec-driven-development contains Anti-patterns reference" {
  # SKILL.md points to REFERENCE.md, or has direct anti-patterns section
  grep -q "Anti-patterns" "$SKILLS_DIR/spec-driven-development/SKILL.md"
}

@test "SE-210: spec-driven-development REFERENCE.md has spec-after anti-pattern" {
  grep -qi "spec-after\|Spec-after" "$SKILLS_DIR/spec-driven-development/REFERENCE.md"
}

@test "SE-210: spec-driven-development REFERENCE.md has orphan-spec anti-pattern" {
  grep -qi "orphan-spec\|Orphan-spec" "$SKILLS_DIR/spec-driven-development/REFERENCE.md"
}

@test "SE-210: docs/rules/domain/skill-antipatterns.md exists" {
  [ -f "$CANONICAL" ]
}

@test "SE-210: skill-antipatterns.md references all 4 critical skills" {
  grep -q "tdd-vertical-slices" "$CANONICAL"
  grep -q "grill-me" "$CANONICAL"
  grep -q "savia-memory" "$CANONICAL"
  grep -q "spec-driven-development" "$CANONICAL"
}

@test "SE-210: skill-antipatterns.md has at least 2 anti-patterns per skill section" {
  # Check tdd section has at least 2 table rows with anti-patterns
  local tdd_count
  tdd_count=$(awk '/## tdd-vertical-slices/,/^---/' "$CANONICAL" | grep -c "^| \*\*" || true)
  [ "$tdd_count" -ge 2 ]
}

@test "SE-210: grill-me SKILL.md does not exceed 150 lines" {
  local lines
  lines=$(wc -l < "$SKILLS_DIR/grill-me/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "SE-210: tdd-vertical-slices SKILL.md does not exceed 150 lines" {
  local lines
  lines=$(wc -l < "$SKILLS_DIR/tdd-vertical-slices/SKILL.md")
  [ "$lines" -le 150 ]
}
