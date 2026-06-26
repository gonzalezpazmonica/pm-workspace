#!/usr/bin/env bats
# tests/test-court-turn-router.bats — SE-231 Adaptive Turn Routing
# Ref: docs/rules/domain/court-turn-routing.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/court-turn-router.sh"
  TMPDIR_CTR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_CTR"
}

# ── Helpers ───────────────────────────────────────────────────────────────────
make_findings() {
  local file="$TMPDIR_CTR/findings.json"
  echo "$1" > "$file"
  echo "$file"
}

# Returns the sorted list of judges from a multi-line output
sorted_judges() { echo "$1" | sort; }

ALL_JUDGES_SORTED="architecture-judge
cognitive-judge
correctness-judge
security-judge
spec-judge"

# ── Basic usage / errors ──────────────────────────────────────────────────────
@test "no arguments → exit 2 (usage error)" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "missing --findings value → exit 2 (usage error)" {
  run bash "$SCRIPT" --findings
  [ "$status" -eq 2 ]
}

@test "non-existent findings file → exit 1" {
  run bash "$SCRIPT" --findings /tmp/does-not-exist-se231.json
  [ "$status" -eq 1 ]
}

@test "empty findings file → exit 1" {
  local f="$TMPDIR_CTR/empty.json"
  touch "$f"
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 1 ]
}

# ── Output format ─────────────────────────────────────────────────────────────
@test "output is one judge per line (no blank lines)" {
  local f; f=$(make_findings '{"findings": [{"type": "security", "detail": "sql injection found"}]}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  # No blank lines
  [[ -z "$(echo "$output" | grep -E '^$')" ]]
  # Each line is a valid judge name (non-empty)
  while IFS= read -r line; do
    [[ -n "$line" ]]
  done <<< "$output"
}

# ── Security findings ─────────────────────────────────────────────────────────
@test "security keyword 'injection' → security-judge + correctness-judge only" {
  local f; f=$(make_findings '{"findings": [{"detail": "sql injection vulnerability detected"}]}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  local got; got=$(sorted_judges "$output")
  local expected
  expected=$(printf '%s\n' "correctness-judge" "security-judge" | sort)
  [ "$got" = "$expected" ]
}

@test "security keyword 'owasp' → security-judge + correctness-judge" {
  local f; f=$(make_findings '{"detail": "owasp A03 risk: credential exposure"}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "security-judge"
  echo "$output" | grep -q "correctness-judge"
  # Exactly 2 lines
  [ "$(echo "$output" | wc -l)" -eq 2 ]
}

@test "security findings → does NOT include architecture-judge" {
  local f; f=$(make_findings '{"detail": "xss attack vector in form input"}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q "architecture-judge"
}

# ── Architecture findings ─────────────────────────────────────────────────────
@test "architecture keyword 'coupling' → architecture-judge + spec-judge only" {
  local f; f=$(make_findings '{"findings": [{"detail": "tight coupling between domain and infrastructure layer"}]}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  local got; got=$(sorted_judges "$output")
  local expected
  expected=$(printf '%s\n' "architecture-judge" "spec-judge" | sort)
  [ "$got" = "$expected" ]
}

@test "architecture keyword 'boundary' → architecture-judge + spec-judge" {
  local f; f=$(make_findings '{"detail": "layer boundary violation: UI calling repository directly"}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "architecture-judge"
  echo "$output" | grep -q "spec-judge"
  [ "$(echo "$output" | wc -l)" -eq 2 ]
}

# ── Logic / edge case findings ────────────────────────────────────────────────
@test "logic keyword 'edge case' → correctness-judge + cognitive-judge only" {
  local f; f=$(make_findings '{"detail": "missing edge case for null pointer dereference"}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  local got; got=$(sorted_judges "$output")
  local expected
  expected=$(printf '%s\n' "cognitive-judge" "correctness-judge" | sort)
  [ "$got" = "$expected" ]
}

@test "logic keyword 'error path' → correctness-judge + cognitive-judge" {
  local f; f=$(make_findings '{"detail": "error path not handled when token expires"}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "correctness-judge"
  echo "$output" | grep -q "cognitive-judge"
  [ "$(echo "$output" | wc -l)" -eq 2 ]
}

# ── Spec mismatch findings ────────────────────────────────────────────────────
@test "spec keyword → spec-judge + correctness-judge only" {
  local f; f=$(make_findings '{"detail": "acceptance criteria AC-03 not implemented"}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  local got; got=$(sorted_judges "$output")
  local expected
  expected=$(printf '%s\n' "correctness-judge" "spec-judge" | sort)
  [ "$got" = "$expected" ]
}

# ── Naming / complexity findings ──────────────────────────────────────────────
@test "naming keyword → cognitive-judge only" {
  local f; f=$(make_findings '{"detail": "poor naming: variable x has no semantic meaning"}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "cognitive-judge"
  [ "$(echo "$output" | wc -l)" -eq 1 ]
}

@test "complexity keyword → cognitive-judge only" {
  local f; f=$(make_findings '{"detail": "high cognitive complexity in parseConfig, score 24"}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "cognitive-judge"
  [ "$(echo "$output" | wc -l)" -eq 1 ]
}

# ── Mixed findings ────────────────────────────────────────────────────────────
@test "mixed findings (security + architecture) → all 5 judges" {
  local f; f=$(make_findings '{"detail": "sql injection AND layer boundary violation found"}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  local got; got=$(sorted_judges "$output")
  [ "$got" = "$ALL_JUDGES_SORTED" ]
}

@test "mixed findings (spec + logic) → all 5 judges" {
  local f; f=$(make_findings '{"detail": "acceptance criteria missing and null exception unhandled"}')
  run bash "$SCRIPT" --findings "$f"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | sort | wc -l)" -eq 5 ]
}

# ── Last-round override ───────────────────────────────────────────────────────
@test "round >= max_round-1 forces all 5 judges (security-only findings)" {
  local f; f=$(make_findings '{"detail": "xss in login form"}')
  run bash "$SCRIPT" --findings "$f" --round 2 --max-round 3
  [ "$status" -eq 0 ]
  local got; got=$(sorted_judges "$output")
  [ "$got" = "$ALL_JUDGES_SORTED" ]
}

@test "round equals max_round forces all 5 judges" {
  local f; f=$(make_findings '{"detail": "naming issue only"}')
  run bash "$SCRIPT" --findings "$f" --round 3 --max-round 3
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | sort | wc -l)" -eq 5 ]
}

@test "round 1 of 3 with simple finding → reduced judge set" {
  local f; f=$(make_findings '{"detail": "sql injection found in login handler"}')
  run bash "$SCRIPT" --findings "$f" --round 1 --max-round 3
  [ "$status" -eq 0 ]
  # Should NOT be 5 judges — round 1 < max_round-1 (2)
  [ "$(echo "$output" | wc -l)" -lt 5 ]
}

@test "no keyword match → all 5 judges (conservative fallback)" {
  local f; f=$(make_findings '{"detail": "general code style issue with whitespace"}')
  run bash "$SCRIPT" --findings "$f" --round 1 --max-round 5
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | sort | wc -l)" -eq 5 ]
}

# ── Exact judge set (not more, not less) ──────────────────────────────────────
@test "security routing returns exactly 2 judges, no duplicates" {
  local f; f=$(make_findings '{"detail": "pii exposure in log output"}')
  run bash "$SCRIPT" --findings "$f" --round 1 --max-round 4
  [ "$status" -eq 0 ]
  local count; count=$(echo "$output" | sort -u | wc -l)
  [ "$count" -eq 2 ]
}

@test "architecture routing returns exactly 2 judges, no duplicates" {
  local f; f=$(make_findings '{"detail": "solid violation: high coupling between modules"}')
  run bash "$SCRIPT" --findings "$f" --round 1 --max-round 4
  [ "$status" -eq 0 ]
  local count; count=$(echo "$output" | sort -u | wc -l)
  [ "$count" -eq 2 ]
}
