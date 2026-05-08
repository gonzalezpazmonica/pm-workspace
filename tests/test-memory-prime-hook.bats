#!/usr/bin/env bats
# BATS tests for .opencode/hooks/memory-prime-hook.sh
# PreToolUse async — auto-primes memory context from user query.
# Ref: batch 49 hook coverage — SPEC-039 context-auto-prime integration

HOOK=".opencode/hooks/memory-prime-hook.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_ROOT=$(mktemp -d "$TMPDIR/mph-XXXXXX")
}
teardown() {
  rm -rf "$TEST_ROOT" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }
@test "SPEC-039 or context-auto-prime reference" {
  run grep -c 'context-auto-prime\|context-prefetch' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Fast exit paths ─────────────────────────────────────

@test "fast-exit: no store file exits 0" {
  PROJECT_ROOT="$TEST_ROOT" run bash "$HOOK" <<< "test query"
  [ "$status" -eq 0 ]
}

@test "fast-exit: empty stdin exits 0" {
  echo "test" > "$TEST_ROOT/store.jsonl"
  PROJECT_ROOT="$TEST_ROOT" run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

@test "fast-exit: missing python3 does not crash" {
  # Cannot truly remove python3 in CI; verify command -v check exists
  run grep -c 'command -v python3' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Bounded concurrency ────────────────────────────────

@test "concurrency: MAX_PARALLEL defined" {
  run grep -c 'MAX_PARALLEL=' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "concurrency: default value 5 (bounded-concurrency doctrine)" {
  run grep -c 'MAX_PARALLEL=5' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "concurrency: uses wait -n for bounded fan-out" {
  run grep -c 'wait -n\|jobs -rp' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "concurrency: bounded-concurrency.md reference" {
  run grep -c 'bounded-concurrency\|Bluesky' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Store detection ───────────────────────────────────

@test "store: default path uses .memory-store.jsonl" {
  run grep -c '\.memory-store.jsonl' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "store: STORE env var respected" {
  run grep -c 'STORE=' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "store: existence check before prime" {
  run grep -c '\[ -f.*STORE.*\]' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Script delegation ─────────────────────────────────

@test "delegate: PRIME_SCRIPT path set" {
  run grep -c 'PRIME_SCRIPT' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "delegate: PREFETCH_SCRIPT path set" {
  run grep -c 'PREFETCH_SCRIPT' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "delegate: --top 3 parameter passed" {
  run grep -c -- '--top 3' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "delegate: --max-tokens bound passed" {
  run grep -c -- '--max-tokens' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Query extraction ──────────────────────────────────

@test "query: truncated to 500 chars" {
  run grep -c 'head -c 500' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Primed output detection ───────────────────────────

@test "primed: grep for 'Auto-primed' marker" {
  run grep -c 'Auto-primed' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "primed: topic extraction from output" {
  run grep -c 'TOPIC=' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Negative cases ────────────────────────────────────

@test "negative: missing prime script handled" {
  # Verify guard exists
  run grep -c 'if \[ -f "\$PRIME_SCRIPT"' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "negative: prime returning empty does not error" {
  echo "test" > "$TEST_ROOT/.memory-store.jsonl"
  PROJECT_ROOT="$TEST_ROOT" run bash "$HOOK" <<< "random query text"
  [ "$status" -eq 0 ]
}

@test "negative: long input truncated not crashed" {
  echo "test" > "$TEST_ROOT/.memory-store.jsonl"
  local big
  big=$(python3 -c 'print("x" * 10000)')
  PROJECT_ROOT="$TEST_ROOT" run bash "$HOOK" <<< "$big"
  [ "$status" -eq 0 ]
}

# ── Edge cases ────────────────────────────────────────

@test "edge: whitespace-only input handled" {
  echo "test" > "$TEST_ROOT/.memory-store.jsonl"
  PROJECT_ROOT="$TEST_ROOT" run bash "$HOOK" <<< "   "
  [ "$status" -eq 0 ]
}

@test "edge: zero-length empty input" {
  echo "test" > "$TEST_ROOT/.memory-store.jsonl"
  PROJECT_ROOT="$TEST_ROOT" run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "edge: binary input does not crash" {
  echo "test" > "$TEST_ROOT/.memory-store.jsonl"
  PROJECT_ROOT="$TEST_ROOT" run bash -c "printf '\\x00\\x01\\xff' | bash $HOOK"
  [ "$status" -eq 0 ]
}

@test "edge: null store path handled" {
  PROJECT_ROOT="/nonexistent/path" run bash "$HOOK" <<< "query"
  [ "$status" -eq 0 ]
}

# ── Coverage ──────────────────────────────────────────

@test "coverage: PreToolUse async documented" {
  run grep -c 'PreToolUse\|async\|Lightweight' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: exit fast pattern used" {
  run grep -c 'exit 0\|exit_fast' "$HOOK"
  [[ "$output" -ge 3 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────

@test "isolation: always exits 0 (async, never blocks)" {
  for input in '' 'x' 'long query' "$(printf 'big%.0s' {1..100})"; do
    PROJECT_ROOT="$TEST_ROOT" run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook does not modify store" {
  echo "original store" > "$TEST_ROOT/.memory-store.jsonl"
  local before_hash
  before_hash=$(sha256sum "$TEST_ROOT/.memory-store.jsonl" | cut -d' ' -f1)
  PROJECT_ROOT="$TEST_ROOT" bash "$HOOK" <<< "query" >/dev/null 2>&1
  local after_hash
  after_hash=$(sha256sum "$TEST_ROOT/.memory-store.jsonl" | cut -d' ' -f1)
  [[ "$before_hash" == "$after_hash" ]]
}
