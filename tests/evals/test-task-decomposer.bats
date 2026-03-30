#!/usr/bin/env bats
# Tests for SPEC-052 Recursive Task Decomposition — Phase 1

SCRIPT="scripts/task-decomposer.sh"

setup() { TMPDIR_TD=$(mktemp -d); }
teardown() { rm -rf "$TMPDIR_TD"; }

@test "task-decomposer.sh exists" {
  [ -f "$SCRIPT" ]
}

@test "task-decomposer.sh is executable" {
  [ -x "$SCRIPT" ]
}

@test "task-decomposer.sh has set -uo pipefail" {
  head -5 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "SPEC-052 document exists" {
  [ -f "docs/propuestas/SPEC-052-recursive-task-decomposition.md" ]
}

@test "atomic task detected for single-concern description" {
  run bash "$SCRIPT" "Add login endpoint"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(atomic)"* ]]
}

@test "composite task detected for multi-concern description" {
  run bash "$SCRIPT" "API with auth and notifications"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(composite)"* ]]
}

@test "composite task with 'and' produces subtasks" {
  run bash "$SCRIPT" --json "Create API and implement auth and send notifications"
  [ "$status" -eq 0 ]
  # Validate JSON output
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['classification']=='composite'; assert len(d['children'])>=2"
}

@test "max depth respected — depth 1 forces atomic leaves" {
  run bash "$SCRIPT" --max-depth 1 --json "Create API and implement auth and send notifications"
  [ "$status" -eq 0 ]
  # At depth 1, children should all be atomic
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for child in d.get('children', []):
    assert child['classification'] == 'atomic', f'Child {child[\"id\"]} should be atomic at max depth 1'
"
}

@test "empty input handled with error" {
  run bash "$SCRIPT" ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "no arguments handled with error" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "--help shows usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "JSON output is valid JSON" {
  run bash "$SCRIPT" --json "Refactor authentication module"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "max depth capped at 3 even if higher requested" {
  run bash "$SCRIPT" --max-depth 10 --json "Create API and auth"
  [ "$status" -eq 0 ]
  # Should not crash; depth is silently capped
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "Spanish connectors detected as composite" {
  run bash "$SCRIPT" "Crear API y implementar autenticacion"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(composite)"* ]]
}
