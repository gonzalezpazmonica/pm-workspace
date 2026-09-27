#!/usr/bin/env bats
# Ref: docs/specs/SE-404-proportional-process-gates.spec.md (AC7-AC8)
# Una corrección por revisión: una segunda ronda de fix abre una revisión nueva.

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
  ROOT_REAL="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  COURT="$ROOT_REAL/scripts/court-review.sh"
  ROUTER="$ROOT_REAL/scripts/court-turn-router.sh"
  CRC="$TMPDIR/.review.crc"
}

teardown() { cd /; }

crc_with_rounds() { # $1 = number of fix rounds
  { echo "---"; echo "review_id: \"r1\""; echo "rounds:"
    for i in $(seq 1 "$1"); do echo "  - round: $i"; echo "    judges: [correctness]"; done
    [[ "$1" -eq 0 ]] && echo "  []"
    echo "---"; } > "$CRC"
}

@test "safety: court-review.sh keeps strict mode" {
  head -20 "$COURT" | grep -qE 'set -e?uo pipefail'
}

@test "AC7: both court-orchestrator definitions declare one fix round" {
  for f in "$ROOT_REAL/.claude/agents/court-orchestrator.md" "$ROOT_REAL/.opencode/agents/court-orchestrator.md"; do
    grep -q 'COURT_MAX_FIX_ROUNDS (1)' "$f" || { echo "missing in $f"; return 1; }
    ! grep -q 'max 3 rounds' "$f"
  done
}

@test "AC7: the court rule sets COURT_MAX_FIX_ROUNDS = 1 and requires previous_review" {
  grep -q '^COURT_MAX_FIX_ROUNDS = 1' "$ROOT_REAL/docs/rules/domain/code-review-court.md"
  grep -q 'previous_review' "$ROOT_REAL/docs/rules/domain/code-review-court.md"
}

@test "AC8: validate accepts a crc with zero or one fix round" {
  crc_with_rounds 0
  run bash "$COURT" validate "$CRC"
  [ "$status" -eq 0 ]
  crc_with_rounds 1
  run bash "$COURT" validate "$CRC"
  [ "$status" -eq 0 ]
}

@test "AC8: validate rejects a crc with two fix rounds" {
  crc_with_rounds 2
  run bash "$COURT" validate "$CRC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"2 fix rounds"* ]]
  [[ "$output" == *"new review"* ]]
}

@test "boundary: COURT_MAX_FIX_ROUNDS override is honoured by validate" {
  crc_with_rounds 2
  COURT_MAX_FIX_ROUNDS=2 run bash "$COURT" validate "$CRC"
  [ "$status" -eq 0 ]
}

@test "missing: validate of a nonexistent file exits 2" {
  run bash "$COURT" validate "$TMPDIR/nope.crc"
  [ "$status" -eq 2 ]
}

@test "empty: validate without argument exits 2" {
  run bash "$COURT" validate
  [ "$status" -eq 2 ]
}
