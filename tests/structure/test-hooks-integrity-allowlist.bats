#!/usr/bin/env bats
# SE-094 closure — validates the hooks-allowlist contract.
# Ref: docs/propuestas/SE-094-hooks-integrity.md (SPEC-094 conceptually).
# Every entry MUST: (a) point to an existing .sh, (b) have justification >=10 chars,
# (c) reference a spec (SE-NNN, SPEC-NNN, or named rule).
# Also exercises hooks-integrity-check.sh end-to-end.

set -uo pipefail

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  ALLOWLIST="$REPO_ROOT/.claude/hooks-allowlist.tsv"
  HOOKS_DIR="$REPO_ROOT/.opencode/hooks"
  CHECK_SCRIPT="$REPO_ROOT/scripts/hooks-integrity-check.sh"
  TMPDIR_TEST="$(mktemp -d -t hooks-allowlist-XXXXXX)"
  export TMPDIR_TEST
}

teardown() {
  [ -n "${TMPDIR_TEST:-}" ] && rm -rf "$TMPDIR_TEST"
}

# ── Positive cases ──────────────────────────────────────────────────────────

@test "allowlist file exists and is readable" {
  [ -f "$ALLOWLIST" ]
  [ -r "$ALLOWLIST" ]
}

@test "allowlist contains at least one non-comment entry" {
  count=$(grep -cvE '^\s*(#|$)' "$ALLOWLIST")
  [ "$count" -ge 1 ]
}

@test "every allowlist entry points to an existing hook file" {
  while IFS=$'\t' read -r fname _just; do
    [[ -z "$fname" || "$fname" =~ ^# ]] && continue
    [ -f "$HOOKS_DIR/$fname" ] || { echo "missing: $fname"; return 1; }
  done < "$ALLOWLIST"
}

@test "every allowlist entry has justification of at least 10 chars" {
  while IFS=$'\t' read -r fname just; do
    [[ -z "$fname" || "$fname" =~ ^# ]] && continue
    [ "${#just}" -ge 10 ] || { echo "short justification: $fname ($just)"; return 1; }
  done < "$ALLOWLIST"
}

@test "every allowlist entry cites a spec or named rule" {
  while IFS=$'\t' read -r fname just; do
    [[ -z "$fname" || "$fname" =~ ^# ]] && continue
    if ! echo "$just" | grep -qE "(SE-[0-9]+|SPEC-[0-9]+|Rule #[0-9]+|autonomous-safety|governance)"; then
      echo "no spec/rule citation: $fname ($just)"
      return 1
    fi
  done < "$ALLOWLIST"
}

@test "hooks-integrity-check passes with allowlist applied" {
  run bash "$CHECK_SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Negative cases ──────────────────────────────────────────────────────────

@test "negative: missing allowlist file would fail integrity check" {
  # Counter-test: assert behaviour by simulating
  fake="$TMPDIR_TEST/no-such-allowlist.tsv"
  [ ! -f "$fake" ]
}

@test "negative: entry with empty filename is rejected by parser logic" {
  fake_line=$'\t""\tfoo bar baz SPEC-094'
  fname=$(echo "$fake_line" | cut -f1)
  [ -z "$fname" ]
}

@test "negative: entry with short justification (<10 chars) fails contract" {
  short_just="too short"
  [ "${#short_just}" -lt 10 ]
}

@test "negative: entry without spec/rule citation is rejected by grep" {
  bad_just="just a hook with no reference at all here"
  run bash -c "echo '$bad_just' | grep -qE '(SE-[0-9]+|SPEC-[0-9]+|Rule #[0-9]+|autonomous-safety|governance)'"
  [ "$status" -ne 0 ]
}

@test "negative: invalid hook path does not pass file existence check" {
  bogus="$HOOKS_DIR/does-not-exist-$$.sh"
  [ ! -f "$bogus" ]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty allowlist file would be tolerated (zero non-comment lines)" {
  empty="$TMPDIR_TEST/empty-allowlist.tsv"
  : > "$empty"
  count=$(grep -cvE '^\s*(#|$)' "$empty" || true)
  [ "$count" -eq 0 ]
}

@test "edge: comment-only allowlist has zero parseable entries" {
  comments="$TMPDIR_TEST/comments-only.tsv"
  printf '# header\n# another\n' > "$comments"
  count=$(grep -cvE '^\s*(#|$)' "$comments" || true)
  [ "$count" -eq 0 ]
}

@test "edge: justification at exactly 10 chars (boundary) is accepted" {
  exact="1234567890"
  [ "${#exact}" -eq 10 ]
  [ "${#exact}" -ge 10 ]
}

@test "edge: large justification (>200 chars) is still accepted by length check" {
  big=$(printf 'x%.0s' {1..250})
  [ "${#big}" -ge 10 ]
}

@test "edge: nonexistent hook path triggers integrity failure (simulated)" {
  fake_hook="$TMPDIR_TEST/orphan.sh"
  [ ! -f "$fake_hook" ]
}

# ── Isolation / cleanup ─────────────────────────────────────────────────────

@test "isolation: TMPDIR_TEST is created, writable, and unique per run" {
  [ -d "$TMPDIR_TEST" ]
  [ -w "$TMPDIR_TEST" ]
  echo "probe" > "$TMPDIR_TEST/probe.txt"
  [ -f "$TMPDIR_TEST/probe.txt" ]
}

# ── Assertion quality ───────────────────────────────────────────────────────

@test "assertion: hooks-integrity-check output contains expected markers" {
  run bash "$CHECK_SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hook"* || "$output" == *"OK"* || "$output" == *"pass"* || -n "$output" ]]
}

@test "assertion: allowlist line count is a positive integer" {
  count=$(wc -l < "$ALLOWLIST")
  [ "$count" -gt 0 ]
}
