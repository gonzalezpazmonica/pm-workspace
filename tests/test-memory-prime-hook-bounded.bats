#!/usr/bin/env bats
# BATS tests for .claude/hooks/memory-prime-hook.sh bounded concurrency
# Ref: docs/rules/domain/bounded-concurrency.md
# Origin: Bluesky outage 2026-04-14 (arXiv N/A — post-mortem blog) + pm-workspace
# fork bomb 2026-04-18. SPEC-055 quality gate.
#
# Verifies the hardening applied in 2026-04-18: explicit MAX_PARALLEL + wait-drain
# instead of implicit upstream bound. Defense in depth even if --top 3 changes.

HOOK=".claude/hooks/memory-prime-hook.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "memory-prime-hook.sh exists and is readable" {
  [[ -f "$HOOK" ]]
  [[ -r "$HOOK" ]]
}

@test "memory-prime-hook.sh uses set -uo pipefail" {
  run head -10 "$HOOK"
  [[ "$output" == *"set -uo pipefail"* ]]
}

@test "memory-prime-hook.sh has valid bash syntax" {
  run bash -n "$HOOK"
  [ "$status" -eq 0 ]
}

@test "memory-prime-hook.sh has shebang" {
  run head -1 "$HOOK"
  [[ "$output" == "#!"* ]]
}

# ── Bounded concurrency contract ───────────────────────────────────────────

@test "MAX_PARALLEL is defined with numeric value" {
  run grep -E "^MAX_PARALLEL=[0-9]+" "$HOOK"
  [ "$status" -eq 0 ]
}

@test "MAX_PARALLEL is ≤ 10 (reasonable upper bound for hook fan-out)" {
  local val; val=$(grep -oP '^MAX_PARALLEL=\K[0-9]+' "$HOOK" | head -1)
  [[ -n "$val" ]]
  [[ "$val" -le 10 ]]
}

@test "MAX_PARALLEL is ≥ 1 (not accidentally zero)" {
  local val; val=$(grep -oP '^MAX_PARALLEL=\K[0-9]+' "$HOOK" | head -1)
  [[ "$val" -ge 1 ]]
}

@test "semaphore pattern uses jobs -rp count" {
  run grep -c "jobs -rp" "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "semaphore pattern uses wait -n to release slot" {
  run grep -c "wait -n" "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "final wait drain before exit (no zombies)" {
  # A final 'wait' (no args) before exit 0 drains any outstanding background work
  run grep -c '^\s*wait\s*2>/dev/null\|^\s*wait\s*$' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "doctrine document is referenced in the hook" {
  # Hook comments must point to the doctrine so future editors find the why
  run grep -c "bounded-concurrency" "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: no unbounded & (python3 spawn) outside semaphore guard" {
  # Count python3 ... & lines; they must be preceded within 10 lines by the
  # "jobs -rp ... MAX_PARALLEL" semaphore check.
  local python_bg_lines; python_bg_lines=$(grep -n "python3.*&$" "$HOOK" | head -5)
  if [[ -z "$python_bg_lines" ]]; then
    # No background python3 calls is also safe — hook was simplified or refactored
    skip "no background python3 calls detected — hook may have been simplified"
  fi
  # Check: within 15 lines before the & line, there is a MAX_PARALLEL guard
  while IFS= read -r line; do
    local ln; ln=$(echo "$line" | cut -d: -f1)
    local guard_start=$((ln > 15 ? ln - 15 : 1))
    local preceding; preceding=$(sed -n "${guard_start},$((ln - 1))p" "$HOOK")
    [[ "$preceding" == *"MAX_PARALLEL"* ]] || {
      echo "FAIL: python3 background spawn at line $ln not guarded by MAX_PARALLEL above" >&2
      return 1
    }
  done <<< "$python_bg_lines"
}

@test "negative: regression — no raw while-read-with-& without semaphore" {
  # Locate each "while read" loop; if any has a '&' line inside, it must be
  # guarded by the MAX_PARALLEL semaphore pattern
  run grep -A20 "while read" "$HOOK"
  # Just check the pattern isn't present without guard (soft check)
  if [[ "$output" == *"&"* ]]; then
    [[ "$output" == *"MAX_PARALLEL"* || "$output" == *"jobs -rp"* ]]
  fi
}

@test "negative: broken bash -n would be caught" {
  local bad="$BATS_TEST_TMPDIR/bad.sh"
  echo 'if then fi' > "$bad"
  run bash -n "$bad"
  [ "$status" -ne 0 ]
}

@test "negative: missing MAX_PARALLEL would be caught" {
  # If the hardening regresses and MAX_PARALLEL vanishes, earlier tests fire
  run grep -c "MAX_PARALLEL" "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "negative: missing bounded-concurrency doc reference would be caught" {
  # The doctrine pointer is part of the contract; if someone deletes it,
  # future readers lose the why.
  [[ -f "docs/rules/domain/bounded-concurrency.md" ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: hook exits fast when no store present" {
  # Simulate: no store file → hook exits 0 (quick path)
  run bash -c "PROJECT_ROOT='$BATS_TEST_TMPDIR/empty' bash '$HOOK' <<< ''"
  [ "$status" -eq 0 ]
}

@test "edge: hook has python3 missing-guard (command -v python3 || exit 0)" {
  # Static check: the hook must have an early exit when python3 is missing.
  # Runtime simulation is brittle (PATH stripping breaks bash itself), so verify
  # the guard exists via source inspection.
  run grep -c "command -v python3" "$HOOK"
  [[ "$output" -ge 1 ]]
  # And the guard must be coupled with an exit 0 (not a fail)
  run grep -cE "command -v python3.*exit 0|python3.*>/dev/null.*exit 0" "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "edge: empty stdin input does not crash" {
  run bash -c "bash '$HOOK' < /dev/null"
  [ "$status" -eq 0 ]
}

@test "edge: very long query is truncated to 500 chars via head -c" {
  # Verify the `head -c 500` safety in the query extraction
  run grep -c 'head -c 500' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "edge: boundary — semaphore releases (wait -n returns) when job completes" {
  # Smoke test the bash semaphore pattern in isolation
  run bash -c '
    MAX=2; for i in 1 2 3 4 5; do
      while [ "$(jobs -rp | wc -l)" -ge "$MAX" ]; do wait -n 2>/dev/null || break; done
      (sleep 0.05) &
    done
    wait 2>/dev/null || true
    echo "ok"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "edge: nonexistent hook path triggers bash error" {
  run bash /tmp/nonexistent-hook-path-memory-prime-12345.sh
  [ "$status" -ne 0 ]
}
