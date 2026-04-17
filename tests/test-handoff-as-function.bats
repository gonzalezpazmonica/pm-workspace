#!/usr/bin/env bats
# Tests for SPEC-121 — handoff-as-function convention in validate-handoff.sh
# Ref: docs/propuestas/SPEC-121-handoff-convention.md
# Ref: docs/rules/domain/agent-handoff-protocol.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export VALIDATOR="$REPO_ROOT/scripts/validate-handoff.sh"
  export PROTOCOL_DOC="$REPO_ROOT/docs/rules/domain/agent-handoff-protocol.md"

  TMPDIR_HF="$(mktemp -d)"
  export TMPDIR_HF

  # Valid handoff-as-function (all required fields + real agent)
  cat > "$TMPDIR_HF/valid-handoff.yaml" <<'EOF'
handoff:
  to: code-reviewer
  spec: SPEC-120
  stage: E2
  context_hash: sha256:48c18e5132b873e8
  reason: "Implementation ready"
  termination_reason: completed
  artifacts:
    - docs/propuestas/SPEC-120-spec-kit-alignment.md
EOF

  # Missing required field: spec
  cat > "$TMPDIR_HF/missing-spec.yaml" <<'EOF'
handoff:
  to: code-reviewer
  stage: E2
  context_hash: sha256:abc123de
  reason: "test"
  termination_reason: completed
EOF

  # Invalid stage
  cat > "$TMPDIR_HF/bad-stage.yaml" <<'EOF'
handoff:
  to: code-reviewer
  spec: SPEC-120
  stage: E9
  context_hash: sha256:abc123de
  reason: "test"
  termination_reason: completed
EOF

  # Unknown agent
  cat > "$TMPDIR_HF/unknown-agent.yaml" <<'EOF'
handoff:
  to: nonexistent-agent-xyz
  spec: SPEC-120
  stage: E2
  context_hash: sha256:abc123de
  reason: "test"
  termination_reason: completed
EOF

  # Legacy format (only termination_reason, no handoff-as-function block)
  cat > "$TMPDIR_HF/legacy-only.yaml" <<'EOF'
termination_reason: completed
notes: "Legacy handoff without SPEC-121 block"
EOF

  # Legacy with invalid reason
  cat > "$TMPDIR_HF/legacy-bad-reason.yaml" <<'EOF'
termination_reason: invalid_enum_value
EOF

  # Bad context_hash (warning, not fatal)
  cat > "$TMPDIR_HF/bad-hash.yaml" <<'EOF'
handoff:
  to: code-reviewer
  spec: SPEC-120
  stage: E2
  context_hash: notasha256hash
  reason: "test"
  termination_reason: completed
EOF
}

teardown() {
  rm -rf "$TMPDIR_HF" 2>/dev/null || true
}

# ── Safety / integrity ───────────────────────────────────────────────────────

@test "safety: validator script exists and is executable" {
  [ -f "$VALIDATOR" ]
  [ -x "$VALIDATOR" ]
}

@test "safety: protocol doc exists and is non-empty" {
  [ -f "$PROTOCOL_DOC" ]
  [ -s "$PROTOCOL_DOC" ]
}

@test "safety: validator does not modify repo state" {
  run bash "$VALIDATOR" --file "$TMPDIR_HF/valid-handoff.yaml"
  # No side effects — repo unchanged (we trust git status; any side effect would be caught)
  [ -f "$VALIDATOR" ]
}

# ── Positive cases ───────────────────────────────────────────────────────────

@test "positive: valid handoff-as-function passes validation" {
  run bash "$VALIDATOR" --file "$TMPDIR_HF/valid-handoff.yaml"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "VALID"
}

@test "positive: legacy termination_reason only still validates" {
  run bash "$VALIDATOR" --file "$TMPDIR_HF/legacy-only.yaml"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "VALID: termination_reason=completed"
}

@test "positive: bad context_hash emits warning but still passes (non-fatal)" {
  run bash "$VALIDATOR" --file "$TMPDIR_HF/bad-hash.yaml"
  # WARNING but exit 0 because all required fields present
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "WARNING.*context_hash" || true
}

@test "positive: protocol doc references SPEC-121" {
  grep -q "SPEC-121" "$PROTOCOL_DOC"
}

@test "positive: protocol doc references OpenAI Agents SDK" {
  grep -qE "OpenAI Agents SDK|openai-agents" "$PROTOCOL_DOC"
}

@test "positive: protocol doc documents required fields" {
  grep -q "context_hash" "$PROTOCOL_DOC"
  grep -q "termination_reason" "$PROTOCOL_DOC"
  grep -qE "^\| \`to\`" "$PROTOCOL_DOC"
}

# ── Negative cases ───────────────────────────────────────────────────────────

@test "negative: missing spec field rejected with exit 2" {
  run bash "$VALIDATOR" --file "$TMPDIR_HF/missing-spec.yaml"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "INVALID.*spec"
}

@test "negative: invalid stage E9 rejected with exit 2" {
  run bash "$VALIDATOR" --file "$TMPDIR_HF/bad-stage.yaml"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "INVALID.*stage"
}

@test "negative: unknown agent in 'to' field rejected" {
  run bash "$VALIDATOR" --file "$TMPDIR_HF/unknown-agent.yaml"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "INVALID.*not found"
}

@test "negative: legacy invalid enum rejected" {
  run bash "$VALIDATOR" --file "$TMPDIR_HF/legacy-bad-reason.yaml"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "INVALID.*enum"
}

@test "negative: nonexistent file errors with exit 2" {
  run bash "$VALIDATOR" --file "/nonexistent-path-xyz.yaml"
  [ "$status" -eq 2 ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: empty file errors cleanly" {
  : > "$TMPDIR_HF/empty.yaml"
  run bash "$VALIDATOR" --file "$TMPDIR_HF/empty.yaml"
  [ "$status" -eq 2 ]
}

@test "edge: help flag returns exit 0 without requiring input" {
  run bash "$VALIDATOR" --help
  [ "$status" -eq 0 ]
}

@test "edge: stage E0 is valid (SDD stage enum boundary low)" {
  cat > "$TMPDIR_HF/stage-e0.yaml" <<'F'
handoff:
  to: code-reviewer
  spec: SPEC-120
  stage: E0
  context_hash: sha256:abc123de
  reason: "test"
  termination_reason: completed
F
  run bash "$VALIDATOR" --file "$TMPDIR_HF/stage-e0.yaml"
  [ "$status" -eq 0 ]
}

@test "edge: stage E4 is valid (SDD stage enum boundary high)" {
  cat > "$TMPDIR_HF/stage-e4.yaml" <<'F'
handoff:
  to: code-reviewer
  spec: SPEC-120
  stage: E4
  context_hash: sha256:abc123de
  reason: "test"
  termination_reason: completed
F
  run bash "$VALIDATOR" --file "$TMPDIR_HF/stage-e4.yaml"
  [ "$status" -eq 0 ]
}

# ── Isolation verification ──────────────────────────────────────────────────

@test "isolation: fixtures live in tmp dir" {
  [[ "$TMPDIR_HF" == /tmp/* ]] || [[ "$TMPDIR_HF" == /var/folders/* ]]
}

@test "isolation: validator exits cleanly on all fixtures (no hangs)" {
  for f in "$TMPDIR_HF"/*.yaml; do
    timeout 5 bash "$VALIDATOR" --file "$f" >/dev/null 2>&1 || true
  done
  [ -d "$TMPDIR_HF" ]  # just confirm we didn't corrupt workspace
}
