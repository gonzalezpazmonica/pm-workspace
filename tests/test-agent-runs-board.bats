#!/usr/bin/env bats
# Ref: docs/specs/SE-349-agent-runs-ledger.spec.md — skill agent-runs-board (SE-376)
#
# Comportamiento del CLI scripts/savia-runs.sh que documenta la skill: registro, columnas
# derivadas, guardrail de finish y, sobre todo, que varios runs autónomos escribiendo a la vez
# no se pisen (cada orden que modifica el ledger lo hace bajo cerrojo exclusivo).

SCRIPT="scripts/savia-runs.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMPDIR="$(mktemp -d)"
  export SAVIA_RUNS_LEDGER="$TMPDIR/data/agent-runs-ledger.jsonl"
  CLI="$REPO_ROOT/$SCRIPT"
}

teardown() {
  rm -rf "$TMPDIR"
}

start_run() {
  bash "$CLI" start overnight dev "${1:-tarea}" --project p --branch agent/x
}

column_of() {
  bash "$CLI" list --json | python3 -c "import json,sys; print({r['run_id']:r['derived_status'] for r in json.load(sys.stdin)}[sys.argv[1]])" "$1"
}

@test "target has safety flags" {
  grep -q "set -uo pipefail" "$REPO_ROOT/$SCRIPT"
}

@test "start registers a run and prints its run_id" {
  R=$(start_run)
  [[ "$R" =~ ^[0-9a-f-]{8,}$ ]]
  [ "$(wc -l < "$SAVIA_RUNS_LEDGER")" -eq 1 ]
  run bash "$CLI" show "$R"
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent/x"* ]]
}

@test "derived column follows the facts: working, ci failure, review, merged" {
  R=$(start_run)
  bash "$CLI" state "$R" active >/dev/null
  [ "$(column_of "$R")" = "working" ]
  bash "$CLI" pr "$R" 12 --state draft --ci failing >/dev/null
  [ "$(column_of "$R")" = "ci_failed" ]
  bash "$CLI" pr "$R" 12 --state open --ci passing --review changes_requested >/dev/null
  [ "$(column_of "$R")" = "changes_requested" ]
  bash "$CLI" pr "$R" 12 --state merged --ci passing --review approved >/dev/null
  [ "$(column_of "$R")" = "merged" ]
}

@test "finish is blocked while the run owns a live PR" {
  R=$(start_run)
  bash "$CLI" pr "$R" 7 --state draft >/dev/null
  run bash "$CLI" finish "$R"
  [ "$status" -ne 0 ]
  [[ "$output" == *"BLOCKED"* ]]
  python3 -c "import json,sys; r=json.loads(open(sys.argv[1]).readline()); assert r['is_terminated'] is False" "$SAVIA_RUNS_LEDGER"
}

@test "finish succeeds after the PR is resolved or disowned, without --force" {
  R=$(start_run)
  bash "$CLI" pr "$R" 7 --state draft >/dev/null
  bash "$CLI" pr "$R" clear >/dev/null
  run bash "$CLI" finish "$R"
  [ "$status" -eq 0 ]
  [ "$(column_of "$R")" = "terminated" ]
}

@test "invalid mode, state and pr values are rejected without touching the ledger" {
  R=$(start_run)
  before=$(sha256sum "$SAVIA_RUNS_LEDGER")
  run bash "$CLI" start badmode a t
  [ "$status" -ne 0 ]
  run bash "$CLI" state "$R" bogus
  [ "$status" -ne 0 ]
  run bash "$CLI" pr "$R" 12 --ci green
  [ "$status" -ne 0 ]
  run bash "$CLI" pr "$R" doce
  [ "$status" -ne 0 ]
  [ "$(sha256sum "$SAVIA_RUNS_LEDGER")" = "$before" ]
}

@test "concurrent updates to different runs are all kept (no lost update)" {
  for i in $(seq 1 12); do start_run "t$i" >/dev/null; done
  i=0
  for R in $(python3 -c "import json,sys; [print(json.loads(l)['run_id']) for l in open(sys.argv[1])]" "$SAVIA_RUNS_LEDGER"); do
    i=$((i+1)); bash "$CLI" pr "$R" "$i" --state open >/dev/null &
  done
  wait
  [ "$(wc -l < "$SAVIA_RUNS_LEDGER")" -eq 12 ]
  [ "$(python3 -c "import json,sys; print(sum(1 for l in open(sys.argv[1]) if json.loads(l)['pr']))" "$SAVIA_RUNS_LEDGER")" -eq 12 ]
}

@test "concurrent pr and state on the same run keep both facts" {
  R=$(start_run)
  for _ in $(seq 1 6); do
    bash "$CLI" pr "$R" 33 --state open --ci passing >/dev/null &
    bash "$CLI" state "$R" waiting_input >/dev/null &
  done
  wait
  python3 -c "
import json,sys
r=json.loads(open(sys.argv[1]).readline())
assert r['pr'] and r['pr']['number']==33, r
assert r['activity_state']=='waiting_input', r
" "$SAVIA_RUNS_LEDGER"
}

@test "a start racing with updates never drops a record" {
  for i in $(seq 1 6); do start_run "base$i" >/dev/null; done
  for R in $(python3 -c "import json,sys; [print(json.loads(l)['run_id']) for l in open(sys.argv[1])]" "$SAVIA_RUNS_LEDGER"); do
    bash "$CLI" state "$R" active >/dev/null &
    start_run "nuevo" >/dev/null &
  done
  wait
  [ "$(wc -l < "$SAVIA_RUNS_LEDGER")" -eq 12 ]
}

@test "ledger rewrite works with an unusable TMPDIR and leaves no temp files" {
  R=$(start_run)
  run env TMPDIR=/nonexistent/savia-runs bash "$CLI" state "$R" active
  [ "$status" -eq 0 ]
  [ "$(column_of "$R")" = "working" ]
  ls "$TMPDIR/data" | grep -vqE '^agent-runs-ledger\.jsonl(\.lock)?$' && return 1
  true
}

@test "edge: status --json with no ledger and with an empty ledger lists every column empty" {
  check_empty() {
    python3 -c "
import json,sys
d=json.loads(sys.argv[1])
cols=['working','needs_input','ci_failed','changes_requested','merge_conflict','draft',
      'review_pending','pr_open','approved','merged','terminated','idle']
assert sorted(d['columns'])==sorted(cols), d['columns']
assert all(v==[] for v in d['columns'].values()), d['columns']
assert d['runs']==[], d['runs']
" "$1"
  }
  run bash "$CLI" status --json
  [ "$status" -eq 0 ]
  [ ! -e "$SAVIA_RUNS_LEDGER" ]
  check_empty "$output"
  bash "$CLI" init >/dev/null
  run bash "$CLI" status --json
  [ "$status" -eq 0 ]
  check_empty "$output"
}

@test "merged PR on a live run is DONE in list, status, status --json and show" {
  R=$(start_run)
  bash "$CLI" state "$R" active >/dev/null
  bash "$CLI" pr "$R" 40 --state merged --ci passing --review approved --mergeable true >/dev/null
  [ "$(column_of "$R")" = "merged" ]
  run bash "$CLI" status --json
  [ "$status" -eq 0 ]
  python3 -c "
import json,sys
d=json.loads(sys.argv[1]); R=sys.argv[2]
assert d['columns']['merged']==[R], d['columns']
assert d['columns']['approved']==[], d['columns']
assert d['runs'][0]['derived_status']=='merged', d['runs'][0]
" "$output" "$R"
  run bash "$CLI" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"READY TO MERGE (0)"* ]]
  [[ "$output" == *"DONE (1)"* ]]
  run bash "$CLI" show "$R"
  [ "$status" -eq 0 ]
  [[ "$output" == *"derived_status : merged"* ]]
  [[ "$output" == *"trace          : pr.state=merged"* ]]
}

@test "capture-cost without SAVIA_RUN_ID is a no-op: no ledger, no lock file" {
  run bash -c "echo '{}' | env -u SAVIA_RUN_ID bash '$CLI' capture-cost"
  [ "$status" -eq 0 ]
  [ ! -e "$TMPDIR/data" ]
}

@test "capture-cost under a held lock gives up quickly with exit 0 and a stderr warning" {
  R=$(start_run)
  tr="$TMPDIR/sub.jsonl"
  echo '{"message":{"model":"m","usage":{"input_tokens":5,"output_tokens":2}}}' > "$tr"
  flock "$SAVIA_RUNS_LEDGER.lock" sleep 9 &
  holder=$!
  for _ in $(seq 1 50); do flock -n "$SAVIA_RUNS_LEDGER.lock" true || break; sleep 0.1; done
  t0=$(date +%s)
  run bash -c "echo '{\"agent_transcript_path\":\"$tr\",\"agent_type\":\"x\"}' | SAVIA_RUN_ID='$R' bash '$CLI' capture-cost 2>&1"
  t1=$(date +%s)
  wait "$holder"
  [ "$status" -eq 0 ]
  [ $((t1 - t0)) -lt 8 ]
  [[ "$output" == *"lock"* ]]
  python3 -c "import json,sys; r=json.loads(open(sys.argv[1]).readline()); assert not r.get('cost'), r" "$SAVIA_RUNS_LEDGER"
}

@test "mkdir fallback: concurrent updates are all kept and the lockdir is released" {
  export SAVIA_RUNS_LOCK_IMPL=mkdir
  for i in $(seq 1 8); do start_run "t$i" >/dev/null; done
  i=0
  for R in $(python3 -c "import json,sys; [print(json.loads(l)['run_id']) for l in open(sys.argv[1])]" "$SAVIA_RUNS_LEDGER"); do
    i=$((i+1)); bash "$CLI" pr "$R" "$i" --state open >/dev/null &
  done
  wait
  [ "$(python3 -c "import json,sys; print(sum(1 for l in open(sys.argv[1]) if json.loads(l)['pr']))" "$SAVIA_RUNS_LEDGER")" -eq 8 ]
  [ ! -e "$SAVIA_RUNS_LEDGER.lockdir" ]
}

@test "mkdir fallback: an orphan lock whose owner PID is dead is broken" {
  export SAVIA_RUNS_LOCK_IMPL=mkdir
  R=$(start_run)
  bash -c 'exit 0' & dead=$!
  wait "$dead"
  mkdir "$SAVIA_RUNS_LEDGER.lockdir"
  echo "$dead" > "$SAVIA_RUNS_LEDGER.lockdir/pid"
  run env SAVIA_RUNS_LOCK_WAIT=3 bash "$CLI" state "$R" active
  [ "$status" -eq 0 ]
  [ "$(column_of "$R")" = "working" ]
  [ ! -e "$SAVIA_RUNS_LEDGER.lockdir" ]
}

@test "mkdir fallback: an old orphan lock without PID file is broken" {
  export SAVIA_RUNS_LOCK_IMPL=mkdir
  R=$(start_run)
  mkdir "$SAVIA_RUNS_LEDGER.lockdir"
  touch -d '5 minutes ago' "$SAVIA_RUNS_LEDGER.lockdir"
  run env SAVIA_RUNS_LOCK_WAIT=3 bash "$CLI" state "$R" active
  [ "$status" -eq 0 ]
  [ "$(column_of "$R")" = "working" ]
}

@test "mkdir fallback: a lock held by a live process times out with a recovery hint" {
  export SAVIA_RUNS_LOCK_IMPL=mkdir
  R=$(start_run)
  mkdir "$SAVIA_RUNS_LEDGER.lockdir"
  echo "$$" > "$SAVIA_RUNS_LEDGER.lockdir/pid"
  run env SAVIA_RUNS_LOCK_WAIT=1 bash "$CLI" state "$R" active
  [ "$status" -ne 0 ]
  [[ "$output" == *"lock timeout"* ]]
  [[ "$output" == *"$SAVIA_RUNS_LEDGER.lockdir"* ]]
  [ "$(column_of "$R")" = "idle" ]
}

@test "edge: task text with quotes stays valid JSON" {
  R=$(bash "$CLI" start overnight dev 'arreglar "comillas" y \barras')
  python3 -c "import json,sys; [json.loads(l) for l in open(sys.argv[1])]" "$SAVIA_RUNS_LEDGER"
  run bash "$CLI" show "$R"
  [[ "$output" == *'comillas'* ]]
}

@test "edge: nonexistent run_id is an error for state, pr and finish" {
  run bash "$CLI" state no-existe active
  [ "$status" -ne 0 ]
  run bash "$CLI" pr no-existe 1
  [ "$status" -ne 0 ]
  run bash "$CLI" finish no-existe
  [ "$status" -ne 0 ]
}
