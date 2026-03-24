#!/usr/bin/env bats
# Tests for Context Prefetch Cache (SPEC-040 EXP-02 production)

@test "context-prefetch.py valid syntax" {
  python3 -c "import py_compile; py_compile.compile('scripts/context-prefetch.py', doraise=True)"
}

@test "predict: sprint-status -> team-workload" {
  run python3 scripts/context-prefetch.py predict "sprint-status"
  [ "$status" -eq 0 ]
  [[ "$output" == *"team-workload"* ]]
  [[ "$output" == *"prefetch_domain"* ]]
}

@test "predict: pr-pending returns multiple candidates" {
  run python3 scripts/context-prefetch.py predict "pr-pending"
  [ "$status" -eq 0 ]
  [[ "$output" == *"spec-status"* ]]
  [[ "$output" == *"security-alerts"* ]]
}

@test "predict: unknown command returns empty" {
  run python3 scripts/context-prefetch.py predict "nonexistent-cmd"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"predicted": []'* ]]
}

@test "benchmark: top-3 accuracy >= 0.90" {
  run python3 -c "
import json, subprocess
r = subprocess.run(['python3','scripts/context-prefetch.py','benchmark'],
                   capture_output=True, text=True)
d = json.loads(r.stdout)
assert d['top3'] >= 0.90, f'Top-3 {d[\"top3\"]} < 0.90'
print(f'OK: top1={d[\"top1\"]}, top3={d[\"top3\"]}')
"
  [ "$status" -eq 0 ]
}

@test "benchmark: model has >= 15 commands" {
  run python3 -c "
import json, subprocess
r = subprocess.run(['python3','scripts/context-prefetch.py','benchmark'],
                   capture_output=True, text=True)
d = json.loads(r.stdout)
assert d['model_size'] >= 15, f'Only {d[\"model_size\"]} commands'
print(f'OK: {d[\"model_size\"]} commands')
"
  [ "$status" -eq 0 ]
}

@test "access: logs access and creates log file" {
  local log="output/.memory-access-log.jsonl"
  rm -f "$log"
  run python3 scripts/context-prefetch.py access "test/topic-key"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Access logged"* ]]
  [ -f "$log" ]
  grep -q "test/topic-key" "$log"
  rm -f "$log"
}

@test "train: builds and saves model" {
  run python3 scripts/context-prefetch.py train
  [ "$status" -eq 0 ]
  [[ "$output" == *"Model trained"* ]]
  [ -f "output/.prefetch-transitions.json" ]
  rm -f "output/.prefetch-transitions.json"
}
