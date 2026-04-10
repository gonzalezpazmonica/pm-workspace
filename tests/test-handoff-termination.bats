#!/usr/bin/env bats
# test-handoff-termination.bats — Tests for SPEC-TERMINAL-STATE-HANDOFF
# Ref: docs/specs/SPEC-TERMINAL-STATE-HANDOFF.spec.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/validate-handoff.sh"
  HANDOFF_TMPL="$REPO_ROOT/.claude/rules/domain/handoff-templates.md"
  VERIF="$REPO_ROOT/.claude/rules/domain/verification-before-done.md"
  TMPDIR_HT=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_HT"
}

# ── Script integrity ─────────────────────────────────────────────────────────

@test "script exists" {
  [ -f "$SCRIPT" ]
}

@test "script has bash shebang" {
  head -1 "$SCRIPT" | grep -q "bash"
}

@test "script has set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "script --help shows usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

@test "script references SPEC-TERMINAL-STATE-HANDOFF" {
  grep -q "SPEC-TERMINAL-STATE-HANDOFF" "$SCRIPT"
}

# ── Valid enum values (6 tests) ──────────────────────────────────────────────

@test "valid: completed" {
  run bash -c "echo 'termination_reason: completed' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VALID"* ]]
}

@test "valid: user_abort" {
  run bash -c "echo 'termination_reason: user_abort' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "valid: token_budget" {
  run bash -c "echo 'termination_reason: token_budget' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "valid: stop_hook" {
  run bash -c "echo 'termination_reason: stop_hook' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "valid: max_turns" {
  run bash -c "echo 'termination_reason: max_turns' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "valid: unrecoverable_error" {
  run bash -c "echo 'termination_reason: unrecoverable_error' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

# ── Invalid enum values ──────────────────────────────────────────────────────

@test "invalid: bogus value returns exit 2" {
  run bash -c "echo 'termination_reason: foo' | bash '$SCRIPT'"
  [ "$status" -eq 2 ]
  [[ "$output" == *"INVALID"* ]]
}

@test "invalid: typo value returns exit 2" {
  run bash -c "echo 'termination_reason: completd' | bash '$SCRIPT'"
  [ "$status" -eq 2 ]
}

@test "invalid: empty enum value returns exit 2" {
  run bash -c "echo 'termination_reason:' | bash '$SCRIPT'"
  # Empty value is treated as missing (warning) or invalid
  [[ "$status" -eq 1 ]] || [[ "$status" -eq 2 ]]
}

# ── Missing field (warning) ──────────────────────────────────────────────────

@test "missing field: returns warning exit 1" {
  run bash -c "echo 'from: agent-x' | bash '$SCRIPT'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"WARNING"* ]] || [[ "$output" == *"missing"* ]]
}

# ── File input ───────────────────────────────────────────────────────────────

@test "valid: --file with completed" {
  local f="$TMPDIR_HT/valid.yaml"
  echo 'termination_reason: "completed"' > "$f"
  run bash "$SCRIPT" --file "$f"
  [ "$status" -eq 0 ]
}

@test "nonexistent --file returns exit 2" {
  run bash "$SCRIPT" --file "/nonexistent/handoff.yaml"
  [ "$status" -eq 2 ]
}

# ── Documentation checks ─────────────────────────────────────────────────────

@test "handoff-templates.md references termination_reason" {
  grep -q "termination_reason" "$HANDOFF_TMPL"
}

@test "handoff-templates.md lists enum values" {
  grep -q "completed" "$HANDOFF_TMPL"
  grep -q "token_budget" "$HANDOFF_TMPL"
}

@test "verification-before-done.md has Retry Policy section" {
  grep -q "Retry Policy" "$VERIF"
}

@test "verification-before-done.md references SPEC-TERMINAL-STATE-HANDOFF" {
  grep -q "SPEC-TERMINAL-STATE-HANDOFF" "$VERIF"
}

@test "verification-before-done.md lists all 6 termination reasons" {
  local count=0
  for r in completed user_abort token_budget stop_hook max_turns unrecoverable_error; do
    grep -q "$r" "$VERIF" && count=$((count + 1))
  done
  [ "$count" -eq 6 ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: empty stdin returns exit 2" {
  run bash -c "echo -n '' | bash '$SCRIPT'"
  [ "$status" -eq 2 ]
}

@test "edge: no-arg and no-stdin returns exit 2" {
  run bash "$SCRIPT" </dev/null
  [ "$status" -eq 2 ]
}

@test "edge: boundary — only termination_reason field" {
  run bash -c "echo 'termination_reason: completed' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "edge: large input with termination_reason embedded" {
  local big
  big=$(yes "noise line" | head -500)
  run bash -c "printf '%s\ntermination_reason: completed\n%s\n' \"\$1\" \"\$2\" | bash '$SCRIPT'" _ "$big" "$big"
  [ "$status" -eq 0 ]
}

@test "edge: unknown flag returns exit 2" {
  run bash "$SCRIPT" --unknown-flag
  [ "$status" -eq 2 ]
}

@test "edge: quoted enum value works" {
  run bash -c "echo 'termination_reason: \"completed\"' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "edge: nonexistent --file path" {
  run bash "$SCRIPT" --file "/tmp/does-not-exist-$$.yaml"
  [ "$status" -eq 2 ]
}

# ── Coverage: functions ──────────────────────────────────────────────────────

@test "coverage: extract_termination_reason function exists" {
  grep -q "extract_termination_reason()" "$SCRIPT"
}

@test "coverage: validate_enum function exists" {
  grep -q "validate_enum()" "$SCRIPT"
}

@test "coverage: read_input function exists" {
  grep -q "read_input()" "$SCRIPT"
}

@test "coverage: parse_args function exists" {
  grep -q "parse_args()" "$SCRIPT"
}

@test "coverage: VALID_REASONS array has 6 values" {
  # Count lines between VALID_REASONS=( and closing )
  local count
  count=$(awk '/^VALID_REASONS=\(/{flag=1;next} /^\)/{flag=0} flag' "$SCRIPT" | grep -c '"')
  [ "$count" -eq 6 ]
}
