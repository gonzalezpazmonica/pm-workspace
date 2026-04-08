#!/usr/bin/env bats
# Tests for heat-scheduler.sh — Lightweight heat-based parallelism
# Ref: docs/propuestas/SPEC-094-heat-based-parallelism.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/heat-scheduler.sh"
  TMPDIR_HS=$(mktemp -d)

  # Create standard test fixture
  cat > "$TMPDIR_HS/slices-basic.json" <<'EOF'
{
  "slices": [
    {"id": 1, "name": "Domain entities", "phase": 1, "heat": "core", "files": ["Sala.cs"]},
    {"id": 2, "name": "Repository", "phase": 1, "heat": "data", "files": ["SalaRepo.cs"]},
    {"id": 3, "name": "Controller", "phase": 2, "heat": "api", "files": ["SalaCtrl.cs"]},
    {"id": 4, "name": "Unit tests", "phase": 3, "heat": "test-unit", "files": ["SalaTests.cs"]},
    {"id": 5, "name": "Integration tests", "phase": 3, "heat": "test-int", "files": ["SalaIntTests.cs"]}
  ]
}
EOF

  # Fixture with file conflict
  cat > "$TMPDIR_HS/slices-conflict.json" <<'EOF'
{
  "slices": [
    {"id": 1, "name": "Service A", "phase": 1, "heat": "a", "files": ["Shared.cs", "A.cs"]},
    {"id": 2, "name": "Service B", "phase": 1, "heat": "b", "files": ["Shared.cs", "B.cs"]}
  ]
}
EOF

  # Fixture without heats (serial mode)
  cat > "$TMPDIR_HS/slices-serial.json" <<'EOF'
{
  "slices": [
    {"id": 1, "name": "Step 1", "phase": 1, "files": ["A.cs"]},
    {"id": 2, "name": "Step 2", "phase": 2, "files": ["B.cs"]},
    {"id": 3, "name": "Step 3", "phase": 3, "files": ["C.cs"]}
  ]
}
EOF

  # Single slice
  cat > "$TMPDIR_HS/slices-single.json" <<'EOF'
{
  "slices": [
    {"id": 1, "name": "Only one", "phase": 1, "heat": "solo", "files": ["Only.cs"]}
  ]
}
EOF
}

teardown() {
  rm -rf "$TMPDIR_HS"
}

# ── 1. Script existence and structure ────────────────────────────────────────

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "script has safety flags (set -uo pipefail)" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "script shows usage without arguments" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

# ── 2. Plan generation ───────────────────────────────────────────────────────

@test "plan generates valid JSON" {
  run bash "$SCRIPT" plan "$TMPDIR_HS/slices-basic.json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "plan creates 3 waves from 5 slices in 3 phases" {
  run bash "$SCRIPT" plan "$TMPDIR_HS/slices-basic.json"
  [ "$status" -eq 0 ]
  local total_waves
  total_waves=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['total_waves'])")
  [ "$total_waves" -eq 3 ]
}

@test "plan detects max_parallel=2 in basic fixture" {
  run bash "$SCRIPT" plan "$TMPDIR_HS/slices-basic.json"
  [ "$status" -eq 0 ]
  local max_par
  max_par=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['max_parallel'])")
  [ "$max_par" -eq 2 ]
}

@test "plan wave 1 has 2 parallel tasks (phase 1)" {
  run bash "$SCRIPT" plan "$TMPDIR_HS/slices-basic.json"
  [ "$status" -eq 0 ]
  local wave1_count
  wave1_count=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['waves'][0]['tasks']))")
  [ "$wave1_count" -eq 2 ]
}

@test "plan includes speedup estimate" {
  run bash "$SCRIPT" plan "$TMPDIR_HS/slices-basic.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"speedup_estimate"* ]]
}

# ── 3. Serial mode (no heats) ───────────────────────────────────────────────

@test "plan without heats creates 1 task per wave (serial)" {
  run bash "$SCRIPT" plan "$TMPDIR_HS/slices-serial.json"
  [ "$status" -eq 0 ]
  local max_par
  max_par=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['max_parallel'])")
  [ "$max_par" -eq 1 ]
}

@test "plan without heats creates N waves for N slices" {
  run bash "$SCRIPT" plan "$TMPDIR_HS/slices-serial.json"
  [ "$status" -eq 0 ]
  local total
  total=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['total_waves'])")
  [ "$total" -eq 3 ]
}

# ── 4. Conflict detection ────────────────────────────────────────────────────

@test "plan fails on file conflict between heats" {
  run bash "$SCRIPT" plan "$TMPDIR_HS/slices-conflict.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"conflict"* ]] || [[ "$output" == *"Shared.cs"* ]]
}

@test "validate passes on clean slices" {
  run bash "$SCRIPT" validate "$TMPDIR_HS/slices-basic.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No file conflicts"* ]]
}

@test "validate fails on conflicting slices" {
  run bash "$SCRIPT" validate "$TMPDIR_HS/slices-conflict.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CONFLICT"* ]]
}

@test "conflicts subcommand returns JSON with conflict details" {
  run bash "$SCRIPT" conflicts "$TMPDIR_HS/slices-conflict.json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['count'] > 0"
}

# ── 5. Edge cases ────────────────────────────────────────────────────────────

@test "plan handles single slice" {
  run bash "$SCRIPT" plan "$TMPDIR_HS/slices-single.json"
  [ "$status" -eq 0 ]
  local total
  total=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['total_waves'])")
  [ "$total" -eq 1 ]
}

@test "plan fails on missing file" {
  run bash "$SCRIPT" plan "$TMPDIR_HS/nonexistent.json"
  [ "$status" -eq 1 ]
}

@test "unknown command shows error" {
  run bash "$SCRIPT" foobar
  [ "$status" -eq 1 ]
}
