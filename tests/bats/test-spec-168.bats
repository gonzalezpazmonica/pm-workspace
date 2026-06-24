#!/usr/bin/env bats
# test-spec-168.bats — SPEC-168: Actor Iterative Pre-Action inner loop
#
# Tests:
# 1. script exists and produces JSON
# 2. --max-iterations 1 produces 1 sola iteración
# 3. world-model-simulator.py es llamado (verificar que existe)
# 4. verdict field presente

setup() {
  REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"
  SCRIPT="$REPO_ROOT/scripts/actor-pre-action-loop.py"
  SIMULATOR="$REPO_ROOT/scripts/world-model-simulator.py"
  export SAVIA_ACTOR_PRE_ACTION=on
}

@test "script exists and is executable/runnable" {
  [ -f "$SCRIPT" ]
  python3 "$SCRIPT" --help >/dev/null 2>&1 || true
  # Validate it's syntactically valid Python
  python3 -c "import ast; ast.parse(open('$SCRIPT').read())"
}

@test "script produces valid JSON output with all required fields" {
  output=$(SAVIA_ACTOR_PRE_ACTION=on python3 "$SCRIPT" \
    --action "read config.json" \
    --context "inspect settings" \
    --max-iterations 3 \
    --confidence-threshold 0.7 \
    --quiet 2>/dev/null)
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'approved_action' in d, 'missing approved_action'
assert 'final_confidence' in d, 'missing final_confidence'
assert 'iterations' in d, 'missing iterations'
assert 'simulation_history' in d, 'missing simulation_history'
assert 'verdict' in d, 'missing verdict'
"
}

@test "--max-iterations 1 produces exactly 1 iteration in history" {
  output=$(SAVIA_ACTOR_PRE_ACTION=on python3 "$SCRIPT" \
    --action "edit README.md" \
    --context "update docs" \
    --max-iterations 1 \
    --confidence-threshold 0.99 \
    --quiet 2>/dev/null)
  count=$(echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(len(d['simulation_history']))
")
  [ "$count" -eq 1 ]
}

@test "world-model-simulator.py exists (dependency check)" {
  [ -f "$SIMULATOR" ]
}

@test "verdict field is present and has valid value" {
  output=$(SAVIA_ACTOR_PRE_ACTION=on python3 "$SCRIPT" \
    --action "read logs" \
    --context "debug" \
    --max-iterations 2 \
    --confidence-threshold 0.5 \
    --quiet 2>/dev/null)
  verdict=$(echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d['verdict'])
")
  [[ "$verdict" == "approved" || "$verdict" == "best_effort" || "$verdict" == "blocked" ]]
}

@test "master switch off returns action without simulation (0 iterations)" {
  output=$(SAVIA_ACTOR_PRE_ACTION=off python3 "$SCRIPT" \
    --action "delete old logs" \
    --context "cleanup" \
    --quiet 2>/dev/null)
  iterations=$(echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d['iterations'])
")
  [ "$iterations" -eq 0 ]
}
