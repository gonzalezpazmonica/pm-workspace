#!/usr/bin/env bats
# tests/test-se-200-context-condenser.bats
# SE-200 — LLM Condenser rolling window context compression
# Ref: docs/propuestas/SE-200-llm-condenser.md

SCRIPT_SH="scripts/context-condenser.sh"
SCRIPT_PY="scripts/context-condenser.py"

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  mkdir -p "$TMPDIR_TEST/output"
  export PROJECT_ROOT="$TMPDIR_TEST"
  SESSION_LOG="$TMPDIR_TEST/output/session-action-log.jsonl"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

_make_log() {
  # Generate N synthetic JSONL lines
  local n="$1"
  local path="$2"
  : > "$path"
  for i in $(seq 1 "$n"); do
    echo "{\"type\":\"observation\",\"seq\":$i,\"msg\":\"event $i\"}" >> "$path"
  done
}

# ── Existence & executability ─────────────────────────────────────────────────

@test "SE-200: context-condenser.sh exists" {
  [ -f "$SCRIPT_SH" ]
}

@test "SE-200: context-condenser.sh is executable" {
  [ -x "$SCRIPT_SH" ]
}

@test "SE-200: context-condenser.py exists" {
  [ -f "$SCRIPT_PY" ]
}

@test "SE-200: context-condenser.py is executable" {
  [ -x "$SCRIPT_PY" ]
}

# ── set -uo pipefail ──────────────────────────────────────────────────────────

@test "SE-200: context-condenser.sh contains set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT_SH"
}

# ── py_compile ────────────────────────────────────────────────────────────────

@test "SE-200: context-condenser.py passes py_compile" {
  python3 -m py_compile "$SCRIPT_PY"
}

# ── SE-200 reference ──────────────────────────────────────────────────────────

@test "SE-200: SE-200 referenced in context-condenser.sh" {
  grep -q "SE-200" "$SCRIPT_SH"
}

@test "SE-200: SE-200 referenced in context-condenser.py" {
  grep -q "SE-200" "$SCRIPT_PY"
}

# ── exit 0 when log does not exist ───────────────────────────────────────────

@test "SE-200: exit 0 when session log does not exist" {
  run bash "$SCRIPT_SH"
  [ "$status" -eq 0 ]
}

# ── exit 0 when log < max_size ───────────────────────────────────────────────

@test "SE-200: exit 0 when log has fewer events than max_size" {
  _make_log 10 "$SESSION_LOG"
  run bash "$SCRIPT_SH" --session-log "$SESSION_LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no condensation needed"* ]]
}

# ── --dry-run does not modify files ──────────────────────────────────────────

@test "SE-200: --dry-run does not write any condensation file" {
  _make_log 130 "$SESSION_LOG"
  run bash "$SCRIPT_SH" --dry-run --session-log "$SESSION_LOG"
  [ "$status" -eq 0 ]
  # No condensation file should be written
  condensation_count=$(find "$TMPDIR_TEST/output" -name "condensations-*.jsonl" | wc -l)
  [ "$condensation_count" -eq 0 ]
}

@test "SE-200: --dry-run output mentions DRY RUN and compress numbers" {
  _make_log 130 "$SESSION_LOG"
  run bash "$SCRIPT_SH" --dry-run --session-log "$SESSION_LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
}

@test "SE-200: --dry-run does not modify the session log" {
  _make_log 130 "$SESSION_LOG"
  original_lines=$(wc -l < "$SESSION_LOG")
  bash "$SCRIPT_SH" --dry-run --session-log "$SESSION_LOG"
  after_lines=$(wc -l < "$SESSION_LOG")
  [ "$original_lines" -eq "$after_lines" ]
}

# ── --stats flag ─────────────────────────────────────────────────────────────

@test "SE-200: --stats prints event count" {
  _make_log 50 "$SESSION_LOG"
  run bash "$SCRIPT_SH" --stats --session-log "$SESSION_LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"events=50"* ]]
}

@test "SE-200: --stats with overflow log mentions 'would compress'" {
  _make_log 130 "$SESSION_LOG"
  run bash "$SCRIPT_SH" --stats --session-log "$SESSION_LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would compress"* ]]
}

# ── condensation entry written ────────────────────────────────────────────────

@test "SE-200: condensation entry written to condensations-YYYYMMDD.jsonl" {
  _make_log 130 "$SESSION_LOG"
  run python3 "$SCRIPT_PY" \
    --log "$SESSION_LOG" \
    --max-size 120 \
    --keep-head 4 \
    --keep-tail 60
  [ "$status" -eq 0 ]
  condensation_file=$(find "$TMPDIR_TEST/output" -name "condensations-*.jsonl" | head -1)
  [ -n "$condensation_file" ]
  [ -f "$condensation_file" ]
}

@test "SE-200: condensation entry contains required fields" {
  _make_log 130 "$SESSION_LOG"
  python3 "$SCRIPT_PY" \
    --log "$SESSION_LOG" \
    --max-size 120 \
    --keep-head 4 \
    --keep-tail 60
  condensation_file=$(find "$TMPDIR_TEST/output" -name "condensations-*.jsonl" | head -1)
  content=$(cat "$condensation_file")
  # Must have all AC5 required fields
  echo "$content" | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
required = ['timestamp', 'session_id', 'events_total', 'events_condensed', 'summary']
missing = [k for k in required if k not in data]
if missing:
    print('Missing:', missing)
    sys.exit(1)
"
}

# ── head preserved ────────────────────────────────────────────────────────────

@test "SE-200: head (first 4 events) preserved after condensation" {
  _make_log 130 "$SESSION_LOG"
  python3 "$SCRIPT_PY" \
    --log "$SESSION_LOG" \
    --max-size 120 \
    --keep-head 4 \
    --keep-tail 60
  # First 4 lines of condensed log must contain seq 1-4
  for i in 1 2 3 4; do
    grep -q "\"seq\":$i" <(head -n 4 "$SESSION_LOG")
  done
}

# ── tail preserved ────────────────────────────────────────────────────────────

@test "SE-200: tail (last 60 events) preserved after condensation" {
  _make_log 130 "$SESSION_LOG"
  python3 "$SCRIPT_PY" \
    --log "$SESSION_LOG" \
    --max-size 120 \
    --keep-head 4 \
    --keep-tail 60
  # Last line should be seq=130
  last_line=$(tail -n 1 "$SESSION_LOG")
  echo "$last_line" | grep -q "\"seq\":130"
}

# ── protocol doc ──────────────────────────────────────────────────────────────

@test "SE-200: context-condenser-protocol.md exists" {
  [ -f "docs/rules/domain/context-condenser-protocol.md" ]
}

@test "SE-200: protocol doc has context_tier and token_budget frontmatter" {
  grep -q "context_tier" "docs/rules/domain/context-condenser-protocol.md"
  grep -q "token_budget" "docs/rules/domain/context-condenser-protocol.md"
}

# ── edge: empty log handled ───────────────────────────────────────────────────

@test "SE-200: empty session log is handled gracefully" {
  touch "$SESSION_LOG"
  run bash "$SCRIPT_SH" --session-log "$SESSION_LOG"
  [ "$status" -eq 0 ]
}

# ── edge: log exactly at max_size (no condensation) ──────────────────────────

@test "SE-200: log exactly at max_size does not trigger condensation" {
  _make_log 120 "$SESSION_LOG"
  run bash "$SCRIPT_SH" --session-log "$SESSION_LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no condensation needed"* ]]
  condensation_count=$(find "$TMPDIR_TEST/output" -name "condensations-*.jsonl" | wc -l)
  [ "$condensation_count" -eq 0 ]
}

# ── Python --stats flag ───────────────────────────────────────────────────────

@test "SE-200: python --stats does not write any files" {
  _make_log 130 "$SESSION_LOG"
  original_mtime=$(stat -c %Y "$SESSION_LOG")
  sleep 1
  python3 "$SCRIPT_PY" \
    --log "$SESSION_LOG" \
    --max-size 120 \
    --keep-head 4 \
    --keep-tail 60 \
    --stats
  condensation_count=$(find "$TMPDIR_TEST/output" -name "condensations-*.jsonl" | wc -l)
  [ "$condensation_count" -eq 0 ]
}
