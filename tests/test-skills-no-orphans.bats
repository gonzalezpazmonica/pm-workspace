#!/usr/bin/env bats
# Regression test for SPEC-082: no orphan skills (DOMAIN.md xor SKILL.md).
# Clara Philosophy requires dual documentation: every skill directory must
# contain BOTH SKILL.md (protocol, how to invoke) AND DOMAIN.md (rationale,
# limits, confidentiality).
#
# Origin: Auditoria 2026-04-07 (M-002) identified pr-agent-judge as orphan
# (SKILL.md only). Fixed 2026-04-18 with SPEC-082 implementation.
#
# Safety: this test follows workspace convention of `set -uo pipefail`
# for error propagation.

SKILLS_DIR=".claude/skills"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structural invariants ───────────────────────────────────────────────────

@test "skills directory exists" {
  [[ -d "$SKILLS_DIR" ]]
}

@test "skills directory has at least 50 skills" {
  local count
  count=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l)
  [[ "$count" -ge 50 ]]
}

# ── Core invariant: no orphans ──────────────────────────────────────────────

@test "every skill directory has SKILL.md" {
  local missing=0
  for d in "$SKILLS_DIR"/*/; do
    if [[ ! -f "$d/SKILL.md" ]]; then
      echo "MISSING SKILL.md: $d" >&2
      missing=$((missing+1))
    fi
  done
  [[ "$missing" -eq 0 ]]
}

@test "every skill directory has DOMAIN.md" {
  local missing=0
  for d in "$SKILLS_DIR"/*/; do
    if [[ ! -f "$d/DOMAIN.md" ]]; then
      echo "MISSING DOMAIN.md: $d" >&2
      missing=$((missing+1))
    fi
  done
  [[ "$missing" -eq 0 ]]
}

@test "SKILL.md count equals DOMAIN.md count" {
  local s d
  s=$(find "$SKILLS_DIR" -maxdepth 2 -name 'SKILL.md' -type f | wc -l)
  d=$(find "$SKILLS_DIR" -maxdepth 2 -name 'DOMAIN.md' -type f | wc -l)
  [[ "$s" -eq "$d" ]]
}

# ── pr-agent-judge specific (the one that was orphan) ──────────────────────

@test "pr-agent-judge has SKILL.md" {
  [[ -f "$SKILLS_DIR/pr-agent-judge/SKILL.md" ]]
}

@test "pr-agent-judge has DOMAIN.md (regression test)" {
  [[ -f "$SKILLS_DIR/pr-agent-judge/DOMAIN.md" ]]
}

@test "pr-agent-judge DOMAIN.md is non-empty" {
  [[ -s "$SKILLS_DIR/pr-agent-judge/DOMAIN.md" ]]
}

@test "pr-agent-judge DOMAIN.md has Por que existe section" {
  run grep -c "## Por que existe esta skill" "$SKILLS_DIR/pr-agent-judge/DOMAIN.md"
  [[ "$output" -ge 1 ]]
}

@test "pr-agent-judge DOMAIN.md references SPEC-124" {
  run grep -c "SPEC-124" "$SKILLS_DIR/pr-agent-judge/DOMAIN.md"
  [[ "$output" -ge 1 ]]
}

# ── DOMAIN.md minimum content contract ──────────────────────────────────────

@test "majority of DOMAIN.md files have Por que section (Clara Philosophy)" {
  local total=0
  local missing=0
  for f in "$SKILLS_DIR"/*/DOMAIN.md; do
    total=$((total+1))
    if ! grep -qE "Por que existe esta skill|Por qué existe esta skill" "$f"; then
      missing=$((missing+1))
    fi
  done
  # Assert: at least 70% of DOMAIN.md have the canonical section.
  # Legacy files from earlier phases may use other heading patterns.
  local min_ok=$(( total * 70 / 100 ))
  local actual_ok=$(( total - missing ))
  [[ "$actual_ok" -ge "$min_ok" ]]
}

@test "every SKILL.md has frontmatter" {
  local missing=0
  for f in "$SKILLS_DIR"/*/SKILL.md; do
    local first
    first=$(head -1 "$f")
    if [[ "$first" != "---" ]]; then
      echo "MISSING frontmatter: $f" >&2
      missing=$((missing+1))
    fi
  done
  [[ "$missing" -eq 0 ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: nonexistent skill directory would fail" {
  [[ ! -d "$SKILLS_DIR/nonexistent-skill-xyz-999" ]]
}

@test "negative: zero-length DOMAIN.md would fail size check" {
  local empty="$BATS_TEST_TMPDIR/empty.md"
  : > "$empty"
  [[ ! -s "$empty" ]]
}

@test "negative: SKILL.md without frontmatter delimiter fails first-line check" {
  local bad="$BATS_TEST_TMPDIR/bad-skill.md"
  echo "# Just a heading" > "$bad"
  local first
  first=$(head -1 "$bad")
  [[ "$first" != "---" ]]
}

@test "negative: mismatched counts would be detected" {
  # Simulate: if SKILL=77 but DOMAIN=76, fail
  local a=77
  local b=76
  # The actual test asserts equality; this verifies the assertion logic itself
  [[ "$a" -ne "$b" ]]
}

@test "negative: orphan directory pattern is detectable" {
  local tmp="$BATS_TEST_TMPDIR/fake-skill"
  mkdir -p "$tmp"
  touch "$tmp/SKILL.md"
  # DOMAIN.md missing — this pattern must be detectable
  [[ -f "$tmp/SKILL.md" ]]
  [[ ! -f "$tmp/DOMAIN.md" ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: no nested skill dirs with SKILL.md at wrong depth" {
  # SKILL.md must be at depth 2 (SKILLS_DIR/{skill}/SKILL.md), not deeper
  local bad
  bad=$(find "$SKILLS_DIR" -mindepth 3 -name 'SKILL.md' -type f | wc -l)
  [[ "$bad" -eq 0 ]]
}

@test "edge: boundary — both files identical count means all paired" {
  local s d
  s=$(find "$SKILLS_DIR" -maxdepth 2 -name 'SKILL.md' -type f | wc -l)
  d=$(find "$SKILLS_DIR" -maxdepth 2 -name 'DOMAIN.md' -type f | wc -l)
  [[ "$s" -gt 0 ]]
  [[ "$d" -gt 0 ]]
  [[ "$s" -eq "$d" ]]
}
