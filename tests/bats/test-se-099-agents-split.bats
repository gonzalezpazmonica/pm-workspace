#!/usr/bin/env bats
# tests/bats/test-se-099-agents-split.bats — SE-099 Agent oversized audit
# Verifies: no FAIL violations in agents-size-checker, references/ valid, script works.
#
# Ref: docs/propuestas/SE-099-agents-oversized-rest.md
# Note: SE-099 documents that NO agents exceed the 200-line WARN threshold.
#       All SLA_WARN violations are byte-based (>4096B), not line-based.

SCRIPT="$(git rev-parse --show-toplevel)/scripts/agents-size-checker.sh"
REFERENCES_DIR="$(git rev-parse --show-toplevel)/.opencode/agents/references"

# ── Test 1: agents-size-checker.sh exists and is parseable ───────────────────
@test "SE-099-01: agents-size-checker.sh exists and is bash-parseable" {
  [ -f "$SCRIPT" ]
  bash -n "$SCRIPT"
}

# ── Test 2: Script produces output ───────────────────────────────────────────
@test "SE-099-02: agents-size-checker.sh produces output" {
  run bash "$SCRIPT" 2>/dev/null
  [ -n "$output" ]
}

# ── Test 3: No agents exceed 400-line FAIL threshold ─────────────────────────
@test "SE-099-03: no agents emit FAIL (>400 lines)" {
  run bash "$SCRIPT" 2>/dev/null
  # Exit code 0 means no FAIL violations
  [ "$status" -eq 0 ]
}

# ── Test 4: No agents exceed 200-line WARN threshold ─────────────────────────
@test "SE-099-04: no agents exceed 200-line WARN threshold" {
  # Column 2 is LINES. Skip header and summary lines.
  # An agent is over the line-WARN threshold if LINES (col2) > 200.
  hard_warn=$(bash "$SCRIPT" 2>/dev/null | awk 'NR>2 && $2~/^[0-9]+$/ && $2+0 > 200 {print $0}' | wc -l)
  [ "$hard_warn" -eq 0 ]
}

# ── Test 5: references/ directory exists ─────────────────────────────────────
@test "SE-099-05: .opencode/agents/references/ directory exists" {
  [ -d "$REFERENCES_DIR" ]
}

# ── Test 6: references/ contains only valid markdown files ───────────────────
@test "SE-099-06: all files in references/ are non-empty markdown" {
  # Skip if directory is empty
  ref_files=("$REFERENCES_DIR"/*.md)
  if [[ ! -f "${ref_files[0]}" ]]; then
    skip "references/ directory is empty (no agents were split)"
  fi
  for f in "$REFERENCES_DIR"/*.md; do
    [ -s "$f" ]   # non-empty
    [[ "$f" == *.md ]]
  done
}

# ── Test 7: Total WARN+FAIL count is deterministic ───────────────────────────
@test "SE-099-07: agents-size-checker.sh output ends with summary line" {
  run bash "$SCRIPT" 2>/dev/null
  [[ "$output" == *"Total:"* ]]
}
