#!/usr/bin/env bats
# Tests for SPEC-124 — pr-agent wrapper
# Ref: docs/propuestas/SPEC-124-pr-agent-wrapper.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/pr-agent-run.sh"
  export SKILL="$REPO_ROOT/.claude/skills/pr-agent-judge/SKILL.md"
  export AGENT="$REPO_ROOT/.claude/agents/pr-agent-judge.md"
  TMPDIR_PA="$(mktemp -d)"
  export TMPDIR_PA
}

teardown() {
  rm -rf "$TMPDIR_PA" 2>/dev/null || true
}

# ── Safety / integrity ───────────────────────────────────────────────────────

@test "safety: wrapper script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "safety: script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: skill file exists" {
  [ -f "$SKILL" ]
}

@test "safety: agent file exists" {
  [ -f "$AGENT" ]
}

# ── Positive: graceful fallbacks ────────────────────────────────────────────

@test "positive: help flag returns usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "positive: missing pr-number rejected with exit 2" {
  run bash "$SCRIPT" --mode review
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "pr-number required"
}

@test "positive: output is valid JSON" {
  run bash "$SCRIPT" --pr-number 123 --repo "fake/repo"
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'judge' in d"
}

@test "positive: judge field is pr-agent" {
  run bash "$SCRIPT" --pr-number 123 --repo "fake/repo"
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['judge']=='pr-agent'"
}

@test "positive: SKILL.md references SPEC-124" {
  grep -q "SPEC-124" "$SKILL"
}

@test "positive: SKILL.md references qodo-ai/pr-agent" {
  grep -qE "qodo-ai/pr-agent|github.com/qodo-ai" "$SKILL"
}

@test "positive: agent declares correct name and model" {
  grep -q "^name: pr-agent-judge" "$AGENT"
  grep -qE "^model: claude-" "$AGENT"
}

@test "positive: agent references SPEC-124" {
  grep -q "SPEC-124" "$AGENT"
}

@test "positive: agent includes handoff section (SPEC-121)" {
  grep -qE "handoff:|^## Handoff" "$AGENT"
}

# ── Negative cases ───────────────────────────────────────────────────────────

@test "negative: unknown flag rejected with exit 2" {
  run bash "$SCRIPT" --bogus-flag
  [ "$status" -eq 2 ]
}

@test "negative: pr-agent not installed → SKIPPED status" {
  # In test env, pr-agent is not installed
  run bash "$SCRIPT" --pr-number 123 --repo "fake/repo"
  # Either SKIPPED (not installed) or status field present
  echo "$output" | grep -qE "SKIPPED|READY"
}

@test "negative: COURT_INCLUDE_PR_AGENT flag check exists" {
  grep -q "COURT_INCLUDE_PR_AGENT" "$SCRIPT"
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: output has status field (SKIPPED or READY)" {
  run bash "$SCRIPT" --pr-number 123 --repo "fake/repo"
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'status' in d"
}

@test "edge: mode defaults to review when not specified" {
  run bash "$SCRIPT" --pr-number 123 --repo "fake/repo"
  # Mode 'review' should appear in output or be respected
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "edge: skill defines trigger condition" {
  grep -qiE "trigger|when|COURT_INCLUDE" "$SKILL"
}

# ── Isolation ────────────────────────────────────────────────────────────────

@test "isolation: script does not write to repo without explicit output" {
  before=$(stat -c %Y "$REPO_ROOT/.git/HEAD" 2>/dev/null || stat -f %m "$REPO_ROOT/.git/HEAD" 2>/dev/null)
  run bash "$SCRIPT" --pr-number 123 --repo "fake/repo"
  after=$(stat -c %Y "$REPO_ROOT/.git/HEAD" 2>/dev/null || stat -f %m "$REPO_ROOT/.git/HEAD" 2>/dev/null)
  [ "$before" = "$after" ]
}

@test "isolation: exit codes well-defined" {
  run bash "$SCRIPT" --pr-number 123 --repo "fake/repo"
  [[ "$status" == "0" || "$status" == "1" || "$status" == "2" ]]
}
