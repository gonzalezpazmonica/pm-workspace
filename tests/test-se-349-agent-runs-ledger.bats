#!/usr/bin/env bats
# tests/test-se-349-agent-runs-ledger.bats — SE-349: Agent Runs Operations Ledger (ARO)
# Ref: docs/specs/SE-349-agent-runs-ledger.spec.md
# Safety: set -uo pipefail applied per-test in setup().
#
# Coverage notes:
#   Exercises the public command surface of scripts/savia-runs.sh:
#     init, start, state, pr, finish, status, list, show, reset
#   Verifies the core AO lesson: display status is DERIVED at read time,
#   never stored (assertions on derived_status vs absence of a stored status
#   field), and the termination guardrail ("owned PR keeps the run alive").

ARO="${BATS_TEST_DIRNAME}/../scripts/savia-runs.sh"

setup() {
  set -uo pipefail
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export SAVIA_WORKSPACE_DIR="$TMP_DIR"
  export SAVIA_RUNS_LEDGER="$TMP_DIR/data/agent-runs-ledger.jsonl"
  mkdir -p "$TMP_DIR/data"
  touch "$SAVIA_RUNS_LEDGER"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# helper: run_id of the first (and only) ledger record
first_run_id() {
  python3 -c 'import sys,json;print(json.loads(open(sys.argv[1]).readline())["run_id"])' "$SAVIA_RUNS_LEDGER"
}

# helper: parse a JSON field from a record line (by run_id)
field() {
  local run_id="$1" key="$2"
  python3 - "$SAVIA_RUNS_LEDGER" "$run_id" "$key" <<'PY'
import sys, json
for line in open(sys.argv[1]):
    line = line.strip()
    if not line: continue
    try: r = json.loads(line)
    except Exception: continue
    if r.get("run_id") == sys.argv[2]:
        print(r.get(sys.argv[3]))
        break
PY
}

# ── init ─────────────────────────────────────────────────────────────────
@test "init: creates the ledger file and echoes its path" {
  run bash "$ARO" init
  [ "$status" -eq 0 ]
  [[ "$output" == "ledger=$SAVIA_RUNS_LEDGER" ]]
  [ -f "$SAVIA_RUNS_LEDGER" ]
}

# ── start ────────────────────────────────────────────────────────────────
@test "start: prints a run_id and writes a JSONL entry" {
  run bash "$ARO" start overnight dev-orchestrator "smoke task"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  RUN_ID="$output"
  [ "$(field "$RUN_ID" run_id)" = "$RUN_ID" ]
}

@test "start: record is schema v1, spawning, not terminated, pr null" {
  RUN_ID="$(bash "$ARO" start improve test-engineer "add tests")"
  [ "$(field "$RUN_ID" schema_version)" = "1" ]
  [ "$(field "$RUN_ID" activity_state)" = "spawning" ]
  [ "$(field "$RUN_ID" is_terminated)" = "False" ]
  [ "$(field "$RUN_ID" pr)" = "None" ]
  [ "$(field "$RUN_ID" mode)" = "improve" ]
  [ "$(field "$RUN_ID" agent)" = "test-engineer" ]
}

@test "start: --project and --branch are persisted" {
  RUN_ID="$(bash "$ARO" start overnight dev-orchestrator "task" --project proyecto-alpha --branch agent/overnight-20260829-lint)"
  [ "$(field "$RUN_ID" project)" = "proyecto-alpha" ]
  [ "$(field "$RUN_ID" branch)" = "agent/overnight-20260829-lint" ]
}

@test "start: rejects an invalid mode" {
  run bash "$ARO" start bogus-mode dev-orchestrator "task"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid mode"* ]]
}

# ── state ────────────────────────────────────────────────────────────────
@test "state: updates activity_state on existing run" {
  RUN_ID="$(bash "$ARO" start overnight dev-orchestrator "task")"
  run bash "$ARO" state "$RUN_ID" active
  [ "$status" -eq 0 ]
  [ "$(field "$RUN_ID" activity_state)" = "active" ]
}

@test "state: rejects an invalid activity_state" {
  RUN_ID="$(bash "$ARO" start overnight dev-orchestrator "task")"
  run bash "$ARO" state "$RUN_ID" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid activity_state"* ]]
}

@test "state: fails on unknown run_id" {
  run bash "$ARO" state deadbeef-0000-0000-0000-000000000000 active
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

# ── pr ───────────────────────────────────────────────────────────────────
@test "pr: attaches PR facts (state/ci/review/mergeable)" {
  RUN_ID="$(bash "$ARO" start overnight dev-orchestrator "task")"
  run bash "$ARO" pr "$RUN_ID" 1009 --state open --ci failing --review requested --mergeable true
  [ "$status" -eq 0 ]
  [ "$(field "$RUN_ID" pr)" = "{'number': 1009, 'state': 'open', 'ci': 'failing', 'review': 'requested', 'mergeable': 'true', 'url': None}" ]
}

@test "pr: clear disowns the PR" {
  RUN_ID="$(bash "$ARO" start overnight dev-orchestrator "task")"
  bash "$ARO" pr "$RUN_ID" 1009 --state open >/dev/null
  [ -n "$(field "$RUN_ID" pr)" ]
  run bash "$ARO" pr "$RUN_ID" clear
  [ "$status" -eq 0 ]
  [ "$(field "$RUN_ID" pr)" = "None" ]
}

@test "pr: rejects an invalid ci value" {
  RUN_ID="$(bash "$ARO" start overnight dev-orchestrator "task")"
  run bash "$ARO" pr "$RUN_ID" 1009 --ci orange
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid ci"* ]]
}

# ── finish (guardrail) ───────────────────────────────────────────────────
@test "finish: terminates a run without PR (is_terminated, ended_at)" {
  RUN_ID="$(bash "$ARO" start improve security-guardian "scan")"
  run bash "$ARO" finish "$RUN_ID"
  [ "$status" -eq 0 ]
  [ "$(field "$RUN_ID" is_terminated)" = "True" ]
  [ -n "$(field "$RUN_ID" ended_at)" ]
}

@test "finish: BLOCKS a run that owns a live PR (AO guardrail)" {
  RUN_ID="$(bash "$ARO" start overnight dev-orchestrator "task")"
  bash "$ARO" pr "$RUN_ID" 1009 --state open --ci failing >/dev/null
  run bash "$ARO" finish "$RUN_ID"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BLOCKED"* ]]
  # guardrail holds: record is NOT terminated
  [ "$(field "$RUN_ID" is_terminated)" = "False" ]
}

@test "finish: --force bypasses the guardrail" {
  RUN_ID="$(bash "$ARO" start overnight dev-orchestrator "task")"
  bash "$ARO" pr "$RUN_ID" 1009 --state open >/dev/null
  run bash "$ARO" finish "$RUN_ID" --force
  [ "$status" -eq 0 ]
  [ "$(field "$RUN_ID" is_terminated)" = "True" ]
}

@test "finish: is idempotent on an already-terminated run" {
  RUN_ID="$(bash "$ARO" start improve test-engineer "x")"
  bash "$ARO" finish "$RUN_ID" >/dev/null
  run bash "$ARO" finish "$RUN_ID"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already terminated"* ]]
}

# ── derived status (read-time, never stored) ─────────────────────────────
@test "derivation: merged run derives to merged even when terminated" {
  RUN_ID="$(bash "$ARO" start improve test-engineer "x")"
  bash "$ARO" pr "$RUN_ID" 1001 --state merged >/dev/null
  bash "$ARO" finish "$RUN_ID" >/dev/null
  bash "$ARO" status --json > "$TMP_DIR/status.json"
  python3 - "$TMP_DIR/status.json" "$RUN_ID" "$SAVIA_RUNS_LEDGER" <<'PY'
import sys, json
d = json.load(open(sys.argv[1]))
r = [x for x in d["runs"] if x["run_id"] == sys.argv[2]][0]
assert r["derived_status"] == "merged", r["derived_status"]
raw = open(sys.argv[3]).read()
assert "derived_status" not in raw, "display status must never be stored"
PY
}

@test "derivation: needs_input for waiting_input, ci_failed for failing ci" {
  R1="$(bash "$ARO" start overnight dev-orchestrator "a")"
  bash "$ARO" state "$R1" waiting_input >/dev/null
  R2="$(bash "$ARO" start overnight dev-orchestrator "b")"
  bash "$ARO" pr "$R2" 1002 --state open --ci failing >/dev/null
  bash "$ARO" status --json > "$TMP_DIR/status.json"
  python3 - "$TMP_DIR/status.json" "$R1" "$R2" <<'PY'
import sys, json
d = json.load(open(sys.argv[1]))
m = {x["run_id"]: x["derived_status"] for x in d["runs"]}
assert m[sys.argv[2]] == "needs_input", m
assert m[sys.argv[3]] == "ci_failed", m
PY
}

# ── status / list / show / reset ─────────────────────────────────────────
@test "status: board renders columns with counts" {
  RUN_ID="$(bash "$ARO" start overnight dev-orchestrator "task")"
  bash "$ARO" pr "$RUN_ID" 1003 --state draft >/dev/null
  run bash "$ARO" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"IN REVIEW"* ]]
  [[ "$output" == *"IN REVIEW (1)"* ]]
}

@test "list: shows derived status and --mode filters" {
  R1="$(bash "$ARO" start overnight dev-orchestrator "a")"
  R2="$(bash "$ARO" start improve test-engineer "b")"
  bash "$ARO" pr "$R2" 1004 --state open --ci passing --review approved >/dev/null
  run bash "$ARO" list --json
  [ "$status" -eq 0 ]
  python3 - "$output" "$R1" "$R2" <<'PY'
import sys, json
rows = json.loads(sys.argv[1])
assert len(rows) == 2
m = {r["run_id"]: r["derived_status"] for r in rows}
assert m[sys.argv[2]] == "idle", m   # no pr, spawning → idle
assert m[sys.argv[3]] == "approved", m
assert all("derived_status" in r for r in rows)
PY
  run bash "$ARO" list --mode overnight --json
  [ "$status" -eq 0 ]
  python3 -c 'import sys,json; assert len(json.loads(sys.argv[1]))==1' "$output"
}

@test "show: prints durable facts, derived status and precedence trace" {
  RUN_ID="$(bash "$ARO" start overnight dev-orchestrator "task")"
  bash "$ARO" pr "$RUN_ID" 1005 --state open --ci failing >/dev/null
  run bash "$ARO" show "$RUN_ID"
  [ "$status" -eq 0 ]
  [[ "$output" == *"derived_status : ci_failed"* ]]
  [[ "$output" == *"trace"* ]]
  [[ "$output" == *"pr.ci=failing"* ]]
}

@test "reset: empties the ledger" {
  RUN_ID="$(bash "$ARO" start overnight dev-orchestrator "task")"
  run bash "$ARO" reset
  [ "$status" -eq 0 ]
  [ ! -s "$SAVIA_RUNS_LEDGER" ]
}

@test "usage: no subcommand exits non-zero with usage" {
  run bash "$ARO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: savia-runs.sh"* ]]
}
