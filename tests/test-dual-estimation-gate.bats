#!/usr/bin/env bats
# BATS tests for .opencode/hooks/dual-estimation-gate.sh
# PostToolUse — SPEC-078 Phase 1. Warns if spec/PBI has effort estimation
# but is missing dual scale (agent + human). Always exits 0. Batch 46.

HOOK=".opencode/hooks/dual-estimation-gate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="${SAVIA_HOOK_PROFILE:-standard}"
  TEST_DIR=$(mktemp -d "$TMPDIR/deg-XXXXXX")
}
teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }
@test "SPEC-078 reference" {
  run grep -c 'SPEC-078' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "has profile_gate standard" {
  run grep -c 'profile_gate "standard"' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Pass-through ────────────────────────────────────────

@test "pass-through: empty stdin exits 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "pass-through: no file_path in JSON exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
}

@test "pass-through: non-spec file path exits 0" {
  echo "content" > "$TEST_DIR/random.md"
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/random.md\"}}"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "pass-through: .py file exits 0" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"/tmp/foo.py"}}'
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "pass-through: nonexistent file exits 0" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"/nonexistent/file.spec.md"}}'
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

# ── No estimation (draft stage) ─────────────────────────

@test "draft: spec without estimation exits silently" {
  cat > "$TEST_DIR/no-est.spec.md" <<EOF
# Spec Draft

Just some content describing the feature scope.
Nothing about time or size yet.
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/no-est.spec.md\"}}"
  [ "$status" -eq 0 ]
  [[ -z "${output}${stderr:-}" ]]
}

# ── Both scales present ─────────────────────────────────

@test "complete: spec with both agent and human scales exits silent" {
  cat > "$TEST_DIR/complete.spec.md" <<EOF
# Complete Spec

agent_effort_minutes: 30
human_effort_hours: 2
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/complete.spec.md\"}}"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "complete: Spanish dual scales also pass" {
  cat > "$TEST_DIR/complete-es.spec.md" <<EOF
# Spec ES

Esfuerzo agente en minutos (agente effort 30 min)
Esfuerzo humano en horas (humano effort 2 hora)
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/complete-es.spec.md\"}}"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

# ── Missing agent scale ─────────────────────────────────

@test "warn: spec with only human scale warns" {
  cat > "$TEST_DIR/only-human.spec.md" <<EOF
# Spec

Effort estimation: 2 hours
human_effort_hours: 2
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/only-human.spec.md\"}}"
  [ "$status" -eq 0 ]
  [[ "${stderr:-$output}" == *"Dual Estimation"* ]]
  [[ "${stderr:-$output}" == *"agent"* ]]
}

# ── Missing human scale ─────────────────────────────────

@test "warn: spec with only agent scale warns" {
  cat > "$TEST_DIR/only-agent.spec.md" <<EOF
# Spec

Effort: 30 minutes
agent_effort_minutes: 30
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/only-agent.spec.md\"}}"
  [ "$status" -eq 0 ]
  [[ "${stderr:-$output}" == *"Dual Estimation"* ]]
  [[ "${stderr:-$output}" == *"human"* ]]
}

# ── Missing both ────────────────────────────────────────

@test "warn: spec with generic effort word but no scales warns" {
  cat > "$TEST_DIR/generic.spec.md" <<EOF
# Spec

This task requires some effort and estimat. Hours needed: unclear.
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/generic.spec.md\"}}"
  [ "$status" -eq 0 ]
  [[ "${stderr:-$output}" == *"Dual Estimation"* ]]
  [[ "${stderr:-$output}" == *"agent"* ]]
  [[ "${stderr:-$output}" == *"human"* ]]
}

# ── File path patterns ──────────────────────────────────

@test "pattern: *.spec.md matches" {
  cat > "$TEST_DIR/test.spec.md" <<EOF
# Test
effort: 1 hour
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/test.spec.md\"}}"
  [[ "${stderr:-$output}" == *"Dual Estimation"* ]]
}

@test "pattern: backlog/pbi/ matches" {
  mkdir -p "$TEST_DIR/backlog/pbi"
  cat > "$TEST_DIR/backlog/pbi/pbi-01.md" <<EOF
# PBI-01
effort: 4 hours
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/backlog/pbi/pbi-01.md\"}}"
  [[ "${stderr:-$output}" == *"Dual Estimation"* ]]
}

@test "pattern: backlog/task/ matches" {
  mkdir -p "$TEST_DIR/backlog/task"
  cat > "$TEST_DIR/backlog/task/t-01.md" <<EOF
# Task 01
effort: 30 min
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/backlog/task/t-01.md\"}}"
  [[ "${stderr:-$output}" == *"Dual Estimation"* ]]
}

@test "pattern: other path like docs/ does NOT match" {
  cat > "$TEST_DIR/doc.md" <<EOF
effort: 1 hour, missing everything
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/doc.md\"}}"
  [[ -z "${stderr:-$output}" ]]
}

# ── Warning content ─────────────────────────────────────

@test "warning: mentions agent_effort_minutes field" {
  cat > "$TEST_DIR/warn.spec.md" <<EOF
effort: 2h
human_effort_hours: 2
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/warn.spec.md\"}}"
  [[ "${stderr:-$output}" == *"agent_effort_minutes"* ]]
}

@test "warning: mentions human_effort_hours field" {
  cat > "$TEST_DIR/warn.spec.md" <<EOF
effort: 30 min
agent_effort_minutes: 30
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/warn.spec.md\"}}"
  [[ "${stderr:-$output}" == *"human_effort_hours"* ]]
}

@test "warning: mentions review_effort_minutes field" {
  cat > "$TEST_DIR/warn.spec.md" <<EOF
effort: 1h
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/warn.spec.md\"}}"
  [[ "${stderr:-$output}" == *"review_effort_minutes"* ]]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: empty spec file exits silent" {
  touch "$TEST_DIR/empty.spec.md"
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/empty.spec.md\"}}"
  [ "$status" -eq 0 ]
  [[ -z "${stderr:-$output}" ]]
}

@test "edge: estimation keyword in comment only" {
  cat > "$TEST_DIR/comment.spec.md" <<EOF
# Spec
<!-- effort estimation required here -->
agent_effort_minutes: 10
human_effort_hours: 1
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/comment.spec.md\"}}"
  [ "$status" -eq 0 ]
  [[ -z "${stderr:-$output}" ]]
}

@test "edge: case-insensitive detection (EFFORT)" {
  cat > "$TEST_DIR/upper.spec.md" <<EOF
# Upper
EFFORT estimation HOURS
EOF
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/upper.spec.md\"}}"
  [[ "${stderr:-$output}" == *"Dual Estimation"* ]]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: agent scale regex check" {
  run grep -c 'agent_effort_minutes\|agent.*effort' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "coverage: human scale regex check" {
  run grep -c 'human_effort_hours\|human.*effort' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "coverage: Spanish keywords (esfuerzo, horas)" {
  run grep -c 'esfuerzo\|horas' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: review_effort_minutes guidance" {
  run grep -c 'review_effort_minutes' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ───────────────────────────────────────────

@test "isolation: always exits 0 (never blocks)" {
  for payload in '' '{}' '{"tool_input":{"file_path":"/x.spec.md"}}'; do
    run bash "$HOOK" <<< "$payload"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook does not modify the spec file" {
  cat > "$TEST_DIR/mod-check.spec.md" <<EOF
effort: 1h
EOF
  local before_hash after_hash
  before_hash=$(sha256sum "$TEST_DIR/mod-check.spec.md" | cut -d' ' -f1)
  bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$TEST_DIR/mod-check.spec.md\"}}" >/dev/null 2>&1
  after_hash=$(sha256sum "$TEST_DIR/mod-check.spec.md" | cut -d' ' -f1)
  [[ "$before_hash" == "$after_hash" ]]
}
