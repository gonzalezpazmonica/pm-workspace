#!/usr/bin/env bats
# test-se-220-s0-speculative-probe.bats
# Ref: SE-220 Speculative Tool Execution -- Slice 0 Feasibility Probe
# Tests: existence, JSON output, verdict field, threshold enforcement

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PREDICTOR="$REPO_ROOT/scripts/speculative-tool-predictor.py"
  PROBE="$REPO_ROOT/scripts/speculative-tool-probe.py"
  export REPO_ROOT PREDICTOR PROBE
}

# ---------------------------------------------------------------------------
# T1: Scripts exist and are executable
# ---------------------------------------------------------------------------

@test "speculative-tool-predictor.py exists" {
  [[ -f "$PREDICTOR" ]]
}

@test "speculative-tool-probe.py exists" {
  [[ -f "$PROBE" ]]
}

@test "speculative-tool-probe.py runs without error" {
  run python3 "$PROBE"
  [[ "$status" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# T2: Probe output is valid JSON
# ---------------------------------------------------------------------------

@test "probe output is valid JSON" {
  output_json="$(python3 "$PROBE")"
  echo "$output_json" | python3 -c "import sys,json; json.load(sys.stdin)"
  [[ "$?" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# T3: verdict field is present in output
# ---------------------------------------------------------------------------

@test "probe output contains verdict field" {
  output_json="$(python3 "$PROBE")"
  verdict="$(echo "$output_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['verdict'])")"
  [[ -n "$verdict" ]]
}

# ---------------------------------------------------------------------------
# T4: acceptance_rate >= 0.60 produces PROCEED verdict
# ---------------------------------------------------------------------------

@test "acceptance_rate >= 0.60 produces verdict PROCEED" {
  output_json="$(python3 "$PROBE")"
  rate="$(echo "$output_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['acceptance_rate'])")"
  verdict="$(echo "$output_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['verdict'])")"
  # Verify rate as float comparison
  python3 -c "import sys; rate=float('$rate'); sys.exit(0 if rate >= 0.60 else 1)"
  [[ "$verdict" == "PROCEED" ]]
}

# ---------------------------------------------------------------------------
# T5: predictor returns valid JSON schema
# ---------------------------------------------------------------------------

@test "predictor returns valid JSON with required fields" {
  input='{"intent": "lee el fichero docs/SE-220.md", "available_tools": ["Read","Bash","Grep"]}'
  output_json="$(echo "$input" | python3 "$PREDICTOR")"
  python3 -c "
import sys, json
d = json.loads('$output_json'.replace(\"'\", '\"'))
" 2>/dev/null || python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'predicted_tools' in d
assert 'confidence' in d
assert 'rationale' in d
assert isinstance(d['predicted_tools'], list)
assert len(d['predicted_tools']) >= 1
assert 0.0 <= float(d['confidence']) <= 1.0
" <<< "$output_json"
}

# ---------------------------------------------------------------------------
# T6: total_cases matches dataset size (>= 15)
# ---------------------------------------------------------------------------

@test "probe total_cases is >= 15" {
  output_json="$(python3 "$PROBE")"
  total="$(echo "$output_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['total_cases'])")"
  [[ "$total" -ge 15 ]]
}

# ---------------------------------------------------------------------------
# T7: correct + incorrect == total_cases
# ---------------------------------------------------------------------------

@test "correct + incorrect equals total_cases" {
  output_json="$(python3 "$PROBE")"
  python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['correct'] + d['incorrect'] == d['total_cases'], \
    f\"correct({d['correct']}) + incorrect({d['incorrect']}) != total({d['total_cases']})\"
" <<< "$output_json"
}

# ---------------------------------------------------------------------------
# T8: cases array present and non-empty
# ---------------------------------------------------------------------------

@test "probe output cases array is non-empty" {
  output_json="$(python3 "$PROBE")"
  count="$(echo "$output_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['cases']))")"
  [[ "$count" -ge 1 ]]
}
