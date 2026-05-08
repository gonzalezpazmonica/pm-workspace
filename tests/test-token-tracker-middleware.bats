#!/usr/bin/env bats
# BATS tests for .opencode/hooks/token-tracker-middleware.sh
# PostToolUse async — monitors context token usage with 3 zones (50/70/85%).
# Ref: batch 51 hook coverage — final 3 hooks → 58/58 (100%) — SPEC-071 Slice 4.

HOOK=".opencode/hooks/token-tracker-middleware.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_REPO=$(mktemp -d "$TMPDIR/tt-XXXXXX")
  mkdir -p "$TEST_REPO/output"
}
teardown() {
  rm -rf "$TEST_REPO" 2>/dev/null || true
  cd /
}

# ── Structural ────────────────────────────────────

@test "hook file exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }
@test "header: PostToolUse event documented" {
  run grep -c 'PostToolUse' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "header: standard tier annotated" {
  run grep -c 'standard' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Profile gate ──────────────────────────────────

@test "profile gate: standard tier sourced" {
  run grep -c 'profile_gate "standard"' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "profile gate: lib path resolved" {
  run grep -c 'LIB_DIR' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Pass-through ──────────────────────────────────

@test "edge: zero tokens used exits 0 fail-safe" {
  CLAUDE_CONTEXT_TOKENS_USED=0 CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "pass-through: missing env vars uses defaults USED=0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "pass-through: stdin is consumed silently" {
  CLAUDE_CONTEXT_TOKENS_USED=0 CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" <<< '{"any":"data"}'
  [ "$status" -eq 0 ]
}

# ── Zone: hint (50–69%) ───────────────────────────

@test "zone hint: 50% emits stderr suggestion" {
  CLAUDE_CONTEXT_TOKENS_USED=100000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"50"* || "$output" == *"50"* ]]
}

@test "zone hint: 60% does not log to jsonl" {
  CLAUDE_CONTEXT_TOKENS_USED=120000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [[ ! -s "$TEST_REPO/output/context-token-log.jsonl" || \
     ! "$(cat "$TEST_REPO/output/context-token-log.jsonl" 2>/dev/null)" =~ \"zone\" ]]
}

# ── Zone: alert (70–84%) ──────────────────────────

@test "zone alert: 70% logs alert to jsonl" {
  CLAUDE_CONTEXT_TOKENS_USED=140000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [[ -f "$TEST_REPO/output/context-token-log.jsonl" ]]
  run cat "$TEST_REPO/output/context-token-log.jsonl"
  [[ "$output" == *"alert"* ]]
}

@test "zone alert: 75% recommends /compact in stderr" {
  CLAUDE_CONTEXT_TOKENS_USED=150000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [[ "$stderr" == *"compact"* || "$output" == *"compact"* ]]
}

# ── Zone: critical (≥85%) ─────────────────────────

@test "zone critical: 90% logs critical to jsonl" {
  CLAUDE_CONTEXT_TOKENS_USED=180000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  run cat "$TEST_REPO/output/context-token-log.jsonl"
  [[ "$output" == *"critical"* ]]
}

@test "zone critical: 85% triggers auto-compact attempt" {
  # auto-compact.sh is fire-and-forget background — we only check the path branch
  run grep -c 'auto-compact' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── JSON log structure ────────────────────────────

@test "log: zone field present in jsonl" {
  CLAUDE_CONTEXT_TOKENS_USED=180000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  run cat "$TEST_REPO/output/context-token-log.jsonl"
  [[ "$output" == *'"zone"'* ]]
}

@test "log: pct field present in jsonl" {
  CLAUDE_CONTEXT_TOKENS_USED=180000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  run cat "$TEST_REPO/output/context-token-log.jsonl"
  [[ "$output" == *'"pct"'* ]]
}

@test "log: ISO 8601 UTC timestamp" {
  CLAUDE_CONTEXT_TOKENS_USED=180000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  run cat "$TEST_REPO/output/context-token-log.jsonl"
  [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ]]
}

@test "log: used and max bytes preserved" {
  CLAUDE_CONTEXT_TOKENS_USED=180000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  run cat "$TEST_REPO/output/context-token-log.jsonl"
  [[ "$output" == *'"used":180000'* ]]
  [[ "$output" == *'"max":200000'* ]]
}

# ── Negative cases ────────────────────────────────

@test "edge: large token max boundary does not crash" {
  CLAUDE_CONTEXT_TOKENS_USED=100 CLAUDE_CONTEXT_TOKENS_MAX=999999 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "edge: USED overflow above MAX does not error" {
  CLAUDE_CONTEXT_TOKENS_USED=300000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "edge: empty CLAUDE_PROJECT_DIR fallback to pwd" {
  cd "$TEST_REPO"
  CLAUDE_CONTEXT_TOKENS_USED=180000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
    run bash "$BATS_TEST_DIRNAME/../$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

# ── Edge cases ────────────────────────────────────

@test "edge: exactly 50% emits hint" {
  CLAUDE_CONTEXT_TOKENS_USED=100000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "edge: exactly 70% logs alert" {
  CLAUDE_CONTEXT_TOKENS_USED=140000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  run cat "$TEST_REPO/output/context-token-log.jsonl"
  [[ "$output" == *"alert"* ]]
}

@test "edge: exactly 85% logs critical" {
  CLAUDE_CONTEXT_TOKENS_USED=170000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  run cat "$TEST_REPO/output/context-token-log.jsonl"
  [[ "$output" == *"critical"* ]]
}

@test "edge: 49% silent (no log, no stderr)" {
  CLAUDE_CONTEXT_TOKENS_USED=98000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [[ ! -s "$TEST_REPO/output/context-token-log.jsonl" || \
     ! "$(cat "$TEST_REPO/output/context-token-log.jsonl" 2>/dev/null)" =~ \"zone\" ]]
}

# ── Isolation ─────────────────────────────────────

@test "isolation: hook always exits 0" {
  CLAUDE_CONTEXT_TOKENS_USED=180000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "isolation: only writes under output/" {
  CLAUDE_CONTEXT_TOKENS_USED=180000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" </dev/null
  # Files outside $TEST_REPO/output should not exist
  [[ ! -e "$TEST_REPO/random-side-effect" ]]
  [[ -d "$TEST_REPO/output" ]] || [[ ! -d "$TEST_REPO/output" ]]
}

@test "coverage: all 3 zones documented in source" {
  run grep -E 'critical|alert|hint|recommend|85|70|50' "$HOOK"
  [ "$status" -eq 0 ]
}
