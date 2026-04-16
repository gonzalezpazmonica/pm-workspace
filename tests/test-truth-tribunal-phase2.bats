#!/usr/bin/env bats
# tests/test-truth-tribunal-phase2.bats
# BATS tests for SPEC-106 Phase 2: post-report-write.sh hook + worker.
# Verifies queue lifecycle (enqueue → claim → done), report-type
# heuristics (path + frontmatter), self-recursion guards, and worker
# subcommands (process, status, clean, enqueue).
#
# Ref: SPEC-106 Phase 2 (async hook integration)
# Ref: SPEC-055 (test quality gate, score >=80)

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  HOOK="$REPO_ROOT/.claude/hooks/post-report-write.sh"
  WORKER="$REPO_ROOT/scripts/truth-tribunal-worker.sh"
  TRIBUNAL="$REPO_ROOT/scripts/truth-tribunal.sh"
  TMPDIR_TEST=$(mktemp -d)
  export TRUTH_TRIBUNAL_QUEUE="$TMPDIR_TEST/queue"
  export TRUTH_TRIBUNAL_LOG="$TMPDIR_TEST/worker.log"
  export TRUTH_TRIBUNAL_CACHE="$TMPDIR_TEST/cache"
  mkdir -p "$TRUTH_TRIBUNAL_QUEUE" "$TRUTH_TRIBUNAL_CACHE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# Helper: build PostToolUse JSON for the hook
hook_input() {
  local file="$1" tool="${2:-Write}"
  printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$tool" "$file"
}

# ── Hook structure ────────────────────────────────────────────────────────

@test "hook exists and is executable" {
  [[ -x "$HOOK" ]]
}

@test "hook uses set -uo pipefail" {
  head -3 "$HOOK" | grep -q "set -uo pipefail"
}

@test "worker exists and is executable" {
  [[ -x "$WORKER" ]]
}

@test "hook is registered in settings.json PostToolUse" {
  grep -q "post-report-write.sh" "$REPO_ROOT/.claude/settings.json"
}

# ── Hook: skip non-report files ───────────────────────────────────────────

@test "hook ignores .py files" {
  local f="$TMPDIR_TEST/script.py"
  echo "print(1)" > "$f"
  hook_input "$f" | bash "$HOOK"
  local count
  count=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$count" -eq 0 ]]
}

@test "hook ignores random .md outside output/" {
  local f="$TMPDIR_TEST/random-notes.md"
  echo "# Notes" > "$f"
  hook_input "$f" | bash "$HOOK"
  local count
  count=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$count" -eq 0 ]]
}

@test "hook ignores .truth.crc files (self-recursion guard)" {
  mkdir -p "$TMPDIR_TEST/output/audits"
  local f="$TMPDIR_TEST/output/audits/foo.md.truth.crc"
  echo "verdict: PUBLISHABLE" > "$f"
  hook_input "$f" | bash "$HOOK"
  local count
  count=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$count" -eq 0 ]]
}

@test "hook ignores nonexistent files (graceful)" {
  hook_input "/nonexistent/path.md" | bash "$HOOK"
  [[ $? -eq 0 ]]
  local count
  count=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$count" -eq 0 ]]
}

# ── Hook: enqueue on report-like paths ────────────────────────────────────

@test "hook enqueues file under output/audits/" {
  mkdir -p "$TMPDIR_TEST/output/audits"
  local f="$TMPDIR_TEST/output/audits/20260415-foo.md"
  echo "# Audit" > "$f"
  hook_input "$f" | bash "$HOOK"
  local count
  count=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$count" -eq 1 ]]
}

@test "hook enqueues ceo-report by filename" {
  mkdir -p "$TMPDIR_TEST/output"
  local f="$TMPDIR_TEST/output/ceo-report-q4.md"
  echo "# CEO" > "$f"
  hook_input "$f" | bash "$HOOK"
  local count
  count=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$count" -eq 1 ]]
}

@test "hook enqueues file with report_type frontmatter" {
  mkdir -p "$TMPDIR_TEST/random/path"
  local f="$TMPDIR_TEST/random/path/notes.md"
  cat > "$f" <<EOF
---
report_type: executive
---
# Body
EOF
  hook_input "$f" | bash "$HOOK"
  local count
  count=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$count" -eq 1 ]]
}

# ── Worker: subcommands ───────────────────────────────────────────────────

@test "worker help prints usage" {
  run bash "$WORKER" help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"truth-tribunal-worker.sh"* ]]
  [[ "$output" == *"process"* ]]
}

@test "worker unknown subcommand exits 2" {
  run bash "$WORKER" frobnicate
  [[ "$status" -eq 2 ]]
}

@test "worker status shows zero counts on empty queue" {
  run bash "$WORKER" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"pending:     0"* ]]
  [[ "$output" == *"in-progress: 0"* ]]
}

@test "worker enqueue requires path argument" {
  run bash "$WORKER" enqueue
  [[ "$status" -eq 2 ]]
}

@test "worker enqueue rejects nonexistent file" {
  run bash "$WORKER" enqueue "/nonexistent/foo.md"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"ERROR"* ]]
}

@test "worker enqueue creates a .req file" {
  local f="$TMPDIR_TEST/manual.md"
  echo "# Manual" > "$f"
  run bash "$WORKER" enqueue "$f"
  [[ "$status" -eq 0 ]]
  local count
  count=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$count" -eq 1 ]]
}

# ── Worker: process pipeline ──────────────────────────────────────────────

@test "worker process exits 1 on empty queue" {
  run bash "$WORKER" process
  [[ "$status" -eq 1 ]]
}

@test "worker process claims and marks done" {
  local f="$TMPDIR_TEST/report.md"
  echo "# Report" > "$f"
  bash "$WORKER" enqueue "$f" >/dev/null
  run bash "$WORKER" process
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Processed: 1"* ]]
  local done_ct
  done_ct=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.done" 2>/dev/null | wc -l)
  [[ "$done_ct" -eq 1 ]]
  # Pending marker should exist next to the report
  [[ -f "${f}.truth.pending" ]]
}

@test "worker process handles missing report gracefully (marks fail)" {
  local req="$TRUTH_TRIBUNAL_QUEUE/TT-fake.req"
  echo "report_path=/nonexistent/report.md" > "$req"
  run bash "$WORKER" process
  local fail_ct
  fail_ct=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.fail" 2>/dev/null | wc -l)
  [[ "$fail_ct" -eq 1 ]]
}

@test "worker process honors --max" {
  for i in 1 2 3; do
    local f="$TMPDIR_TEST/r${i}.md"
    echo "# r${i}" > "$f"
    bash "$WORKER" enqueue "$f" >/dev/null
    sleep 0.01  # ensure unique timestamp
  done
  run bash "$WORKER" process --max 2
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Processed: 2"* ]]
  local pending
  pending=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$pending" -eq 1 ]]
}

# ── Worker: clean ─────────────────────────────────────────────────────────

@test "worker clean removes only old .done files" {
  # Create two .done files: one fresh, one >7 days old
  touch "$TRUTH_TRIBUNAL_QUEUE/fresh.done"
  touch -d "10 days ago" "$TRUTH_TRIBUNAL_QUEUE/old.done"
  run bash "$WORKER" clean
  [[ "$status" -eq 0 ]]
  [[ -f "$TRUTH_TRIBUNAL_QUEUE/fresh.done" ]]
  [[ ! -f "$TRUTH_TRIBUNAL_QUEUE/old.done" ]]
}

# ── Pending marker structure ──────────────────────────────────────────────

@test "pending marker has YAML frontmatter with required fields" {
  local f="$TMPDIR_TEST/audit-foo.md"
  echo "# Audit" > "$f"
  bash "$WORKER" enqueue "$f" >/dev/null
  bash "$WORKER" process >/dev/null
  local marker="${f}.truth.pending"
  [[ -f "$marker" ]]
  grep -q "^report_type:" "$marker"
  grep -q "^destination_tier:" "$marker"
  grep -q "^status: pending_evaluation" "$marker"
  grep -q "^next_action:" "$marker"
}

# ── Idempotency ──────────────────────────────────────────────────────────

@test "hook does not double-enqueue if cache is fresh" {
  mkdir -p "$TMPDIR_TEST/output/audits"
  local f="$TMPDIR_TEST/output/audits/cached.md"
  echo "# Cached" > "$f"
  # Pre-populate cache
  local hash
  hash=$(sha256sum "$f" | awk '{print $1}')
  echo "verdict: PUBLISHABLE" > "$TRUTH_TRIBUNAL_CACHE/${hash}.truth.crc"
  hook_input "$f" | bash "$HOOK"
  local count
  count=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$count" -eq 0 ]]
}
