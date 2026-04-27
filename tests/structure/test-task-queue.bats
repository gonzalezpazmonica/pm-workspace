#!/usr/bin/env bats
# Ref: SE-075 Slice 1 — scripts/lib/task-queue.py (serial-execution job queue)
# Spec: docs/propuestas/SE-075-voicebox-adoption.md
# Re-implementation pattern from voicebox MIT (no source copied).
#
# Safety: bash consumers of this CLI should source `set -uo pipefail` themselves.
# Coverage of TaskQueue methods exercised below: _queue_path, _conn, _init_schema,
# enqueue, dequeue, heartbeat, complete, status, recover, drain, list_jobs, _cli.

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="scripts/lib/task-queue.py"
  TASK_QUEUE_ABS="$ROOT_DIR/$SCRIPT"
  TMPDIR_TQ=$(mktemp -d)
  export PROJECT_ROOT="$TMPDIR_TQ"
}

teardown() {
  rm -rf "$TMPDIR_TQ"
  unset PROJECT_ROOT
}

# Helper: run the queue CLI against the sandboxed PROJECT_ROOT
tq() { python3 "$TASK_QUEUE_ABS" "$@"; }

# ── C1 / C2 — file-level safety + identity ───────────────────────────────────

@test "task-queue.py: file exists, has shebang, and is executable" {
  [ -f "$TASK_QUEUE_ABS" ]
  head -1 "$TASK_QUEUE_ABS" | grep -q '^#!'
  [ -x "$TASK_QUEUE_ABS" ]
}

@test "task-queue.py: spec reference SE-075 cited in module docstring" {
  grep -q "SE-075" "$TASK_QUEUE_ABS"
  grep -q "docs/propuestas/SE-075" "$TASK_QUEUE_ABS"
}

@test "task-queue.py: attribution to voicebox MIT pattern present (clean-room)" {
  grep -q "voicebox" "$TASK_QUEUE_ABS"
  grep -q "MIT" "$TASK_QUEUE_ABS"
  grep -q "clean-room" "$TASK_QUEUE_ABS"
}

# ── C3 — Positive paths (≥5 distinct success behaviours) ────────────────────

@test "enqueue prints a job_id (32-hex) and creates the queue file" {
  run tq enqueue myqueue run-spec --payload '{"spec":"SE-073"}'
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[a-f0-9]{32}$ ]]
  [ -f "$TMPDIR_TQ/output/task-queue/myqueue.sqlite" ]
}

@test "dequeue claims the oldest pending job and reports its payload" {
  tq enqueue qA run-spec-1 --payload '{"spec":"SE-073"}' >/dev/null
  tq enqueue qA run-spec-2 --payload '{"spec":"SE-074"}' >/dev/null
  run tq dequeue qA --worker w1
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; j=json.loads(sys.argv[1]); assert j['command']=='run-spec-1'; assert j['payload']['spec']=='SE-073'" "$output"
}

@test "complete --ok marks the job as done" {
  jid=$(tq enqueue qB run --payload '{}')
  tq dequeue qB --worker w1 >/dev/null
  run tq complete qB "$jid" --ok
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
  run tq status qB --json
  python3 -c "import json,sys; s=json.loads(sys.argv[1]); assert s['done']==1 and s['running']==0" "$output"
}

@test "complete --fail records the error message" {
  jid=$(tq enqueue qC run --payload '{}')
  tq dequeue qC --worker w1 >/dev/null
  run tq complete qC "$jid" --fail "boom: rerun later"
  [ "$status" -eq 0 ]
  run tq list qC --status failed
  [[ "$output" == *"boom: rerun later"* ]]
}

@test "status counts jobs by state (json output is parseable)" {
  tq enqueue qD a >/dev/null; tq enqueue qD b >/dev/null
  run tq status qD --json
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; s=json.loads(sys.argv[1]); assert s['pending']==2; assert s['done']==0" "$output"
}

@test "drain deletes done|failed jobs and leaves pending intact" {
  jid=$(tq enqueue qE run)
  tq dequeue qE --worker w1 >/dev/null
  tq complete qE "$jid" --ok >/dev/null
  tq enqueue qE later >/dev/null
  run tq drain qE
  [ "$status" -eq 0 ]
  [[ "$output" == "deleted=1" ]]
  run tq status qE --json
  python3 -c "import json,sys; s=json.loads(sys.argv[1]); assert s['pending']==1; assert s['done']==0" "$output"
}

@test "list_jobs prints one JSON object per row" {
  tq enqueue qL a >/dev/null
  tq enqueue qL b >/dev/null
  run tq list qL
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l)" -eq 2 ]
  echo "$output" | head -1 | python3 -c "import json,sys; r=json.loads(sys.stdin.read()); assert r['queue']=='qL'"
}

# ── C4 — Negative / failure paths (≥4) ───────────────────────────────────────

@test "complete with --fail must include a message (mutually exclusive with --ok)" {
  jid=$(tq enqueue qF run)
  tq dequeue qF --worker w1 >/dev/null
  run tq complete qF "$jid"
  [ "$status" -ne 0 ]
}

@test "invalid queue name (only special chars) is rejected with exit 2" {
  run tq enqueue '!!!' run
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid queue name"* ]]
}

@test "missing job_id argument to complete fails (argparse error)" {
  run tq complete somequeue
  [ "$status" -ne 0 ]
}

@test "unknown subcommand fails with non-zero exit" {
  run tq foobar somequeue
  [ "$status" -ne 0 ]
}

@test "no arguments at all produces a usage error" {
  run tq
  [ "$status" -ne 0 ]
}

# ── C5 — Edge cases (empty / nonexistent / boundary / no-args / timeout) ─────

@test "edge: dequeue on empty queue returns exit 1 and no stdout" {
  run tq dequeue emptyq --worker w1
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "edge: dequeue on nonexistent queue still creates the schema and returns exit 1" {
  run tq dequeue brand_new_q --worker w1
  [ "$status" -eq 1 ]
  [ -f "$TMPDIR_TQ/output/task-queue/brand_new_q.sqlite" ]
}

@test "edge: drain on empty queue returns deleted=0 (zero boundary)" {
  run tq drain neverused
  [ "$status" -eq 0 ]
  [[ "$output" == "deleted=0" ]]
}

@test "edge: stale-heartbeat recover resets running jobs to pending (timeout boundary)" {
  jid=$(tq enqueue qR run)
  tq dequeue qR --worker w1 >/dev/null
  # With STALE_HEARTBEAT_SEC=0 the constructor's auto-recover already runs first,
  # so explicit recover() is idempotent (returns 0). The end-state is what matters:
  # the running job must become pending again.
  TASK_QUEUE_STALE_SEC=0 run tq recover qR
  [ "$status" -eq 0 ]
  [[ "$output" == "recovered=0" ]]
  run tq status qR --json
  python3 -c "import json,sys; s=json.loads(sys.argv[1]); assert s['pending']==1; assert s['running']==0" "$output"
}

@test "edge: large payload (>4 KiB) round-trips without truncation" {
  big=$(python3 -c 'print("x"*5000)')
  jid=$(tq enqueue qBig run --payload "{\"blob\":\"$big\"}")
  run tq dequeue qBig --worker w1
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; j=json.loads(sys.argv[1]); assert len(j['payload']['blob'])==5000" "$output"
}

# ── C6 / C9 — Atomicity + assertion-quality reinforcement ───────────────────

@test "atomicity: two workers cannot dequeue the same job (no double-claim)" {
  jid=$(tq enqueue qX run)
  run tq dequeue qX --worker w1
  [ "$status" -eq 0 ]
  run tq dequeue qX --worker w2
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "auto-recovery on construction: stale running jobs become pending again" {
  jid=$(tq enqueue qAR run)
  tq dequeue qAR --worker w1 >/dev/null
  # Re-construct TaskQueue with stale-cutoff=0 — recover() runs in __init__
  TASK_QUEUE_STALE_SEC=0 run tq status qAR --json
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; s=json.loads(sys.argv[1]); assert s['pending']==1; assert s['running']==0" "$output"
}

@test "fresh heartbeats are NOT recovered (boundary check on heartbeat freshness)" {
  jid=$(tq enqueue qH run)
  tq dequeue qH --worker w1 >/dev/null
  # Default cutoff (300s) — the just-claimed job stays running
  run tq recover qH
  [ "$status" -eq 0 ]
  [[ "$output" == "recovered=0" ]]
}

# ── C2 — safety: script defines defensive primitives ────────────────────────

@test "safety: task-queue.py uses BEGIN IMMEDIATE for atomic claim" {
  grep -q "BEGIN IMMEDIATE" "$TASK_QUEUE_ABS"
}

@test "safety: WAL journal mode is enabled for concurrent readers" {
  grep -q "journal_mode=WAL" "$TASK_QUEUE_ABS"
}

@test "safety: script header documents storage path under output/task-queue" {
  grep -q "output/task-queue" "$TASK_QUEUE_ABS"
}
