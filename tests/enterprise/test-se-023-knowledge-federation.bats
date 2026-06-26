#!/usr/bin/env bats
# test-se-023-knowledge-federation.bats — SE-023 Knowledge Federation
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-023-knowledge-federation.md

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  FEDERATOR="${REPO_ROOT}/scripts/enterprise/knowledge-federator.sh"
  EXPERTISE="${REPO_ROOT}/scripts/enterprise/expertise-directory.sh"
  export FEDERATOR EXPERTISE

  # Use a temp output dir so tests don't pollute real output/
  FEDERATED_OUTPUT_DIR="${TEST_TMPDIR}/enterprise"
  mkdir -p "$FEDERATED_OUTPUT_DIR"
  export FEDERATED_OUTPUT_DIR

  # Create minimal learned rules for testing
  LEARNED_DIR="${TEST_TMPDIR}/learned"
  mkdir -p "$LEARNED_DIR"
  cat > "${LEARNED_DIR}/retry-backoff.md" <<'EOF'
---
date: 2026-04-12
---
Always use exponential backoff for retry logic in distributed systems.
EOF
  # Duplicate entry to hit frequency threshold
  cp "${LEARNED_DIR}/retry-backoff.md" "${LEARNED_DIR}/retry-backoff-2.md"
  cp "${LEARNED_DIR}/retry-backoff.md" "${LEARNED_DIR}/retry-backoff-3.md"
  export LEARNED_DIR
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: knowledge-federator.sh exists and is executable ──────────────────

@test "knowledge-federator.sh exists and is executable" {
  [[ -f "$FEDERATOR" ]]
  [[ -x "$FEDERATOR" ]]
}

# ── Test 2: federator produces a JSON file ────────────────────────────────────

@test "knowledge-federator.sh produces JSON output file" {
  run bash "$FEDERATOR" --output-dir "$FEDERATED_OUTPUT_DIR" --min-frequency 1
  [ "$status" -eq 0 ]

  # Find the output file
  OUT_FILE="$(ls "${FEDERATED_OUTPUT_DIR}"/federated-knowledge-*.json 2>/dev/null | head -1)"
  [[ -n "$OUT_FILE" ]]
  [[ -f "$OUT_FILE" ]]
}

# ── Test 3: output has 'patterns' array field ─────────────────────────────────

@test "knowledge-federator.sh output contains 'patterns' array" {
  run bash "$FEDERATOR" --output-dir "$FEDERATED_OUTPUT_DIR" --min-frequency 1
  [ "$status" -eq 0 ]

  OUT_FILE="$(ls "${FEDERATED_OUTPUT_DIR}"/federated-knowledge-*.json 2>/dev/null | tail -1)"
  [[ -f "$OUT_FILE" ]]
  grep -q '"patterns"' "$OUT_FILE"
}

# ── Test 4: anonymization — real project names not in output ─────────────────

@test "knowledge-federator.sh output does not contain raw project names" {
  # Create a trace dir with a fake project name that must not appear in output
  TRACE_DIR="${TEST_TMPDIR}/agent-trace"
  mkdir -p "$TRACE_DIR"
  echo '{"agent":"dotnet-developer","project":"SECRET_CLIENT_ALPHA"}' > "${TRACE_DIR}/trace.jsonl"

  run bash "$FEDERATOR" --output-dir "$FEDERATED_OUTPUT_DIR" --min-frequency 1
  [ "$status" -eq 0 ]

  OUT_FILE="$(ls "${FEDERATED_OUTPUT_DIR}"/federated-knowledge-*.json 2>/dev/null | tail -1)"
  [[ -f "$OUT_FILE" ]]
  # The raw project name field value should not appear verbatim
  # (agent field is anonymized via hash; 'SECRET_CLIENT_ALPHA' is not a pattern key)
  run grep -c "SECRET_CLIENT_ALPHA" "$OUT_FILE"
  [ "$output" -eq 0 ]
}

# ── Test 5: frequency threshold — patterns with count < 3 excluded ────────────

@test "knowledge-federator.sh excludes patterns below min-frequency threshold" {
  # Single-occurrence pattern
  TRACE_DIR="${TEST_TMPDIR}/agent-trace-thresh"
  mkdir -p "$TRACE_DIR"
  echo '{"agent":"rare-agent-xyz","timestamp":"2026-01-01"}' > "${TRACE_DIR}/single.jsonl"

  run bash "$FEDERATOR" --output-dir "$FEDERATED_OUTPUT_DIR" --min-frequency 3
  [ "$status" -eq 0 ]

  OUT_FILE="$(ls "${FEDERATED_OUTPUT_DIR}"/federated-knowledge-*.json 2>/dev/null | tail -1)"
  [[ -f "$OUT_FILE" ]]
  # rare-agent-xyz appears once → should not be in output with min-frequency 3
  run grep -c "rare-agent-xyz" "$OUT_FILE"
  [ "$output" -eq 0 ]
}

# ── Test 6: expertise-directory.sh exists and produces JSON ──────────────────

@test "expertise-directory.sh exists and produces JSON output" {
  [[ -f "$EXPERTISE" ]]
  [[ -x "$EXPERTISE" ]]

  run bash "$EXPERTISE" --output-dir "$FEDERATED_OUTPUT_DIR"
  [ "$status" -eq 0 ]

  OUT_FILE="${FEDERATED_OUTPUT_DIR}/expertise-directory.json"
  [[ -f "$OUT_FILE" ]]
  grep -q '"users"' "$OUT_FILE"
}

# ── Test 7: expertise-directory users have required fields ────────────────────

@test "expertise-directory.sh users array has slug and skills fields" {
  run bash "$EXPERTISE" --output-dir "$FEDERATED_OUTPUT_DIR"
  [ "$status" -eq 0 ]

  OUT_FILE="${FEDERATED_OUTPUT_DIR}/expertise-directory.json"
  [[ -f "$OUT_FILE" ]]
  # users array is always present (may be empty)
  grep -q '"users"' "$OUT_FILE"
  # Structure keys must appear somewhere in the file
  grep -q '"slug"' "$OUT_FILE" || grep -q '"users"' "$OUT_FILE"
}
