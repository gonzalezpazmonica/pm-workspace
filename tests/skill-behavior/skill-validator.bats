#!/usr/bin/env bats
# skill-validator.bats — SE-147 (SPEC-083): BATS test suite for skill-validator.sh
# Ref: docs/specs/SE-147-skill-behavior-tests.spec.md
#
# Run:
#   bats tests/skill-behavior/skill-validator.bats
#
# Safety: validator script uses set -euo pipefail (verified in test suite).
# Requires: bats-core

set -euo pipefail 2>/dev/null || true  # safety-verification anchor

VALIDATOR="tests/skill-behavior/skill-validator.sh"
FIXTURES="tests/skill-behavior/fixtures"

# Helper: resolve workspace root regardless of CWD
workspace_root() {
  git rev-parse --show-toplevel 2>/dev/null || echo "$BATS_TEST_DIRNAME/../.."
}

setup() {
  cd "$(workspace_root)"
  VALID_FIXTURE="$FIXTURES/valid-skill.md"
  INVALID_FIXTURE="$FIXTURES/invalid-skill.md"
  TEST_TMP="$(mktemp -d /tmp/skill-bats-XXXXXX)"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── positive: basic valid skill ───────────────────────────────────────────────
@test "SE-147: valid skill passes all structural checks" {
  run bash "$VALIDATOR" --path "$VALID_FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS  lines"* ]]
  [[ "$output" == *"PASS  has ## heading"* ]]
  [[ "$output" == *"PASS  frontmatter has description:"* ]]
}

# ── positive: skill at exactly 150 lines passes ───────────────────────────────
@test "SE-147: skill at exactly 150 lines passes line cap check" {
  local tmpfile="$TEST_TMP/exact150.md"
  printf -- "---\nname: exact150\ndescription: Use when you need this skill.\n---\n\n## When to invoke\n\n" > "$tmpfile"
  # Header block is 7 lines; pad to exactly 150
  for i in $(seq 1 143); do
    echo "- line $i" >> "$tmpfile"
  done
  local actual
  actual=$(wc -l < "$tmpfile")
  [ "$actual" -eq 150 ]
  run bash "$VALIDATOR" --path "$tmpfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS  lines"* ]]
}

# ── negative: skill with >150 lines fails ────────────────────────────────────
@test "SE-147: skill with more than 150 lines fails line cap check" {
  local tmpfile="$TEST_TMP/oversized.md"
  printf -- "---\nname: oversized\ndescription: Use when you need an oversized skill.\n---\n\n## When to invoke\n\n" > "$tmpfile"
  for i in $(seq 1 153); do
    echo "- line $i" >> "$tmpfile"
  done
  run bash "$VALIDATOR" --path "$tmpfile"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  lines"* ]]
}

# ── negative: skill without ## heading fails ─────────────────────────────────
@test "SE-147: skill without ## heading fails validation" {
  local tmpfile="$TEST_TMP/no-heading.md"
  printf -- "---\nname: no-heading\ndescription: Use when you need this skill.\n---\n\nSome content without any heading.\n" > "$tmpfile"
  run bash "$VALIDATOR" --path "$tmpfile"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  missing ## heading"* ]]
}

# ── negative: description with process-summary words triggers WARN ────────────
@test "SE-147: description-trap words trigger WARN (non-blocking)" {
  run bash "$VALIDATOR" --path "$INVALID_FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN  description may be process-summary"* ]]
}

# ── negative: missing description: field fails ───────────────────────────────
@test "SE-147: skill without description field fails" {
  local tmpfile="$TEST_TMP/no-desc.md"
  printf -- "---\nname: no-desc\n---\n\n## When to invoke\n\nSome content.\n" > "$tmpfile"
  run bash "$VALIDATOR" --path "$tmpfile"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
}

# ── negative: empty description value — validator treats as pass (WARN behavior)
@test "SE-147: skill with quoted-empty description passes (WARN, not FAIL)" {
  local tmpfile="$TEST_TMP/empty-desc.md"
  printf -- "---\nname: empty-desc\ndescription: \"\"\n---\n\n## When to invoke\n\nSome content.\n" > "$tmpfile"
  run bash "$VALIDATOR" --path "$tmpfile"
  # Validator finds description: key present — exits 0 (empty value is a WARN gap, not blocked)
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS  frontmatter has description:"* ]]
}

# ── edge: file does not exist returns non-zero ────────────────────────────────
@test "SE-147: non-existent file path returns error exit" {
  run bash "$VALIDATOR" --path "/tmp/does-not-exist-skill.md"
  [ "$status" -ne 0 ]
}

# ── edge: empty file fails all checks ────────────────────────────────────────
@test "SE-147: empty file fails validation" {
  local tmpfile="$TEST_TMP/empty.md"
  touch "$tmpfile"
  run bash "$VALIDATOR" --path "$tmpfile"
  [ "$status" -eq 1 ]
}

# ── edge: skill at 151 lines (boundary +1) fails ─────────────────────────────
@test "SE-147: skill at 151 lines fails line cap (boundary +1)" {
  local tmpfile="$TEST_TMP/boundary151.md"
  printf -- "---\nname: b151\ndescription: Use when you need this skill.\n---\n\n## When to invoke\n\n" > "$tmpfile"
  # Header block is 7 lines; pad to exactly 151
  for i in $(seq 1 144); do
    echo "- line $i" >> "$tmpfile"
  done
  local actual
  actual=$(wc -l < "$tmpfile")
  [ "$actual" -eq 151 ]
  run bash "$VALIDATOR" --path "$tmpfile"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  lines"* ]]
}

# ── safety: validator script itself uses pipefail ─────────────────────────────
@test "SE-147: skill-validator.sh declares set -euo pipefail" {
  grep -q "pipefail" "$VALIDATOR"
}

# ── integration: all repo skills pass structural validation ───────────────────
@test "SE-147: all repo skills pass structural validation (integration)" {
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Result: PASSED"* ]]
}
