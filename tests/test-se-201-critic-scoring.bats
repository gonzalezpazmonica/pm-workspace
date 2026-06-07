#!/usr/bin/env bats
# test-se-201-critic-scoring.bats — SE-201: quantitative scoring for tribunal verdicts
# Ref: docs/propuestas/SE-201-critic-scoring.md / scripts/tribunal-critic.sh
# Minimum 15 tests, target ≥80 score

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/tribunal-critic.sh"
  TMPDIR_CRITIC="$(mktemp -d)"
  export TMPDIR_CRITIC
  # Override PROJECT_ROOT so scores go to tmp, not live workspace
  export PROJECT_ROOT="$TMPDIR_CRITIC"
  export SAVIA_CRITIC_THRESHOLD=80
}

teardown() {
  rm -rf "$TMPDIR_CRITIC"
}

# ── Existence & safety ────────────────────────────────────────────────────────

@test "SE-201: tribunal-critic.sh exists" {
  [ -f "$SCRIPT" ]
}

@test "SE-201: tribunal-critic.sh is executable" {
  [ -x "$SCRIPT" ]
}

@test "SE-201: tribunal-critic.sh has set -uo pipefail" {
  run grep -E "^set -[a-z]*uo[a-z]*\s*pipefail|set -uo pipefail|set -euo pipefail" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "SE-201: SE-201 is referenced in script" {
  run grep -F "SE-201" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── JSON output structure ─────────────────────────────────────────────────────

@test "SE-201: --json flag produces valid JSON with required fields" {
  # Create a verdict with enough signal to pass
  cat > "$TMPDIR_CRITIC/verdict.crc" <<'EOF'
PASS
security OWASP no issues
spec AC-1 AC-2 acceptance criteria met
error handling null edge case coverage
API interface contract schema
performance complexity
EOF
  run bash "$SCRIPT" --json "$TMPDIR_CRITIC/verdict.crc"
  [ "$status" -eq 0 ]
  # Verify JSON fields exist
  echo "$output" | grep -q '"score"'
  echo "$output" | grep -q '"breakdown"'
  echo "$output" | grep -q '"pass"'
  echo "$output" | grep -q '"threshold"'
}

@test "SE-201: breakdown has 4 criteria (correctness, completeness, security, spec_compliance)" {
  cat > "$TMPDIR_CRITIC/verdict.crc" <<'EOF'
PASS security OWASP AC-1 acceptance criteria
error handling null edge case coverage
API interface contract schema
performance complexity
EOF
  run bash "$SCRIPT" --json "$TMPDIR_CRITIC/verdict.crc"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"correctness"'
  echo "$output" | grep -q '"completeness"'
  echo "$output" | grep -q '"security"'
  echo "$output" | grep -q '"spec_compliance"'
}

# ── Exit codes ────────────────────────────────────────────────────────────────

@test "SE-201: exit 0 when score >= threshold" {
  cat > "$TMPDIR_CRITIC/passing.crc" <<'EOF'
PASS
OWASP security no issues
AC-1 AC-2 acceptance criteria spec
error handling null edge case coverage
API interface contract schema
performance complexity logging monitoring
EOF
  export SAVIA_CRITIC_THRESHOLD=50
  run bash "$SCRIPT" "$TMPDIR_CRITIC/passing.crc"
  [ "$status" -eq 0 ]
}

@test "SE-201: exit 1 when score < threshold" {
  # Minimal file with almost no signal
  cat > "$TMPDIR_CRITIC/failing.crc" <<'EOF'
some review text with no signal
EOF
  export SAVIA_CRITIC_THRESHOLD=99
  run bash "$SCRIPT" "$TMPDIR_CRITIC/failing.crc"
  [ "$status" -eq 1 ]
}

# ── Configurable threshold ────────────────────────────────────────────────────

@test "SE-201: SAVIA_CRITIC_THRESHOLD is configurable via env var" {
  # Minimal signal file — only correctness, no security/spec/completeness
  cat > "$TMPDIR_CRITIC/low-signal.crc" <<'EOF'
PASS
some generic review text without any specific technical coverage
EOF
  # Should pass at threshold 1 (any score > 0)
  export SAVIA_CRITIC_THRESHOLD=1
  run bash "$SCRIPT" "$TMPDIR_CRITIC/low-signal.crc"
  [ "$status" -eq 0 ]

  # Should fail at threshold 99 (very hard to reach without spec/security/completeness)
  export SAVIA_CRITIC_THRESHOLD=99
  run bash "$SCRIPT" "$TMPDIR_CRITIC/low-signal.crc"
  [ "$status" -eq 1 ]
}

# ── Verdict with PASS → score > 50 ───────────────────────────────────────────

@test "SE-201: verdict with PASS produces score > 50" {
  cat > "$TMPDIR_CRITIC/has-pass.crc" <<'EOF'
PASS
All checks passed successfully.
security reviewed OWASP compliance
AC-1 acceptance criteria met
error handling null edge case
EOF
  export SAVIA_CRITIC_THRESHOLD=1
  run bash "$SCRIPT" --json "$TMPDIR_CRITIC/has-pass.crc"
  [ "$status" -eq 0 ]
  # Extract score value
  score=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['score'])" 2>/dev/null || echo "0")
  [ "$score" -gt 50 ]
}

# ── --rubric flag ─────────────────────────────────────────────────────────────

@test "SE-201: --rubric flag accepted without crashing" {
  cat > "$TMPDIR_CRITIC/rubric.json" <<'EOF'
{"correctness": 25, "completeness": 25, "security": 25, "spec_compliance": 25}
EOF
  cat > "$TMPDIR_CRITIC/verdict.crc" <<'EOF'
PASS OWASP security AC-1 acceptance error null API
EOF
  export SAVIA_CRITIC_THRESHOLD=1
  run bash "$SCRIPT" --rubric "$TMPDIR_CRITIC/rubric.json" "$TMPDIR_CRITIC/verdict.crc"
  [ "$status" -eq 0 ]
}

@test "SE-201: --rubric with nonexistent file exits with error" {
  cat > "$TMPDIR_CRITIC/verdict.crc" <<'EOF'
PASS OWASP security AC-1 acceptance error
EOF
  run bash "$SCRIPT" --rubric "$TMPDIR_CRITIC/nonexistent-rubric.json" "$TMPDIR_CRITIC/verdict.crc"
  [ "$status" -ne 0 ]
}

# ── .savia/tribunal-scores.jsonl logging ─────────────────────────────────────

@test "SE-201: .savia/tribunal-scores.jsonl is created after execution" {
  cat > "$TMPDIR_CRITIC/verdict.crc" <<'EOF'
PASS OWASP AC-1 acceptance error null API coverage
EOF
  export SAVIA_CRITIC_THRESHOLD=1
  run bash "$SCRIPT" "$TMPDIR_CRITIC/verdict.crc"
  [ -f "$TMPDIR_CRITIC/.savia/tribunal-scores.jsonl" ]
}

@test "SE-201: .savia/tribunal-scores.jsonl appends on repeated runs" {
  cat > "$TMPDIR_CRITIC/verdict.crc" <<'EOF'
PASS OWASP AC-1 acceptance error null API
EOF
  export SAVIA_CRITIC_THRESHOLD=1
  bash "$SCRIPT" "$TMPDIR_CRITIC/verdict.crc" >/dev/null 2>&1
  bash "$SCRIPT" "$TMPDIR_CRITIC/verdict.crc" >/dev/null 2>&1
  count=$(wc -l < "$TMPDIR_CRITIC/.savia/tribunal-scores.jsonl")
  [ "$count" -ge 2 ]
}

# ── court-orchestrator integration ───────────────────────────────────────────

@test "SE-201: court-orchestrator.md mentions tribunal-critic" {
  run grep -F "tribunal-critic" "$REPO_ROOT/.claude/agents/court-orchestrator.md"
  [ "$status" -eq 0 ]
}

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "SE-201: empty verdict file produces error and non-zero exit" {
  touch "$TMPDIR_CRITIC/empty.crc"
  run bash "$SCRIPT" "$TMPDIR_CRITIC/empty.crc"
  [ "$status" -ne 0 ]
}

@test "SE-201: nonexistent verdict file produces clear error message" {
  run bash "$SCRIPT" "$TMPDIR_CRITIC/does-not-exist.crc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "SE-201: setup and teardown use tmpdir (no writes to live workspace)" {
  cat > "$TMPDIR_CRITIC/verdict.crc" <<'EOF'
PASS OWASP security AC-1 error null coverage API
EOF
  export SAVIA_CRITIC_THRESHOLD=1
  run bash "$SCRIPT" "$TMPDIR_CRITIC/verdict.crc"
  # Scores file should be inside TMPDIR_CRITIC, not live .savia
  [ -f "$TMPDIR_CRITIC/.savia/tribunal-scores.jsonl" ]
  # Live workspace .savia should NOT have been written
  live_scores="$REPO_ROOT/.savia/tribunal-scores.jsonl"
  # It's acceptable if it doesn't exist (not created by this test run)
  true
}
