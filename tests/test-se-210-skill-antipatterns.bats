#!/usr/bin/env bats
# tests/test-se-210-skill-antipatterns.bats
# SE-210 — Explicit anti-patterns section in critical skills
# Ref: docs/propuestas/SE-210-skill-antipatterns.md

SKILLS_DIR=".claude/skills"

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── Inline skills have ## Anti-patterns ───────────────────────────────────────

@test "SE-210: tdd-vertical-slices/SKILL.md has ## Anti-patterns section" {
  grep -q "## Anti-patterns" "$ROOT/$SKILLS_DIR/tdd-vertical-slices/SKILL.md"
}

@test "SE-210: grill-me/SKILL.md has ## Anti-patterns section" {
  grep -q "## Anti-patterns" "$ROOT/$SKILLS_DIR/grill-me/SKILL.md"
}

@test "SE-210: zoom-out/SKILL.md has ## Anti-patterns section" {
  grep -q "## Anti-patterns" "$ROOT/$SKILLS_DIR/zoom-out/SKILL.md"
}

@test "SE-210: caveman/SKILL.md has ## Anti-patterns section" {
  grep -q "## Anti-patterns" "$ROOT/$SKILLS_DIR/caveman/SKILL.md"
}

@test "SE-210: savia-memory/SKILL.md has ## Anti-patterns section" {
  grep -q "## Anti-patterns" "$ROOT/$SKILLS_DIR/savia-memory/SKILL.md"
}

# ── No inline skill exceeds 150 lines ─────────────────────────────────────────

@test "SE-210: tdd-vertical-slices/SKILL.md does not exceed 150 lines" {
  local lines
  lines=$(wc -l < "$ROOT/$SKILLS_DIR/tdd-vertical-slices/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "SE-210: grill-me/SKILL.md does not exceed 150 lines" {
  local lines
  lines=$(wc -l < "$ROOT/$SKILLS_DIR/grill-me/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "SE-210: zoom-out/SKILL.md does not exceed 150 lines" {
  local lines
  lines=$(wc -l < "$ROOT/$SKILLS_DIR/zoom-out/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "SE-210: caveman/SKILL.md does not exceed 150 lines" {
  local lines
  lines=$(wc -l < "$ROOT/$SKILLS_DIR/caveman/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "SE-210: savia-memory/SKILL.md does not exceed 150 lines" {
  local lines
  lines=$(wc -l < "$ROOT/$SKILLS_DIR/savia-memory/SKILL.md")
  [ "$lines" -le 150 ]
}

# ── spec-driven-development has anti-patterns (SKILL.md or REFERENCE.md) ─────

@test "SE-210: spec-driven-development has anti-patterns in SKILL.md or REFERENCE.md" {
  grep -ql "## Anti-patterns\|Anti-pattern\|anti-pattern" \
    "$ROOT/$SKILLS_DIR/spec-driven-development/SKILL.md" \
    "$ROOT/$SKILLS_DIR/spec-driven-development/REFERENCE.md" 2>/dev/null
}

@test "SE-210: spec-driven-development/REFERENCE.md exists" {
  [ -f "$ROOT/$SKILLS_DIR/spec-driven-development/REFERENCE.md" ]
}

@test "SE-210: spec-driven-development/REFERENCE.md has ## Anti-patterns" {
  grep -q "## Anti-patterns" "$ROOT/$SKILLS_DIR/spec-driven-development/REFERENCE.md"
}

# ── Each anti-pattern uses marker ❌ or Anti-pattern keyword ─────────────────

@test "SE-210: tdd-vertical-slices anti-patterns use ❌ marker" {
  grep -q "❌" "$ROOT/$SKILLS_DIR/tdd-vertical-slices/SKILL.md"
}

@test "SE-210: grill-me anti-patterns use ❌ marker" {
  grep -q "❌" "$ROOT/$SKILLS_DIR/grill-me/SKILL.md"
}

@test "SE-210: caveman anti-patterns use ❌ marker" {
  grep -q "❌" "$ROOT/$SKILLS_DIR/caveman/SKILL.md"
}

@test "SE-210: savia-memory anti-patterns use ❌ marker" {
  grep -q "❌" "$ROOT/$SKILLS_DIR/savia-memory/SKILL.md"
}

@test "SE-210: REFERENCE.md anti-patterns use ❌ marker" {
  grep -q "❌" "$ROOT/$SKILLS_DIR/spec-driven-development/REFERENCE.md"
}

# ── spec-driven-development SKILL.md links to REFERENCE.md ───────────────────

@test "SE-210: spec-driven-development/SKILL.md links to REFERENCE.md" {
  grep -q "REFERENCE.md" "$ROOT/$SKILLS_DIR/spec-driven-development/SKILL.md"
}
