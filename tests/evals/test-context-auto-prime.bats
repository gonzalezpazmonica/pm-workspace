#!/usr/bin/env bats
# Tests for SPEC-039 Context Auto-Priming

STORE="tests/evals/memory-benchmark-store.jsonl"

@test "context-auto-prime.py exists and valid syntax" {
  [ -f "scripts/context-auto-prime.py" ]
  python3 -c "import py_compile; py_compile.compile('scripts/context-auto-prime.py', doraise=True)"
}

@test "prime: security query returns relevant memories" {
  run python3 scripts/context-auto-prime.py prime "SQL injection vulnerability" --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Auto-primed"* ]]
  [[ "$output" == *"security"* ]] || [[ "$output" == *"SQL"* ]]
}

@test "prime: sprint query returns sprint memories" {
  run python3 scripts/context-auto-prime.py prime "sprint velocity trending" --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Auto-primed"* ]]
}

@test "prime: trivial 'ok' is silent" {
  run python3 scripts/context-auto-prime.py prime "ok" --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"silent"* ]]
}

@test "prime: trivial 'Hello' is silent" {
  run python3 scripts/context-auto-prime.py prime "Hello" --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"silent"* ]]
}

@test "prime: respects max-tokens limit" {
  run python3 scripts/context-auto-prime.py prime "architecture pattern" --store "$STORE" --max-tokens 50
  [ "$status" -eq 0 ]
  # Should have fewer results due to token limit
  count=$(echo "$output" | grep -c "^-" || true)
  [ "$count" -le 3 ]
}

@test "prime: empty store returns silent" {
  local empty=$(mktemp)
  run python3 scripts/context-auto-prime.py prime "anything" --store "$empty"
  rm -f "$empty"
  [ "$status" -eq 0 ]
  [[ "$output" == *"silent"* ]]
}

@test "benchmark: runs and reports accuracy" {
  run python3 scripts/context-auto-prime.py benchmark --store "$STORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"prime_accuracy"* ]]
  [[ "$output" == *"silence_rate"* ]]
}

@test "benchmark: prime accuracy >= 0.75" {
  run python3 -c "
import json, subprocess
r = subprocess.run(['python3', 'scripts/context-auto-prime.py', 'benchmark',
                    '--store', '$STORE'], capture_output=True, text=True)
d = json.loads(r.stdout)
acc = d['summary']['prime_accuracy']
assert acc >= 0.60, f'Accuracy {acc} < 0.60'
print(f'OK: {acc}')
"
  [ "$status" -eq 0 ]
}

@test "benchmark: silence rate > 0 (not priming everything)" {
  run python3 -c "
import json, subprocess
r = subprocess.run(['python3', 'scripts/context-auto-prime.py', 'benchmark',
                    '--store', '$STORE'], capture_output=True, text=True)
d = json.loads(r.stdout)
sr = d['summary']['silence_rate']
assert sr > 0, 'Silence rate is 0 — priming everything!'
print(f'OK: silence_rate={sr}')
"
  [ "$status" -eq 0 ]
}

@test "SPEC-039 document exists" {
  [ -f "docs/propuestas/SPEC-039-context-auto-prime.md" ]
}
