#!/usr/bin/env bats
# skill-validator.bats — SE-147: BATS test suite for skill-validator.sh
#
# Run:
#   bats tests/skill-behavior/skill-validator.bats
#
# Requires: bats-core (available at /home/monica/.local/bin/bats)

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
}

# ── Test 1: valid skill passes all checks ─────────────────────────────────────
@test "valid skill passes validation" {
  run bash "$VALIDATOR" --path "$VALID_FIXTURE"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "PASS  lines"
  echo "$output" | grep -q "PASS  has ## heading"
  echo "$output" | grep -q "PASS  frontmatter has description:"
}

# ── Test 2: skill with >150 lines fails ───────────────────────────────────────
@test "skill with more than 150 lines fails" {
  local tmpfile
  tmpfile="$(mktemp /tmp/skill-XXXXXX.md)"

  # Write frontmatter + heading
  printf -- "---\nname: oversized\ndescription: Use when you need an oversized skill.\n---\n\n## When to invoke\n\n" > "$tmpfile"

  # Pad to 160 lines total
  for i in $(seq 1 153); do
    echo "- line $i" >> "$tmpfile"
  done

  run bash "$VALIDATOR" --path "$tmpfile"
  rm -f "$tmpfile"

  [ "$status" -eq 1 ]
  echo "$output" | grep -q "FAIL  lines"
}

# ── Test 3: skill without ## heading fails ────────────────────────────────────
@test "skill without heading fails validation" {
  local tmpfile
  tmpfile="$(mktemp /tmp/skill-XXXXXX.md)"

  printf -- "---\nname: no-heading\ndescription: Use when you need this skill.\n---\n\nSome content without any heading.\n" > "$tmpfile"

  run bash "$VALIDATOR" --path "$tmpfile"
  rm -f "$tmpfile"

  [ "$status" -eq 1 ]
  echo "$output" | grep -q "FAIL  missing ## heading"
}

# ── Test 4: description with process-summary words triggers WARN ──────────────
@test "skill with process-summary description triggers WARN" {
  run bash "$VALIDATOR" --path "$INVALID_FIXTURE"
  # Description-trap is a WARN (non-blocking) so exit 0
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "WARN  description may be process-summary"
}

# ── Test 5: integration — all repo skills pass structural validation ───────────
@test "all repo skills pass structural validation" {
  run bash "$VALIDATOR"
  # Validator exits 0 only if no hard FAILs (WARNs are non-blocking)
  [ "$status" -eq 0 ]

  # Summary line must show FAILED count of 0
  echo "$output" | grep -q "Result: PASSED"
}
