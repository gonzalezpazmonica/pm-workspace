#!/usr/bin/env bats
# Ref: SE-073 — MEMORY.md L1 hard-cap tiered (Slice 1)
# Strategy: tmp dir as MEMORY_DIR, synthesize memory files with controlled
# frontmatter, verify rotation produces correct Tier A/B partition.

setup() {
  TMPDIR=$(mktemp -d)
  export MEMORY_DIR="$TMPDIR"
  export MEMORY_TIER_A_CAP=3
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  ROTATE="$ROOT_DIR/scripts/memory-tier-rotate.sh"
  ACCESS="$ROOT_DIR/scripts/memory-access.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

# Helper: create a memory file with controlled frontmatter
make_mem() {
  local name="$1" access="${2:-0}" last="${3:-2020-01-01}" pin="${4:-}"
  {
    echo "---"
    echo "name: ${name}"
    echo "description: test ${name}"
    echo "type: feedback"
    echo "access_count: ${access}"
    echo "last_access: ${last}"
    [[ -n "$pin" ]] && echo "pin: ${pin}"
    echo "---"
    echo ""
    echo "Body of ${name}"
  } > "$TMPDIR/${name}.md"
}

@test "rotate: empty MEMORY_DIR exits 0 with no-op message" {
  run bash "$ROTATE" --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"no hay memory files"* ]]
}

@test "rotate: status mode is read-only (does not write MEMORY.md)" {
  make_mem "feedback_a" 0 "2020-01-01"
  run bash "$ROTATE" --status
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR/MEMORY.md" ]
}

@test "rotate: dry-run shows tier counts" {
  make_mem "a" 0 "2020-01-01"
  make_mem "b" 0 "2020-01-01"
  make_mem "c" 0 "2020-01-01"
  make_mem "d" 0 "2020-01-01"
  run bash "$ROTATE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"total files     : 4"* ]]
  [[ "$output" == *"Tier A (active) : 3"* ]]
  [[ "$output" == *"Tier B (archive): 1"* ]]
}

@test "rotate: writes MEMORY.md with Tier A entries (full description)" {
  make_mem "high" 5 "$(date -u +%Y-%m-%d)"
  make_mem "mid" 1 "$(date -u +%Y-%m-%d)"
  make_mem "low" 0 "2020-01-01"
  bash "$ROTATE" >/dev/null
  [ -f "$TMPDIR/MEMORY.md" ]
  grep -q "high.md" "$TMPDIR/MEMORY.md"
  grep -q "mid.md" "$TMPDIR/MEMORY.md"
  grep -q "test high" "$TMPDIR/MEMORY.md"
}

@test "rotate: high access_count entry ranks above low one" {
  make_mem "low_freq" 0 "2020-01-01"
  make_mem "high_freq" 10 "2020-01-01"
  MEMORY_TIER_A_CAP=1 bash "$ROTATE" >/dev/null
  grep -q "high_freq.md" "$TMPDIR/MEMORY.md"
  grep -q "low_freq.md" "$TMPDIR/MEMORY-ARCHIVE.md"
  ! grep -q "low_freq.md" "$TMPDIR/MEMORY.md"
}

@test "rotate: pin:true forces Tier A regardless of access" {
  make_mem "pinned" 0 "2020-01-01" "true"
  make_mem "active1" 5 "$(date -u +%Y-%m-%d)"
  make_mem "active2" 5 "$(date -u +%Y-%m-%d)"
  MEMORY_TIER_A_CAP=2 bash "$ROTATE" >/dev/null
  grep -q "pinned.md" "$TMPDIR/MEMORY.md"
}

@test "rotate: user_* prefix gets identity_bonus (Tier A)" {
  make_mem "user_identity" 0 "2020-01-01"
  make_mem "feedback_active" 5 "$(date -u +%Y-%m-%d)"
  MEMORY_TIER_A_CAP=1 bash "$ROTATE" >/dev/null
  grep -q "user_identity.md" "$TMPDIR/MEMORY.md"
  ! grep -q "feedback_active.md" "$TMPDIR/MEMORY.md"
}

@test "rotate: recency bonus applied for last_access < 30d" {
  local recent; recent=$(date -u -d '5 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-5d +%Y-%m-%d)
  make_mem "recent" 0 "$recent"
  make_mem "old" 0 "2020-01-01"
  MEMORY_TIER_A_CAP=1 bash "$ROTATE" >/dev/null
  grep -q "recent.md" "$TMPDIR/MEMORY.md"
}

@test "rotate: writes MEMORY-ARCHIVE.md with filename-only entries" {
  make_mem "a" 0 "2020-01-01"
  make_mem "b" 0 "2020-01-01"
  MEMORY_TIER_A_CAP=1 bash "$ROTATE" >/dev/null
  [ -f "$TMPDIR/MEMORY-ARCHIVE.md" ]
  grep -q "Tier B" "$TMPDIR/MEMORY-ARCHIVE.md"
  # filename-only format (no description after dash em)
  grep -E '^\- \[[a-z_]+\.md\]\([a-z_]+\.md\)$' "$TMPDIR/MEMORY-ARCHIVE.md"
}

@test "rotate: rejects unknown argument" {
  make_mem "a" 0 "2020-01-01"
  run bash "$ROTATE" --unknown-flag
  [ "$status" -eq 2 ]
}

@test "rotate: missing MEMORY_DIR exits 1 with clear error" {
  export MEMORY_DIR="$TMPDIR/does-not-exist"
  run bash "$ROTATE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no existe"* ]]
}

@test "rotate: ignores MEMORY.md, MEMORY-ARCHIVE.md, session-journal.md" {
  echo "should not be processed" > "$TMPDIR/MEMORY.md"
  echo "should not be processed" > "$TMPDIR/MEMORY-ARCHIVE.md"
  echo "should not be processed" > "$TMPDIR/session-journal.md"
  run bash "$ROTATE" --status
  [[ "$output" == *"total files     : 0"* ]] || [[ "$output" == *"no hay memory files"* ]]
}

@test "access: increments access_count from 0 to 1" {
  make_mem "tracked" 0 "2020-01-01"
  bash "$ACCESS" tracked.md
  grep -q "access_count: 1" "$TMPDIR/tracked.md"
}

@test "access: increments existing access_count" {
  make_mem "tracked" 4 "2020-01-01"
  bash "$ACCESS" tracked.md
  grep -q "access_count: 5" "$TMPDIR/tracked.md"
}

@test "access: updates last_access to today" {
  make_mem "tracked" 0 "2020-01-01"
  bash "$ACCESS" tracked.md
  local today; today=$(date -u +%Y-%m-%d)
  grep -q "last_access: ${today}" "$TMPDIR/tracked.md"
}

@test "access: fails on missing file" {
  run bash "$ACCESS" missing.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"no encontrado"* ]]
}

@test "access: fails on file without frontmatter" {
  echo "no frontmatter here" > "$TMPDIR/raw.md"
  run bash "$ACCESS" raw.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"no tiene frontmatter"* ]] || [[ "$output" == *"frontmatter"* ]]
}

@test "access: fails when called without arguments" {
  run bash "$ACCESS"
  [ "$status" -eq 2 ]
}

@test "rotate + access: integration — bumping access promotes Tier" {
  make_mem "candidate" 0 "2020-01-01"
  make_mem "incumbent" 1 "$(date -u +%Y-%m-%d)"
  MEMORY_TIER_A_CAP=1 bash "$ROTATE" >/dev/null
  grep -q "incumbent.md" "$TMPDIR/MEMORY.md"
  # Now bump candidate access count past incumbent
  for i in 1 2 3 4 5 6; do bash "$ACCESS" candidate.md >/dev/null; done
  MEMORY_TIER_A_CAP=1 bash "$ROTATE" >/dev/null
  grep -q "candidate.md" "$TMPDIR/MEMORY.md"
}

@test "rotate: scripts/memory-tier-rotate.sh has set safety flags" {
  grep -q 'set -[uo]*o pipefail' "$ROTATE"
}

@test "access: scripts/memory-access.sh has set safety flags" {
  grep -q 'set -[uo]*o pipefail' "$ACCESS"
}

@test "edge: rotate respects MEMORY_TIER_A_CAP=1" {
  make_mem "a" 0 "2020-01-01"
  make_mem "b" 0 "2020-01-01"
  make_mem "c" 0 "2020-01-01"
  MEMORY_TIER_A_CAP=1 bash "$ROTATE" >/dev/null
  local count; count=$(wc -l < "$TMPDIR/MEMORY.md")
  [ "$count" -eq 1 ]
}

@test "edge: rotate handles file with truncated description (>150 chars)" {
  {
    echo "---"
    echo "name: long"
    echo "description: $(printf 'x%.0s' {1..200})"
    echo "type: feedback"
    echo "access_count: 0"
    echo "last_access: 2020-01-01"
    echo "---"
    echo "body"
  } > "$TMPDIR/long.md"
  bash "$ROTATE" >/dev/null
  grep -q "\.\.\." "$TMPDIR/MEMORY.md"
}

@test "spec ref: SE-073 documented in script header" {
  grep -q "SE-073" "$ROTATE"
  grep -q "SE-073" "$ACCESS"
}
