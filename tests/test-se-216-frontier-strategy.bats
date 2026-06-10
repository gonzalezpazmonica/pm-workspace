#!/usr/bin/env bats
# test-se-216-frontier-strategy.bats — SE-216 Slice 3: Frontier Strategies
# Ref: docs/propuestas/SE-216-evo-patterns.md

SCRIPT="scripts/frontier-strategy.sh"

setup() {
  # Isolated tmp dir per test — avoids cross-test contamination
  TEST_TMPDIR="$(mktemp -d)"
  export AGENT_SCRATCHPAD_OUTPUT_DIR="$TEST_TMPDIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

THREE_ITEMS='[
  {"id": "skill-abc", "scores": {"correctness": 0.8, "latency": 0.6}, "metadata": {}},
  {"id": "skill-def", "scores": {"correctness": 0.5, "latency": 0.9}, "metadata": {}},
  {"id": "skill-ghi", "scores": {"correctness": 0.7, "latency": 0.7}, "metadata": {}}
]'
# avg scores: skill-abc=0.70, skill-def=0.70, skill-ghi=0.70
# correctness leader: skill-abc(0.8); latency leader: skill-def(0.9)

HIGH_SCORES='[
  {"id": "best",   "scores": {"quality": 0.95}, "metadata": {}},
  {"id": "middle", "scores": {"quality": 0.60}, "metadata": {}},
  {"id": "worst",  "scores": {"quality": 0.20}, "metadata": {}}
]'
# avg: best=0.95, middle=0.60, worst=0.20

FIVE_ITEMS='[
  {"id": "a", "scores": {"x": 0.9, "y": 0.1}, "metadata": {}},
  {"id": "b", "scores": {"x": 0.5, "y": 0.5}, "metadata": {}},
  {"id": "c", "scores": {"x": 0.3, "y": 0.8}, "metadata": {}},
  {"id": "d", "scores": {"x": 0.7, "y": 0.4}, "metadata": {}},
  {"id": "e", "scores": {"x": 0.2, "y": 0.6}, "metadata": {}}
]'

SINGLE_ITEM='[{"id": "only", "scores": {"q": 0.5}, "metadata": {}}]'

IDENTICAL_SCORES='[
  {"id": "x1", "scores": {"q": 0.5, "r": 0.5}, "metadata": {}},
  {"id": "x2", "scores": {"q": 0.5, "r": 0.5}, "metadata": {}},
  {"id": "x3", "scores": {"q": 0.5, "r": 0.5}, "metadata": {}}
]'

PARETO_ITEMS='[
  {"id": "specialist-a", "scores": {"correctness": 0.9, "latency": 0.2}, "metadata": {}},
  {"id": "specialist-b", "scores": {"correctness": 0.2, "latency": 0.9}, "metadata": {}},
  {"id": "mediocre",     "scores": {"correctness": 0.5, "latency": 0.5}, "metadata": {}}
]'
# specialist-a leads correctness; specialist-b leads latency
# mediocre has higher avg than specialist-a (0.55>0.55) — tied, but neither leads any task

SINGLE_TASK='[
  {"id": "top",    "scores": {"only_metric": 0.9}, "metadata": {}},
  {"id": "bottom", "scores": {"only_metric": 0.3}, "metadata": {}}
]'

# ---------------------------------------------------------------------------
# T-01: Script exists and is executable
# ---------------------------------------------------------------------------
@test "T-01: script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# ---------------------------------------------------------------------------
# T-02: set -uo pipefail present
# ---------------------------------------------------------------------------
@test "T-02: set -uo pipefail is present in script" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

# ---------------------------------------------------------------------------
# T-03: argmax returns item with highest average score
# ---------------------------------------------------------------------------
@test "T-03: argmax returns item with highest score" {
  run bash "$SCRIPT" select --strategy argmax --k 1 --input-json "$HIGH_SCORES"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert len(data) == 1, f'Expected 1 item, got {len(data)}'
assert data[0]['id'] == 'best', f'Expected best, got {data[0][\"id\"]}'
"
}

# ---------------------------------------------------------------------------
# T-04: argmax with k=2 returns exactly 2 distinct items
# ---------------------------------------------------------------------------
@test "T-04: argmax k=2 returns exactly 2 distinct items" {
  run bash "$SCRIPT" select --strategy argmax --k 2 --input-json "$HIGH_SCORES"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert len(data) == 2, f'Expected 2 items, got {len(data)}'
ids = [d['id'] for d in data]
assert len(set(ids)) == 2, f'IDs not distinct: {ids}'
"
}

# ---------------------------------------------------------------------------
# T-05: top_k=3 returns exactly 3 distinct items
# ---------------------------------------------------------------------------
@test "T-05: top_k=3 returns exactly 3 distinct items" {
  run bash "$SCRIPT" select --strategy top_k --k 3 --input-json "$HIGH_SCORES"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert len(data) == 3, f'Expected 3 items, got {len(data)}'
ids = [d['id'] for d in data]
assert len(set(ids)) == 3, f'IDs not distinct: {ids}'
"
}

# ---------------------------------------------------------------------------
# T-06: epsilon_greedy epsilon=0 always returns argmax
# ---------------------------------------------------------------------------
@test "T-06: epsilon_greedy epsilon=0 behaves like argmax" {
  # Run 5 times; all should return 'best' since epsilon=0 means no exploration
  for _ in 1 2 3 4 5; do
    run bash "$SCRIPT" select --strategy epsilon_greedy --k 1 --epsilon 0 --input-json "$HIGH_SCORES"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert data[0]['id'] == 'best', f'Expected best, got {data[0][\"id\"]}'
"
  done
}

# ---------------------------------------------------------------------------
# T-07: epsilon_greedy epsilon=1 returns a valid item (may not be argmax)
# ---------------------------------------------------------------------------
@test "T-07: epsilon_greedy epsilon=1 returns a valid item" {
  run bash "$SCRIPT" select --strategy epsilon_greedy --k 1 --epsilon 1.0 --input-json "$HIGH_SCORES"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert len(data) == 1, f'Expected 1 item, got {len(data)}'
valid_ids = {'best', 'middle', 'worst'}
assert data[0]['id'] in valid_ids, f'Got invalid id: {data[0][\"id\"]}'
"
}

# ---------------------------------------------------------------------------
# T-08: softmax with very low temperature converges to argmax
# ---------------------------------------------------------------------------
@test "T-08: softmax T=0.001 converges to argmax" {
  # With very low T, highest score item should dominate almost always
  # Run 10 times and check majority
  count=0
  for _ in $(seq 1 10); do
    out=$(bash "$SCRIPT" select --strategy softmax --k 1 --temperature 0.001 --input-json "$HIGH_SCORES")
    id=$(echo "$out" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
    if [ "$id" = "best" ]; then
      count=$((count+1))
    fi
  done
  # At T=0.001 with score 0.95 vs 0.60/0.20, best should dominate all 10
  [ "$count" -ge 9 ]
}

# ---------------------------------------------------------------------------
# T-09: softmax returns k distinct items
# ---------------------------------------------------------------------------
@test "T-09: softmax returns k=3 distinct items" {
  run bash "$SCRIPT" select --strategy softmax --k 3 --temperature 1.0 --input-json "$HIGH_SCORES"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert len(data) == 3, f'Expected 3, got {len(data)}'
ids = [d['id'] for d in data]
assert len(set(ids)) == 3, f'IDs not distinct: {ids}'
"
}

# ---------------------------------------------------------------------------
# T-10: pareto_per_task preserves specialists (both A and B appear)
# ---------------------------------------------------------------------------
@test "T-10: pareto_per_task preserves both task specialists" {
  run bash "$SCRIPT" select --strategy pareto_per_task --k 3 --input-json "$PARETO_ITEMS"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ids = {d['id'] for d in data}
assert 'specialist-a' in ids, f'specialist-a missing from {ids}'
assert 'specialist-b' in ids, f'specialist-b missing from {ids}'
"
}

# ---------------------------------------------------------------------------
# T-11: pareto_per_task with a single task is equivalent to argmax
# ---------------------------------------------------------------------------
@test "T-11: pareto_per_task single-task behaves like argmax" {
  run bash "$SCRIPT" select --strategy pareto_per_task --k 1 --input-json "$SINGLE_TASK"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert data[0]['id'] == 'top', f'Expected top, got {data[0][\"id\"]}'
"
}

# ---------------------------------------------------------------------------
# T-12: empty input returns [] without crash
# ---------------------------------------------------------------------------
@test "T-12: empty input returns [] without crash" {
  run bash "$SCRIPT" select --strategy argmax --k 1 --input-json "[]"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert data == [], f'Expected [], got {data}'
"
}

# ---------------------------------------------------------------------------
# T-13: unknown strategy exits non-zero and lists valid strategies
# ---------------------------------------------------------------------------
@test "T-13: unknown strategy exits non-zero with valid strategy list" {
  run bash "$SCRIPT" select --strategy nonexistent --k 1 --input-json "$HIGH_SCORES"
  [ "$status" -ne 0 ]
  echo "$output$stderr" | grep -qiE "argmax|top_k|epsilon_greedy|softmax|pareto_per_task"
}

# ---------------------------------------------------------------------------
# T-14: output is valid JSON
# ---------------------------------------------------------------------------
@test "T-14: output is valid JSON" {
  run bash "$SCRIPT" select --strategy top_k --k 2 --input-json "$THREE_ITEMS"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"
}

# ---------------------------------------------------------------------------
# T-15: --input-json inline works without --input-file
# ---------------------------------------------------------------------------
@test "T-15: --input-json inline works" {
  run bash "$SCRIPT" select --strategy argmax --k 1 \
    --input-json '[{"id":"z","scores":{"q":0.99},"metadata":{}}]'
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert data[0]['id'] == 'z'
"
}

# ---------------------------------------------------------------------------
# T-16: stdin works when no --input-file or --input-json
# ---------------------------------------------------------------------------
@test "T-16: reads from stdin when no input flag is given" {
  run bash -c "echo '$HIGH_SCORES' | bash $SCRIPT select --strategy argmax --k 1"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert data[0]['id'] == 'best'
"
}

# ---------------------------------------------------------------------------
# T-17: k greater than number of items returns all available items
# ---------------------------------------------------------------------------
@test "T-17: k larger than item count returns all items without error" {
  run bash "$SCRIPT" select --strategy top_k --k 10 --input-json "$HIGH_SCORES"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert len(data) == 3, f'Expected 3 (all items), got {len(data)}'
"
}

# ---------------------------------------------------------------------------
# T-18: items with identical scores do not crash
# ---------------------------------------------------------------------------
@test "T-18: identical scores do not crash" {
  run bash "$SCRIPT" select --strategy argmax --k 2 --input-json "$IDENTICAL_SCORES"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert len(data) == 2
"
}

# ---------------------------------------------------------------------------
# T-19: single-task items work across all strategies
# ---------------------------------------------------------------------------
@test "T-19: single-task input works for all strategies" {
  for strat in argmax top_k epsilon_greedy softmax pareto_per_task; do
    run bash "$SCRIPT" select --strategy "$strat" --k 1 --input-json "$SINGLE_TASK"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; data=json.load(sys.stdin); assert len(data)==1"
  done
}

# ---------------------------------------------------------------------------
# T-20: pareto_per_task with k=1 returns exactly 1 item
# ---------------------------------------------------------------------------
@test "T-20: pareto_per_task k=1 returns exactly 1 item" {
  run bash "$SCRIPT" select --strategy pareto_per_task --k 1 --input-json "$PARETO_ITEMS"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert len(data) == 1, f'Expected 1, got {len(data)}'
"
}

# ---------------------------------------------------------------------------
# T-21: argmax with single item returns that item
# ---------------------------------------------------------------------------
@test "T-21: argmax with single item returns that item" {
  run bash "$SCRIPT" select --strategy argmax --k 1 --input-json "$SINGLE_ITEM"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert len(data) == 1
assert data[0]['id'] == 'only', f'Expected only, got {data[0][\"id\"]}'
"
}

# ---------------------------------------------------------------------------
# T-22: --input-file works with a temp file
# ---------------------------------------------------------------------------
@test "T-22: --input-file reads from file correctly" {
  TMP=$(mktemp /tmp/fs-test-XXXX.json)
  echo "$HIGH_SCORES" > "$TMP"
  run bash "$SCRIPT" select --strategy argmax --k 1 --input-file "$TMP"
  rm -f "$TMP"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert data[0]['id'] == 'best'
"
}

# ---------------------------------------------------------------------------
# T-23: output contains 'rank' field in each item
# ---------------------------------------------------------------------------
@test "T-23: output items contain rank field" {
  run bash "$SCRIPT" select --strategy top_k --k 2 --input-json "$HIGH_SCORES"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    assert 'rank' in item, f'Missing rank in {item}'
    assert 'reason' in item, f'Missing reason in {item}'
    assert 'id' in item, f'Missing id in {item}'
"
}

# ---------------------------------------------------------------------------
# T-24: softmax k=5 from 5 items returns all 5 distinct items
# ---------------------------------------------------------------------------
@test "T-24: softmax k=n returns all n distinct items" {
  run bash "$SCRIPT" select --strategy softmax --k 5 --temperature 1.0 --input-json "$FIVE_ITEMS"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert len(data) == 5, f'Expected 5, got {len(data)}'
ids = [d['id'] for d in data]
assert len(set(ids)) == 5, f'IDs not distinct: {ids}'
"
}

# ---------------------------------------------------------------------------
# T-25: internal _select_py dispatcher is exercised by all strategies
# ---------------------------------------------------------------------------
@test "T-25: _select_py dispatcher handles all 5 strategies without crash" {
  for strategy in argmax top_k epsilon_greedy softmax pareto_per_task; do
    run bash "$SCRIPT" select --strategy "$strategy" --k 1 --input-json "$THREE_ITEMS"
    [ "$status" -eq 0 ]
    # Output must be valid JSON array (verifies _select_py returned correctly)
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d,list)"
  done
}
