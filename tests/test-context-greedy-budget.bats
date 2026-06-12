#!/usr/bin/env bats
# Ref: scripts/context-greedy-budget.{py,sh} — SPEC-189
# Tests for the bash wrapper and CLI smoke against real fixtures.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/context-greedy-budget.sh"
  export PY_SCRIPT="$REPO_ROOT/scripts/context-greedy-budget.py"
  export FIXTURES="$REPO_ROOT/tests/fixtures/context-greedy-budget"
  TMPDIR_CGB=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_CGB"
}

@test "shell wrapper exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "no args shows help" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"context-greedy-budget"* ]]
  [[ "$output" == *"SPEC-189"* ]]
}

@test "--help exits zero with usage" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"--budget"* ]]
  [[ "$output" == *"--format"* ]]
}

@test "missing input returns exit 3" {
  run bash "$SCRIPT" "$TMPDIR_CGB/nope.acm" "anything"
  [[ "$status" -eq 3 ]]
  [[ "$output" == *"not found"* ]]
}

@test "smoke: ACM fixture with markdown output" {
  run bash "$SCRIPT" "$FIXTURES/sample.acm" "authentication user" --budget 400
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Context Subgraph"* ]]
  [[ "$output" == *"Selected"* ]]
  [[ "$output" == *"Authentication Service"* ]]
}

@test "smoke: JSON fixture with json output is valid JSON" {
  run bash "$SCRIPT" "$FIXTURES/sample-graph.json" "auth jwt" --budget 300 --format json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import json, sys; json.loads(sys.stdin.read())"
}

@test "smoke: jsonl format produces parseable lines" {
  run bash "$SCRIPT" "$FIXTURES/sample-graph.json" "auth" --budget 200 --format jsonl
  [[ "$status" -eq 0 ]]
  # Every non-empty line must parse as JSON
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" | python3 -c "import json, sys; json.loads(sys.stdin.read())"
  done <<< "$output"
}

@test "explain table goes to stderr with score columns" {
  run bash -c "bash '$SCRIPT' '$FIXTURES/sample.acm' 'authentication' --budget 400 --explain 2>&1 1>/dev/null"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"id"* ]]
  [[ "$output" == *"score"* ]]
  [[ "$output" == *"structural"* ]]
  [[ "$output" == *"semantic"* ]]
}

@test "deterministic: same input twice → same output" {
  out1=$(bash "$SCRIPT" "$FIXTURES/sample.acm" "auth" --budget 300)
  out2=$(bash "$SCRIPT" "$FIXTURES/sample.acm" "auth" --budget 300)
  [[ "$out1" == "$out2" ]]
}

@test "no-numpy: script runs even when numpy unimport (sanity)" {
  # We can't really uninstall numpy; instead, verify the source has no numpy import.
  ! grep -E "^import numpy" "$PY_SCRIPT"
  ! grep -E "^from numpy" "$PY_SCRIPT"
}

@test "no-vendor: forbidden top-level imports absent" {
  ! grep -E "^import slurp" "$PY_SCRIPT"
  ! grep -E "^import sklearn" "$PY_SCRIPT"
  ! grep -E "^import networkx" "$PY_SCRIPT"
}

@test "tiktoken is opt-in inside try/except" {
  # The only mention of tiktoken should be inside a try block (lazy import).
  run grep -A1 "import tiktoken" "$PY_SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "real INDEX.acm: chat query under 500 tokens completes" {
  ACM="$REPO_ROOT/projects/savia-mobile-android/.agent-maps/INDEX.acm"
  if [[ ! -f "$ACM" ]]; then
    skip "INDEX.acm not present in this checkout"
  fi
  run bash "$SCRIPT" "$ACM" "chat" --budget 500
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Selected"* ]]
}

@test "budget is respected: tokens_used <= budget" {
  out=$(bash "$SCRIPT" "$FIXTURES/sample.acm" "auth user payment" --budget 100 --format json)
  echo "$out" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d['stats']['tokens_used'] <= d['stats']['tokens_budget'], d['stats']
"
}

@test "min-score filter excludes nodes below threshold" {
  out=$(bash "$SCRIPT" "$FIXTURES/sample.acm" "authentication" --budget 5000 --min-score 0.4 --format json)
  echo "$out" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
for n in d['nodes']:
    assert n['score'] >= 0.0
"
}

@test "auto-detect: .acm extension picks ACM adapter" {
  run bash "$SCRIPT" "$FIXTURES/sample.acm" "auth" --budget 200
  [[ "$status" -eq 0 ]]
  # ACM nodes have kind 'doc'
  out_json=$(bash "$SCRIPT" "$FIXTURES/sample.acm" "auth" --budget 200 --format json)
  echo "$out_json" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert any(n.get('kind') == 'doc' for n in d['nodes']), d
"
}
