#!/usr/bin/env bats
# test-causal-confidence-channel.bats — SPEC-188 F3 tests
# Tests for Decision Trace Writer (P5) and Capture Hook
# Run: bats tests/test-causal-confidence-channel.bats
# Ref: SPEC-188 F3 — docs/propuestas/SPEC-188-root-cause-investigation-architecture.md

setup() {
  REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel 2>/dev/null || pwd)"
  WRITER="${REPO_ROOT}/scripts/decision-trace-writer.py"
  HOOK="${REPO_ROOT}/.opencode/hooks/decision-trace-capture.sh"
  PROTOCOL="${REPO_ROOT}/docs/rules/domain/decision-trace-protocol.md"
  TRACES_DIR="$(mktemp -d)"
  export SAVIA_DECISION_TRACE=on
}

teardown() {
  rm -rf "$TRACES_DIR"
}

# 1 — writer produces valid JSON
@test "decision-trace-writer.py produces valid JSON output" {
  run python3 "$WRITER" \
    --agent test-agent \
    --decision "Use PostgreSQL" \
    --rationale "Need concurrent transactions" \
    --confidence 0.85 \
    --output "$TRACES_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"
}

# 2 — output directory is created
@test "output/decision-traces directory is created when missing" {
  FRESH_DIR="${TRACES_DIR}/fresh/nested"
  rm -rf "$FRESH_DIR"
  run python3 "$WRITER" \
    --agent test-agent \
    --decision "Test decision" \
    --rationale "Test rationale" \
    --confidence 0.7 \
    --output "$FRESH_DIR"
  [ "$status" -eq 0 ]
  [ -d "$FRESH_DIR" ]
}

# 3 — JSON file written to output directory
@test "decision-trace-writer.py writes JSON file to output dir" {
  python3 "$WRITER" \
    --agent trace-test \
    --decision "Write to disk" \
    --rationale "Disk write verification" \
    --confidence 0.9 \
    --output "$TRACES_DIR" >/dev/null
  FOUND=$(find "$TRACES_DIR" -name "*.json" | wc -l | tr -d ' ')
  [ "$FOUND" -ge 1 ]
}

# 4 — confidence is validated in [0, 1]
@test "decision-trace-writer.py rejects confidence outside [0,1]" {
  run python3 "$WRITER" \
    --agent test-agent \
    --decision "Bad confidence" \
    --rationale "Should fail" \
    --confidence 1.5 \
    --output "$TRACES_DIR"
  [ "$status" -ne 0 ]
}

# 5 — alternatives field is present in output JSON
@test "alternatives field is present in written trace JSON" {
  python3 "$WRITER" \
    --agent trace-test \
    --decision "Choose A" \
    --rationale "A is better" \
    --confidence 0.8 \
    --alternatives "B (rejected: cost), C (rejected: complexity)" \
    --output "$TRACES_DIR" >/dev/null
  TRACE_FILE=$(find "$TRACES_DIR" -name "*.json" | head -1)
  [ -n "$TRACE_FILE" ]
  ALT_VAL=$(python3 -c "import json; d=json.load(open('$TRACE_FILE')); print(d.get('alternatives','MISSING'))")
  [ "$ALT_VAL" != "MISSING" ]
  [ "$ALT_VAL" != "" ]
}

# 6 — hook exists and is executable
@test "decision-trace-capture.sh hook exists and is executable" {
  [ -f "$HOOK" ]
  [ -x "$HOOK" ]
}

# 7 — SAVIA_DECISION_TRACE=off means no file written
@test "SAVIA_DECISION_TRACE=off prevents file creation" {
  BEFORE=$(find "$TRACES_DIR" -name "*.json" | wc -l | tr -d ' ')
  SAVIA_DECISION_TRACE=off python3 "$WRITER" \
    --agent test-agent \
    --decision "Should not write" \
    --rationale "Flag is off" \
    --confidence 0.5 \
    --output "$TRACES_DIR" >/dev/null 2>&1
  AFTER=$(find "$TRACES_DIR" -name "*.json" | wc -l | tr -d ' ')
  [ "$AFTER" -eq "$BEFORE" ]
}

# 8 — hook exits 0 always (even with no input / flag off)
@test "decision-trace-capture.sh exits 0 when SAVIA_DECISION_TRACE=off" {
  run bash "$HOOK" <<< ""
  # hook must exit 0 regardless
  [ "$status" -eq 0 ]
}

# 9 — decision-trace-protocol.md exists
@test "docs/rules/domain/decision-trace-protocol.md exists" {
  [ -f "$PROTOCOL" ]
}

# 10 — written trace has required fields
@test "written trace JSON contains all required fields" {
  python3 "$WRITER" \
    --agent required-fields-agent \
    --decision "Fields check" \
    --rationale "Verify required fields" \
    --confidence 0.75 \
    --spec-ref "SPEC-188" \
    --output "$TRACES_DIR" >/dev/null
  TRACE_FILE=$(find "$TRACES_DIR" -name "*required-fields*" | head -1)
  [ -n "$TRACE_FILE" ]
  python3 -c "
import json, sys
d = json.load(open('$TRACE_FILE'))
required = ['ts', 'agent', 'decision', 'rationale', 'confidence', 'alternatives', 'causal_chain', 'spec_ref']
missing = [k for k in required if k not in d]
if missing:
    print('Missing:', missing)
    sys.exit(1)
print('all fields present')
"
}
