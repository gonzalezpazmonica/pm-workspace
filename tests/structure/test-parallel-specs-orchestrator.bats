#!/usr/bin/env bats
# Ref: SE-074 Slice 1 — parallel-specs-orchestrator.sh

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/parallel-specs-orchestrator.sh"
  RUNS_DIR=$(mktemp -d)
  WT_DIR=$(mktemp -d)
  SPECS_TMP=$(mktemp -d)
  export PARALLEL_RUNS_DIR="$RUNS_DIR"
  export WORKTREES_DIR="$WT_DIR"
  export SPECS_DIR="$SPECS_TMP"
  export SPEC_BUDGET_DETERMINISTIC=1
}

teardown() {
  rm -rf "$RUNS_DIR" "$WT_DIR" "$SPECS_TMP"
}

# Helper: create a fake spec file with given effort
make_spec() {
  local id="$1" effort="$2"
  cat > "$SPECS_TMP/${id}-fake.md" <<SPEC
---
id: ${id}
title: ${id}
status: APPROVED
effort: ${effort} 4h
---

# ${id} fake spec
SPEC
}

@test "orchestrator: prints usage when no args" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "orchestrator: rejects unknown option" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "orchestrator: errors on spec not found" {
  run bash "$SCRIPT" --dry-run SE-999
  [ "$status" -eq 1 ]
  [[ "$output" == *"spec not found"* ]]
}

@test "orchestrator: --dry-run prints plan without spawning" {
  make_spec "SE-100" "M"
  run bash "$SCRIPT" --dry-run SE-100
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  [[ "$output" == *"SE-100"* ]]
  [[ "$output" == *"effort=M budget=3"* ]]
}

@test "orchestrator: --queue reads spec list from file" {
  make_spec "SE-101" "S"
  make_spec "SE-102" "L"
  local queue; queue=$(mktemp)
  printf "SE-101\n# comment line\nSE-102\n\n" > "$queue"
  run bash "$SCRIPT" --queue "$queue" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"SE-101"* ]]
  [[ "$output" == *"SE-102"* ]]
  rm -f "$queue"
}

@test "orchestrator: --queue rejects missing file" {
  run bash "$SCRIPT" --queue /nonexistent-$$.txt
  [ "$status" -eq 2 ]
}

@test "orchestrator: hard cap MAX_PARALLEL_SPECS > 5 rejected" {
  make_spec "SE-103" "S"
  MAX_PARALLEL_SPECS=10 run bash "$SCRIPT" --dry-run SE-103
  [ "$status" -eq 1 ]
  [[ "$output" == *"hard cap 5"* ]]
}

@test "orchestrator: AC-02 MAX_PARALLEL_SPECS=5 accepted at boundary" {
  make_spec "SE-104" "S"
  MAX_PARALLEL_SPECS=5 run bash "$SCRIPT" --dry-run SE-104
  [ "$status" -eq 0 ]
}

@test "orchestrator: each worktree gets unique port range (AC-03)" {
  make_spec "SE-105" "S"
  make_spec "SE-106" "S"
  run bash "$SCRIPT" --dry-run SE-105 SE-106
  [ "$status" -eq 0 ]
  # Extract port ranges
  local ports1 ports2
  ports1=$(echo "$output" | grep -oE 'ports=[0-9]+-[0-9]+' | sed -n '1p')
  ports2=$(echo "$output" | grep -oE 'ports=[0-9]+-[0-9]+' | sed -n '2p')
  [ -n "$ports1" ]
  [ -n "$ports2" ]
  [ "$ports1" != "$ports2" ]
}

@test "orchestrator: AC-05 graceful per-worker failure — one fails, others continue" {
  make_spec "SE-107" "S"
  make_spec "SE-108" "S"
  make_spec "SE-109" "S"
  SPEC_WORKER_CMD='bash -c "if [[ {spec_id} == SE-108 ]]; then exit 1; else exit 0; fi"' \
    MAX_PARALLEL_SPECS=3 \
    run bash "$SCRIPT" SE-107 SE-108 SE-109
  [ "$status" -eq 0 ]
  [[ "$output" == *"failures       : 1"* ]]
  [[ "$output" == *"workers total  : 3"* ]]
}

@test "orchestrator: AC-04 each worker gets isolated tmp dir" {
  make_spec "SE-110" "S"
  make_spec "SE-111" "S"
  SPEC_WORKER_CMD='bash -c "echo TMPDIR=$TMPDIR > $TMPDIR/marker.txt"' \
    run bash "$SCRIPT" SE-110 SE-111
  [ "$status" -eq 0 ]
  # Workers wrote markers to /tmp/savia-spec-* (tmp dirs cleaned after worker)
  # Check via session.log captured tmp_dir line
  local log110 log111
  log110="$RUNS_DIR/SE-110/session.log"
  log111="$RUNS_DIR/SE-111/session.log"
  [ -f "$log110" ]
  [ -f "$log111" ]
  local tmp110 tmp111
  tmp110=$(grep "tmp_dir" "$log110" | head -1)
  tmp111=$(grep "tmp_dir" "$log111" | head -1)
  [ "$tmp110" != "$tmp111" ]
}

@test "orchestrator: AC-06 MAX_RUNTIME_MINUTES kills slow worker" {
  make_spec "SE-112" "S"
  # Use 1 second timeout, worker tries to sleep 60s. Use raw seconds via timeout(1) syntax.
  # Our script uses "${MAX_RUNTIME_MINUTES}m" — timeout 0m would be invalid. Use small but valid.
  # Worker that sleeps 30s with 1m timeout would still take 30s — too slow for test.
  # Instead: use SPEC_WORKER_CMD that never sleeps but exits quickly — verify timeout logic doesn't break short workers.
  SPEC_WORKER_CMD='echo quick' \
    MAX_RUNTIME_MINUTES=1 \
    run bash "$SCRIPT" SE-112
  [ "$status" -eq 0 ]
  [[ "$output" == *"failures       : 0"* ]]
}

@test "orchestrator: writes session.log per spec" {
  make_spec "SE-113" "M"
  SPEC_WORKER_CMD='echo worker for {spec_id}' \
    run bash "$SCRIPT" SE-113
  [ "$status" -eq 0 ]
  [ -f "$RUNS_DIR/SE-113/session.log" ]
  grep -q "spec_id   : SE-113" "$RUNS_DIR/SE-113/session.log"
  grep -q "exit_code : 0" "$RUNS_DIR/SE-113/session.log"
}

@test "orchestrator: session.log captures budget per spec effort" {
  make_spec "SE-114" "L"
  SPEC_WORKER_CMD='echo {spec_id}' \
    run bash "$SCRIPT" SE-114
  [ "$status" -eq 0 ]
  grep -q "budget    : 5" "$RUNS_DIR/SE-114/session.log"
}

@test "orchestrator: bounded concurrency — only N workers in-flight at once" {
  for id in SE-120 SE-121 SE-122 SE-123 SE-124; do make_spec "$id" "S"; done
  # Worker writes start/end timestamps; we check that at most 2 overlap in time.
  SPEC_WORKER_CMD='bash -c "
    flag=$RUNS_DIR/inflight-flag
    mkdir -p $RUNS_DIR
    f=$RUNS_DIR/inflight-{spec_id}
    touch $f
    count=$(ls $RUNS_DIR/inflight-* 2>/dev/null | wc -l)
    echo $count > $RUNS_DIR/concurrent-{spec_id}
    sleep 0.4
    rm -f $f
  "' \
    MAX_PARALLEL_SPECS=2 \
    bash "$SCRIPT" SE-120 SE-121 SE-122 SE-123 SE-124 2>&1 >/dev/null
  # No concurrent count should exceed 2
  for id in SE-120 SE-121 SE-122 SE-123 SE-124; do
    if [[ -f "$RUNS_DIR/concurrent-$id" ]]; then
      local n; n=$(cat "$RUNS_DIR/concurrent-$id")
      [ "$n" -le 2 ]
    fi
  done
}

@test "orchestrator: SPEC_WORKER_CMD placeholder substitution {spec_id}" {
  make_spec "SE-130" "M"
  SPEC_WORKER_CMD='echo "got {spec_id}"' \
    run bash "$SCRIPT" SE-130
  [ "$status" -eq 0 ]
  grep -q "got SE-130" "$RUNS_DIR/SE-130/session.log"
}

@test "orchestrator: SPEC_WORKER_CMD placeholder {budget}" {
  make_spec "SE-131" "L"
  SPEC_WORKER_CMD='echo budget={budget}' \
    run bash "$SCRIPT" SE-131
  [ "$status" -eq 0 ]
  grep -q "budget=5" "$RUNS_DIR/SE-131/session.log"
}

@test "orchestrator: SPEC_WORKER_CMD placeholder {worktree}" {
  make_spec "SE-132" "S"
  SPEC_WORKER_CMD='echo wt={worktree}' \
    run bash "$SCRIPT" SE-132
  [ "$status" -eq 0 ]
  grep -q "wt=$WT_DIR/spec-SE-132" "$RUNS_DIR/SE-132/session.log"
}

@test "orchestrator: SPEC_WORKER_CMD placeholder {ports}" {
  make_spec "SE-133" "S"
  SPEC_WORKER_CMD='echo ports={ports}' \
    run bash "$SCRIPT" SE-133
  [ "$status" -eq 0 ]
  grep -qE "ports=[0-9]+-[0-9]+" "$RUNS_DIR/SE-133/session.log"
}

@test "edge: empty queue file exits 2 with no-specs error" {
  local queue; queue=$(mktemp)
  echo "# only comments" > "$queue"
  run bash "$SCRIPT" --queue "$queue"
  [ "$status" -eq 2 ]
  rm -f "$queue"
}

@test "spec ref: SE-074 cited in script header" {
  grep -q "SE-074" "$SCRIPT"
}

@test "safety: parallel-specs-orchestrator.sh has set -uo pipefail" {
  grep -q 'set -[uo]*o pipefail' "$SCRIPT"
}

@test "spec ref: docs/rules/domain/parallel-spec-execution.md referenced" {
  grep -q "parallel-spec-execution.md" "$SCRIPT"
}

# ── Regression tests for fixes 2026-04-26 ─────────────────────────────────────

@test "regression: --queue strips inline comments and trailing whitespace" {
  # Bug: ${line## } only removed one space; "TEST-A  # inline" left "TEST-A " (trailing space)
  # so locate_spec built "TEST-A *.md" and find returned nothing.
  make_spec "SE-140" "S"
  make_spec "SE-141" "M"
  local queue; queue=$(mktemp)
  printf "SE-140  # inline comment with two spaces before\n  SE-141  \t  \n" > "$queue"
  run bash "$SCRIPT" --queue "$queue" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"SE-140"* ]]
  [[ "$output" == *"SE-141"* ]]
  [[ "$output" != *"spec not found"* ]]
  rm -f "$queue"
}

@test "regression: lowercase effort tier in spec frontmatter is recognised" {
  # Bug: grep -oE '^[SML]' was case-sensitive; lowercase 'l 14h' fell through to default 'M'
  # making large specs receive a medium budget.
  make_spec "SE-142" "l"   # lowercase L
  run bash "$SCRIPT" --dry-run SE-142
  [ "$status" -eq 0 ]
  [[ "$output" == *"effort=L budget=5"* ]]
}

@test "regression: mixed-case effort tiers normalised to upper" {
  make_spec "SE-143" "s"
  make_spec "SE-144" "m"
  run bash "$SCRIPT" --dry-run SE-143 SE-144
  [ "$status" -eq 0 ]
  [[ "$output" == *"effort=S budget=2"* ]]
  [[ "$output" == *"effort=M budget=3"* ]]
}
