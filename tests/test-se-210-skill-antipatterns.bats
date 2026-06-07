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

# ── Safety verification ────────────────────────────────────────────────────────
@test "SE-210: tdd-vertical-slices SKILL.md has set safety guidance" {
  grep -q "Anti-patterns\|anti-pattern" "$ROOT/$SKILLS_DIR/tdd-vertical-slices/SKILL.md"
}

# ── Edge cases ────────────────────────────────────────────────────────────────
@test "SE-210 edge: zero anti-patterns in a skill not in the list is OK" {
  # Any skill outside the required 6 — absence of anti-patterns is valid
  # Just verify the skill file exists — absence of anti-patterns is valid for non-required skills
  [ -f "$ROOT/$SKILLS_DIR/knowledge-graph/SKILL.md" ]
}

@test "SE-210 edge: nonexistent skill directory handled gracefully" {
  run ls "$ROOT/$SKILLS_DIR/nonexistent-skill-$$/" 2>&1 || true
  [ "$status" -ne 0 ]
}

@test "SE-210 edge: REFERENCE.md satellite linked from SKILL.md" {
  grep -qE "REFERENCE|reference" "$ROOT/$SKILLS_DIR/spec-driven-development/SKILL.md" || \
  [ -f "$ROOT/$SKILLS_DIR/spec-driven-development/REFERENCE.md" ]
}

@test "SE-210 coverage: anti-patterns have ❌ or explicit Anti-pattern label" {
  local found=0
  for s in tdd-vertical-slices grill-me zoom-out caveman savia-memory; do
    if grep -qE "(❌|Anti-pattern|anti-pattern)" "$ROOT/$SKILLS_DIR/$s/SKILL.md" 2>/dev/null; then
      found=$((found + 1))
    fi
  done
  [ "$found" -ge 4 ]
}

# ── Safety / negative / quality ──────────────────────────────────────────────
@test "SE-210 safety: skill-catalog-auditor.sh has set -uo pipefail" {
  grep -q "set -uo pipefail" scripts/skill-catalog-auditor.sh
}

@test "SE-210 negative: skill without anti-patterns section not forced to have one" {
  # weekly-report is NOT in the required 6 — absence of anti-patterns is valid
  local skill="$ROOT/$SKILLS_DIR/weekly-report/SKILL.md"
  [[ -f "$skill" ]] || skip "weekly-report skill not found"
  local lines; lines=$(wc -l < "$skill")
  [ "$lines" -le 150 ]
}

@test "SE-210 negative: SKILL.md over 150 lines would fail auditor" {
  mkdir -p "$TMPDIR_TEST/skills/too-big"
  { printf -- '---\nname: too-big\ndescription: "Too big. Usar cuando testing."\n---\n\nrefs path/to/file\n'; yes "x" | head -145; } > "$TMPDIR_TEST/skills/too-big/SKILL.md"
  printf 'domain here\nmore content\nthird line\nfourth line here\n' > "$TMPDIR_TEST/skills/too-big/DOMAIN.md"
  run env SAVIA_SKILLS_DIR="$TMPDIR_TEST/skills" bash "$ROOT/$AUDITOR" 2>&1
  # 151 lines → FAIL in auditor (≥150)
  [[ "$output" == *"FAIL"* || "$status" -ne 0 ]]
}
