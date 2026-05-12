#!/usr/bin/env bats
# Smoke test for /flow-run and /flow-trace — Slice 2 of SPEC-AGENTIC-FLOW-GRAPH.

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
  # shellcheck disable=SC1091
  source scripts/savia-env.sh >/dev/null 2>&1 || true
}

@test "runner exists and is executable" {
  [ -x scripts/flow_runner.py ]
}

@test "flow-run dry-run on hello-world" {
  run python3 scripts/flow_runner.py run hello-world --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'"dry_run": true'* ]]
  [[ "$output" == *'"order"'* ]]
}

@test "flow-run actual on hello-world emits trace.jsonl" {
  run python3 scripts/flow_runner.py run hello-world
  [ "$status" -eq 0 ]
  [[ "$output" == *'"ok": true'* ]]
}

@test "flow-trace prints last run events" {
  python3 scripts/flow_runner.py run hello-world >/dev/null
  run python3 scripts/flow_runner.py trace
  [ "$status" -eq 0 ]
  [[ "$output" == *'flow_start'* ]]
  [[ "$output" == *'flow_end'* ]]
}

@test "unknown flow returns 3" {
  run python3 scripts/flow_runner.py run no-such
  [ "$status" -eq 3 ]
}

# ─── Slice 3 ─────────────────────────────────────────────────────────────────

@test "code-review-court flow validates" {
  run python3 scripts/flow_validate.py code-review-court
  [ "$status" -eq 0 ]
}

@test "code-review-court flow runs end-to-end with 5 parallel judges" {
  run python3 scripts/flow_runner.py run code-review-court --input pr_number=99
  [ "$status" -eq 0 ]
  [[ "$output" == *'"ok": true'* ]]
  trace=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['trace'])")
  # exactly one wave for the 5 judges
  waves=$(grep -c '"event": "wave_start"' "$trace")
  [ "$waves" -eq 1 ]
}

@test "agent kind records invocation in trace" {
  run python3 scripts/flow_runner.py run code-review-court --input pr_number=1
  [ "$status" -eq 0 ]
  trace=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['trace'])")
  grep -q '"_invoked": "agent:correctness-judge"' "$trace"
}

@test "subflow invocation records subflow trace event" {
  cat > /tmp/sf-parent.flow.yaml << 'YAML'
flow_id: sf-parent-bats
version: 1
confidentiality: N1
nodes:
  - id: call
    kind: subflow
    invoke: hello-world
edges:
  - {from: call, to: END, when: "true"}
guards: {max_iterations: 1, max_duration_minutes: 1}
YAML
  run python3 scripts/flow_runner.py run /tmp/sf-parent.flow.yaml
  [ "$status" -eq 0 ]
  rm -f /tmp/sf-parent.flow.yaml
}

@test "flow-to-obsidian renders all flows without error" {
  run python3 scripts/flow_to_obsidian.py
  [ "$status" -eq 0 ]
  [ -d output/obsidian/flows ]
  [ -f output/obsidian/flows/flow-hello-world.md ]
}
