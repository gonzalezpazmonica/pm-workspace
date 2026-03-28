#!/usr/bin/env bats

setup() {
  export SCRIPT="scripts/wave-executor.sh"
  export FIXTURES="tests/fixtures"
}

@test "happy path: 3 tasks 2 waves all succeed" {
  run bash "$SCRIPT" "$FIXTURES/wave-dag-happy.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.status == "success"'
  echo "$output" | jq -e '.total_waves == 2'
  echo "$output" | jq -e '.total_tasks == 3'
}

@test "diamond dependency: A->B,C->D = 3 waves" {
  run bash "$SCRIPT" "$FIXTURES/wave-dag-diamond.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.total_waves == 3'
  echo "$output" | jq -e '.waves[0].tasks[0].id == "A"'
}

@test "empty task graph succeeds with 0 waves" {
  run bash "$SCRIPT" "$FIXTURES/wave-dag-empty.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.status == "success"'
  echo "$output" | jq -e '.total_waves == 0'
}

@test "cycle detected exits 2" {
  run bash "$SCRIPT" "$FIXTURES/wave-dag-cycle.json"
  [ "$status" -eq 2 ]
}

@test "missing dependency exits 2" {
  local tmp=$(mktemp)
  echo '{"tasks":[{"id":"test","command":"echo t","depends_on":["compile"]}]}' > "$tmp"
  run bash "$SCRIPT" "$tmp"
  [ "$status" -eq 2 ]
  rm -f "$tmp"
}

@test "duplicate task ID exits 2" {
  local tmp=$(mktemp)
  echo '{"tasks":[{"id":"build","command":"echo 1","depends_on":[]},{"id":"build","command":"echo 2","depends_on":[]}]}' > "$tmp"
  run bash "$SCRIPT" "$tmp"
  [ "$status" -eq 2 ]
  rm -f "$tmp"
}

@test "task fails mid-wave exits 1" {
  local tmp=$(mktemp)
  echo '{"tasks":[{"id":"good","command":"true","depends_on":[]},{"id":"bad","command":"false","depends_on":[]}]}' > "$tmp"
  run bash "$SCRIPT" "$tmp"
  [ "$status" -eq 1 ]
  echo "$output" | jq -e '.status == "failed"'
  rm -f "$tmp"
}

@test "overflow splits into sub-waves" {
  run bash "$SCRIPT" "$FIXTURES/wave-dag-overflow.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.total_waves == 2'
}

@test "missing expected file fails task" {
  local tmp=$(mktemp)
  echo '{"tasks":[{"id":"gen","command":"true","depends_on":[],"expected_files":["/tmp/nonexistent-wave-test-file.xyz"]}]}' > "$tmp"
  run bash "$SCRIPT" "$tmp"
  [ "$status" -eq 1 ]
  echo "$output" | jq -e '.waves[0].tasks[0].expected_files_present == false'
  rm -f "$tmp"
}

@test "report flag writes to file" {
  local rpt=$(mktemp)
  run bash "$SCRIPT" "$FIXTURES/wave-dag-happy.json" --report "$rpt"
  [ "$status" -eq 0 ]
  jq -e '.status == "success"' "$rpt"
  rm -f "$rpt"
}

@test "no arguments exits 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "nonexistent file exits 2" {
  run bash "$SCRIPT" "/tmp/no-such-file-wave.json"
  [ "$status" -eq 2 ]
}
