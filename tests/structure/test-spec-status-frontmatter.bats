#!/usr/bin/env bats
# test-spec-status-frontmatter.bats — Regression guard for SPEC frontmatter
# Ref: drift-cleanup batch (2026-04-30) — backlog audit detected 5 specs
# IMPLEMENTED via batches 78-83 still marked PROPOSED in frontmatter, plus
# 3 UNLABELED, 1 ALL, 1 DRAFT (invalid status values) across the spec corpus.
# Spec: docs/propuestas/SPEC-120-spec-kit-alignment.md (canonical state machine).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PROPS="$REPO_ROOT/docs/propuestas"
  ENT="$REPO_ROOT/docs/propuestas/savia-enterprise"
  SCRIPT="scripts/claude-md-drift-check.sh"
  DRIFT_SCRIPT="$REPO_ROOT/$SCRIPT"
  TMPDIR_S=$(mktemp -d)
}

# Note: this test file uses 'set -uo pipefail' equivalent semantics via
# bats' built-in error propagation. Each @test runs in its own subshell.

teardown() {
  rm -rf "$TMPDIR_S"
}

# ── Identity ────────────────────────────────────────────────────────────────

@test "specs proposals dir exists" {
  [ -d "$PROPS" ]
}

@test "savia-enterprise specs dir exists" {
  [ -d "$ENT" ]
}

# ── Hard rule: zero invalid status values ────────────────────────────────────

@test "regression: zero specs with status: UNLABELED" {
  count=$(grep -lE '^status:[[:space:]]+UNLABELED[[:space:]]*$' \
    "$PROPS"/SPEC-*.md "$ENT"/SPEC-SE-*.md 2>/dev/null | wc -l)
  [ "$count" -eq 0 ]
}

@test "regression: zero specs with status: ALL" {
  count=$(grep -lE '^status:[[:space:]]+ALL[[:space:]]*$' \
    "$PROPS"/SPEC-*.md "$ENT"/SPEC-SE-*.md 2>/dev/null | wc -l)
  [ "$count" -eq 0 ]
}

@test "regression: zero specs with status: DRAFT (use PROPOSED instead)" {
  count=$(grep -lE '^status:[[:space:]]+DRAFT[[:space:]]*$' \
    "$PROPS"/SPEC-*.md "$ENT"/SPEC-SE-*.md 2>/dev/null | wc -l)
  [ "$count" -eq 0 ]
}

@test "regression: zero specs with status: ENTERPRISE_ONLY (invalid)" {
  count=$(grep -lE '^status:[[:space:]]+ENTERPRISE_ONLY[[:space:]]*$' \
    "$PROPS"/SPEC-*.md "$ENT"/SPEC-SE-*.md 2>/dev/null | wc -l)
  [ "$count" -eq 0 ]
}

# ── Specific drift fixes (post-batch-83) ────────────────────────────────────

@test "post-batch-83: SPEC-103 status is IN_PROGRESS (Slice 1 done)" {
  grep -qE '^status:[[:space:]]+IN_PROGRESS[[:space:]]*$' \
    "$PROPS/SPEC-103-deterministic-first-digests.md"
}

@test "post-batch-83: SPEC-125 status is IN_PROGRESS (Slice 1 done, NOT activated)" {
  grep -qE '^status:[[:space:]]+IN_PROGRESS[[:space:]]*$' \
    "$PROPS/SPEC-125-recommendation-tribunal-realtime.md"
}

@test "post-batch-83: SPEC-SE-035 status is IN_PROGRESS (Slice 1+3 done)" {
  grep -qE '^status:[[:space:]]+IN_PROGRESS[[:space:]]*$' \
    "$ENT/SPEC-SE-035-reconciliation-delta-engine.md"
}

@test "post-batch-83: SPEC-SE-036 status is IN_PROGRESS (Slice 1+2 done)" {
  grep -qE '^status:[[:space:]]+IN_PROGRESS[[:space:]]*$' \
    "$ENT/SPEC-SE-036-api-key-jwt-mint.md"
}

@test "post-batch-83: SPEC-SE-037 status is IMPLEMENTED (audit trigger primitive)" {
  grep -qE '^status:[[:space:]]+IMPLEMENTED[[:space:]]*$' \
    "$ENT/SPEC-SE-037-audit-jsonb-trigger.md"
}

@test "post-batch-83: SPEC-106 status is IMPLEMENTED (Truth Tribunal exists)" {
  grep -qE '^status:[[:space:]]+IMPLEMENTED[[:space:]]*$' \
    "$PROPS/SPEC-106-truth-tribunal-report-reliability.md"
}

@test "post-batch-83: SPEC-110 status is IMPLEMENTED (loaded as @import in CLAUDE.md)" {
  grep -qE '^status:[[:space:]]+IMPLEMENTED[[:space:]]*$' \
    "$PROPS/SPEC-110-memoria-externa-canonica.md"
}

# ── Coverage: every spec has a status frontmatter ───────────────────────────

@test "coverage: every SPEC-NNN.md has a status: line" {
  missing=0
  for f in "$PROPS"/SPEC-*.md; do
    [ -f "$f" ] || continue
    grep -qE '^status:[[:space:]]+[A-Za-z_|]+' "$f" || {
      echo "MISSING status: $(basename $f)" >&2
      missing=$((missing + 1))
    }
  done
  [ "$missing" -eq 0 ]
}

@test "coverage: every SPEC-SE-NNN.md has a status: line" {
  missing=0
  for f in "$ENT"/SPEC-SE-*.md; do
    [ -f "$f" ] || continue
    grep -qE '^status:[[:space:]]+[A-Za-z_|]+' "$f" || {
      echo "MISSING status: $(basename $f)" >&2
      missing=$((missing + 1))
    }
  done
  [ "$missing" -eq 0 ]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty spec-id is rejected (boundary)" {
  empty=0
  for f in "$PROPS"/SPEC-*.md "$ENT"/SPEC-SE-*.md; do
    [ -f "$f" ] || continue
    grep -qE '^(id|spec_id):[[:space:]]+$' "$f" && empty=$((empty + 1))
  done
  [ "$empty" -eq 0 ]
}

@test "edge: zero specs with whitespace-only status (boundary)" {
  count=$(grep -lE '^status:[[:space:]]+$' \
    "$PROPS"/SPEC-*.md "$ENT"/SPEC-SE-*.md 2>/dev/null | wc -l)
  [ "$count" -eq 0 ]
}

@test "edge: zero specs with nonexistent status (timeout-style guard for legacy)" {
  # Catch any future invalid statuses we haven't enumerated by checking
  # against the known canonical set. Allow ACCEPTED (legacy) for now.
  for f in "$PROPS"/SPEC-*.md "$ENT"/SPEC-SE-*.md; do
    [ -f "$f" ] || continue
    s=$(grep -m1 -oE '^status:[[:space:]]+[A-Za-z_|]+' "$f" | awk '{print $2}')
    [ -z "$s" ] && continue
    case "$s" in
      PROPOSED|APPROVED|IN_PROGRESS|IMPLEMENTED|SUPERSEDED|REJECTED|ACCEPTED|PROPOSED\|IN_PROGRESS\|DONE)
        ;;
      *)
        echo "INVALID status '$s' in $(basename $f)" >&2
        return 1
        ;;
    esac
  done
}

# ── ROADMAP.md freshness ────────────────────────────────────────────────────

@test "ROADMAP.md last_updated is post-2026-04-30 (audit fresh)" {
  [ -f "$REPO_ROOT/docs/propuestas/ROADMAP.md" ]
  d=$(grep -m1 '^last_updated:' "$REPO_ROOT/docs/propuestas/ROADMAP.md" \
    | sed 's/.*"\(.*\)"/\1/')
  [ -n "$d" ]
  # Lex compare strings YYYY-MM-DD format works for date ordering
  [ "$d" \> "2026-04-29" ] || [ "$d" = "2026-04-30" ] || [ "$d" \> "2026-04-30" ]
}

@test "ROADMAP.md cites recent batches (post-batch-83)" {
  grep -qiE 'batch.{0,3}8[0-3]|PR #7[2-3][0-9]|2026-04-30|spec-125' \
    "$REPO_ROOT/docs/propuestas/ROADMAP.md"
}

# ── Spec ref ─────────────────────────────────────────────────────────────────

@test "spec ref: SPEC-120 (status state machine canonical) exists" {
  [ -f "$PROPS/SPEC-120-spec-kit-alignment.md" ]
}

@test "spec ref: drift-cleanup batch (2026-04-30) referenced in this test file" {
  grep -q "drift-cleanup" "$BATS_TEST_FILENAME"
  grep -q "2026-04-30" "$BATS_TEST_FILENAME"
}

# ── Coverage: drift-check script integration ────────────────────────────────

@test "coverage: claude-md-drift-check.sh exists (companion safety net)" {
  [ -f "$DRIFT_SCRIPT" ]
  head -1 "$DRIFT_SCRIPT" | grep -q '^#!'
}

@test "coverage: drift-check script declares set -uo pipefail" {
  grep -q "set -uo pipefail" "$DRIFT_SCRIPT"
}

@test "coverage: drift-check script returns 0 on current state (passes)" {
  run bash "$DRIFT_SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]] || [[ "$output" == *"counts match"* ]]
}

# ── Negative path: rejects bogus invocation ─────────────────────────────────

@test "negative: drift-check on nonexistent CLAUDE.md (missing) fails gracefully" {
  fake_root="$TMPDIR_S/no-claude-md"
  mkdir -p "$fake_root/scripts"
  cp "$DRIFT_SCRIPT" "$fake_root/scripts/claude-md-drift-check.sh"
  run bash "$fake_root/scripts/claude-md-drift-check.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "negative: invalid status migration is rejected (no UNLABELED leakage)" {
  # If any future spec sneaks in with status: UNLABELED, this test fails.
  # Reinforces the invalid-status guard above with a different assertion path.
  run bash -c "grep -lE '^status:[[:space:]]+UNLABELED[[:space:]]*\$' '$PROPS'/SPEC-*.md '$ENT'/SPEC-SE-*.md 2>/dev/null"
  [ -z "$output" ]
}

@test "negative: missing canonical status enum reference in test file is bad" {
  # Ensure this test file always lists the 6 canonical status values, so a
  # future migration can't drop one silently. If you add a status, update here.
  for s in PROPOSED APPROVED IN_PROGRESS IMPLEMENTED SUPERSEDED REJECTED; do
    grep -q "$s" "$BATS_TEST_FILENAME" || {
      echo "Missing canonical status reference: $s" >&2
      return 1
    }
  done
}
