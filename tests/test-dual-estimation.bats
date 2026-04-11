#!/usr/bin/env bats
# BATS tests for SE-013 dual estimation rule
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-013-dual-estimation.md
# Ref: .claude/rules/domain/dual-estimation.md
# Quality gate: SPEC-055 (audit score ≥80)
# Safety: tests use BATS run/status guards; target script has set -uo pipefail

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/estimate-calibrate.sh"
  export RULE="$REPO_ROOT/.claude/rules/domain/dual-estimation.md"
  export TEMPLATE="$REPO_ROOT/docs/propuestas/TEMPLATE.md"
  export EXAMPLE="$REPO_ROOT/data/agent-actuals.example.jsonl"
  TMPDIR_DE=$(mktemp -d)
  export TMPDIR_DE
}

teardown() {
  rm -rf "$TMPDIR_DE"
}

@test "rule file exists at expected path" {
  [ -f "$RULE" ]
}

@test "rule file is 150 lines or fewer" {
  run bash -c "wc -l < '$RULE'"
  [ "$status" -eq 0 ]
  [ "$output" -le 150 ]
}

@test "rule headline mentions 10x multiplier" {
  grep -q "10x" "$RULE"
}

@test "rule contains all five adjustment categories" {
  grep -q "Trivial" "$RULE"
  grep -q "Standard" "$RULE"
  grep -q "Complex" "$RULE"
  grep -q "Novel" "$RULE"
  grep -q "Legacy" "$RULE"
}

@test "rule cites METR sources" {
  grep -q "METR" "$RULE"
  grep -q "2503.14499" "$RULE"
}

@test "template has dual estimate fields (human + agent)" {
  grep -q "Estimate (human)" "$TEMPLATE"
  grep -q "Estimate (agent)" "$TEMPLATE"
}

@test "template references the dual-estimation rule" {
  grep -q "dual-estimation.md" "$TEMPLATE"
}

@test "target script has safety flags set" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "calibration script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "script runs successfully with seeded example data" {
  local log="$TMPDIR_DE/actuals.jsonl"
  cp "$EXAMPLE" "$log"
  run bash "$SCRIPT" --log "$log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dual Estimation Calibration Report"* ]]
  [[ "$output" == *"Global pipeline speedup"* ]]
}

@test "script handles empty or missing log gracefully" {
  run bash "$SCRIPT" --log "$TMPDIR_DE/nonexistent.jsonl"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No samples"* ]]
}

@test "script skips malformed JSONL line with warning and continues" {
  local log="$TMPDIR_DE/malformed.jsonl"
  {
    echo '{"spec_id":"A","category":"standard","human_estimate_days":1,"agent_wallclock_hours_actual":0.5}'
    echo 'this is not json at all'
    echo '{"spec_id":"B","category":"standard","human_estimate_days":2,"agent_wallclock_hours_actual":1.0}'
  } > "$log"
  run bash "$SCRIPT" --log "$log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Samples: 2"* ]]
}

@test "--format json produces valid parseable JSON" {
  local log="$TMPDIR_DE/actuals.jsonl"
  cp "$EXAMPLE" "$log"
  run bash "$SCRIPT" --log "$log" --format json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'samples' in d; assert 'categories' in d; assert 'global_speedup' in d"
}

@test "global pipeline speedup matches known fixed input" {
  # 3 entries, all standard. human_days: 1+2+3 = 6d = 48h.
  # agent_hours: 2+2+2 = 6h. Speedup = 48/6 = 8x.
  local log="$TMPDIR_DE/fixed.jsonl"
  {
    echo '{"spec_id":"F1","category":"standard","human_estimate_days":1,"agent_wallclock_hours_actual":2.0}'
    echo '{"spec_id":"F2","category":"standard","human_estimate_days":2,"agent_wallclock_hours_actual":2.0}'
    echo '{"spec_id":"F3","category":"standard","human_estimate_days":3,"agent_wallclock_hours_actual":2.0}'
  } > "$log"
  run bash "$SCRIPT" --log "$log" --format json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); g=d['global_speedup']; assert abs(g - 8.0) < 0.01, f'expected 8.0, got {g}'"
}

@test "example seed file exists with valid JSONL and at least 4 entries" {
  [ -f "$EXAMPLE" ]
  run bash -c "wc -l < '$EXAMPLE'"
  [ "$status" -eq 0 ]
  [ "$output" -ge 4 ]
  # Validate every line is JSON
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "$line" | python3 -c "import sys,json; json.loads(sys.stdin.read())"
  done < "$EXAMPLE"
}

@test "script fails with error on unknown argument" {
  run bash "$SCRIPT" --nonsense-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "script output includes adjustment suggestion for well-sampled category" {
  local log="$TMPDIR_DE/many.jsonl"
  # 11 samples of standard: human_days=1, agent_h=0.1 → speedup 80x
  for i in $(seq 1 11); do
    echo "{\"spec_id\":\"S$i\",\"category\":\"standard\",\"human_estimate_days\":1,\"agent_wallclock_hours_actual\":0.1}"
  done > "$log"
  run bash "$SCRIPT" --log "$log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"suggest"* ]]
}

# ── estimate-convert.sh two-ratio helper ────────────────────────────────────

@test "estimate-convert exists and is executable" {
  local cv="$REPO_ROOT/scripts/estimate-convert.sh"
  [ -x "$cv" ]
}

@test "estimate-convert conservative mode computes 4h for 5 standard days" {
  local cv="$REPO_ROOT/scripts/estimate-convert.sh"
  run bash "$cv" 5 --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"agent_hours":4.00'* ]]
  [[ "$output" == *'"mode":"conservative"'* ]]
}

@test "estimate-convert applies category factor for trivial" {
  local cv="$REPO_ROOT/scripts/estimate-convert.sh"
  run bash "$cv" 5 --category trivial --format json
  [ "$status" -eq 0 ]
  # 5 × 0.533 = 2.665 ≈ 2.67
  [[ "$output" == *'"agent_hours":2.67'* ]]
}

@test "estimate-convert empirical falls back when samples insufficient" {
  local cv="$REPO_ROOT/scripts/estimate-convert.sh"
  run bash "$cv" 5 --mode empirical --min-samples 100 --format json
  [ "$status" -eq 2 ]
  [[ "$output" == *'"fell_back":1'* ]]
  [[ "$output" == *'"mode":"conservative"'* ]]
}

@test "estimate-convert rejects invalid category" {
  local cv="$REPO_ROOT/scripts/estimate-convert.sh"
  run bash "$cv" 5 --category nonsense
  [ "$status" -eq 1 ]
}

@test "estimate-convert rejects non-numeric human days" {
  local cv="$REPO_ROOT/scripts/estimate-convert.sh"
  run bash "$cv" abc
  [ "$status" -eq 1 ]
}
