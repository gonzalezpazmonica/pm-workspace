#!/usr/bin/env bats
# test-se-073-memory-tier-rotate.bats — SE-073: 2-tier memory rotation
# Ref: docs/propuestas/SE-073-memory-index-cap-tiered.md
# Minimum 15 tests, target ≥80 score

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/memory-tier-rotate.sh"
  TMPDIR_MEM="$(mktemp -d)"
  export SAVIA_MEMORY_DIR="$TMPDIR_MEM"
  export MEMORY_DIR="$TMPDIR_MEM/auto"
  mkdir -p "$MEMORY_DIR"
}

teardown() {
  rm -rf "$TMPDIR_MEM"
}

# ── Helper ──────────────────────────────────────────────────────────────────
make_entry() {
  local name="$1" access_count="${2:-0}" last_access="${3:-2026-01-01}" pin="${4:-false}"
  cat > "$MEMORY_DIR/${name}.md" <<EOF
---
name: $name
description: test entry $name
access_count: $access_count
last_access: $last_access
pin: $pin
---
Content for $name
EOF
}

# ── Safety ──────────────────────────────────────────────────────────────────

@test "SE-073: script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "SE-073: set -uo pipefail present in script" {
  run grep -E "^set\s+.*-.*u.*pipefail|^set\s+.*-uo\s*pipefail|set -uo pipefail|set -euo pipefail" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Flag acceptance ─────────────────────────────────────────────────────────

@test "SE-073: --help flag works without error" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--dry-run"* ]]
}

@test "SE-073: --dry-run does not modify files" {
  make_entry alpha 5 "2026-06-01"
  make_entry beta  0 "2026-01-01"
  # No MEMORY.md should exist before
  [ ! -f "$MEMORY_DIR/MEMORY.md" ]
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  # MEMORY.md must NOT have been created
  [ ! -f "$MEMORY_DIR/MEMORY.md" ]
}

@test "SE-073: --dry-run does not modify MEMORY.md if it exists" {
  make_entry alpha 5 "2026-06-01"
  echo "existing content" > "$MEMORY_DIR/MEMORY.md"
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  # Content must be unchanged
  [[ "$(cat "$MEMORY_DIR/MEMORY.md")" == "existing content" ]]
}

@test "SE-073: --stats shows Tier A and Tier B counts" {
  make_entry freq_a  10 "2026-06-01"
  make_entry rare_b  0  "2026-01-01"
  run bash "$SCRIPT" --stats
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tier A"* ]]
  [[ "$output" == *"Tier B"* ]]
}

@test "SE-073: --status is an alias for --stats" {
  make_entry entry1 3 "2026-06-01"
  run bash "$SCRIPT" --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tier A"* ]]
}

# ── Rotation logic ──────────────────────────────────────────────────────────

@test "SE-073: rotation creates MEMORY.md" {
  make_entry myentry 5 "2026-06-01"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$MEMORY_DIR/MEMORY.md" ]
}

@test "SE-073: high-freq entries (access>=3 + recent) go to Tier A" {
  make_entry hf_entry 5 "2026-06-01"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "hf_entry" "$MEMORY_DIR/MEMORY.md"
}

@test "SE-073: low-freq old entries go to Tier B when cap exceeded" {
  # Create 31 entries: 30 high-freq + 1 low-freq
  for i in $(seq 1 30); do
    make_entry "hf_$(printf '%02d' $i)" 10 "2026-06-01"
  done
  make_entry "lf_old" 0 "2026-01-01"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  # MEMORY.md should have exactly 30 lines
  local count; count=$(wc -l < "$MEMORY_DIR/MEMORY.md")
  [ "$count" -eq 30 ]
  # MEMORY-ARCHIVE.md should contain the low-freq entry
  [ -f "$MEMORY_DIR/MEMORY-ARCHIVE.md" ]
  grep -q "lf_old" "$MEMORY_DIR/MEMORY-ARCHIVE.md"
}

@test "SE-073: hard cap 30 entries enforced in MEMORY.md" {
  # Create 35 entries all with same score
  for i in $(seq 1 35); do
    make_entry "entry_$(printf '%03d' $i)" 0 "2026-01-01"
  done
  MEMORY_TIER_A_CAP=30 run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  local count; count=$(wc -l < "$MEMORY_DIR/MEMORY.md")
  [ "$count" -le 30 ]
}

@test "SE-073: pinned entries (pin: true) always go to Tier A" {
  # Create 31 entries to force overflow, plus a pinned one
  for i in $(seq 1 30); do
    make_entry "high_$(printf '%02d' $i)" 10 "2026-06-01"
  done
  # Pinned entry with zero access (should still be Tier A due to pin bonus)
  make_entry "pinned_special" 0 "2026-01-01" "true"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "pinned_special" "$MEMORY_DIR/MEMORY.md"
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "SE-073: empty MEMORY_DIR is handled gracefully" {
  # No .md files in dir
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no hay memory files"* ]]
}

@test "SE-073: all entries in Tier A (no demotion needed)" {
  make_entry a1 5 "2026-06-01"
  make_entry a2 3 "2026-06-01"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$MEMORY_DIR/MEMORY.md" ]
  # Both should appear in MEMORY.md
  grep -q "a1" "$MEMORY_DIR/MEMORY.md"
  grep -q "a2" "$MEMORY_DIR/MEMORY.md"
}

@test "SE-073: MEMORY.md and MEMORY-ARCHIVE.md are excluded from rotation candidates" {
  # Even if MEMORY.md / MEMORY-ARCHIVE.md exist, they should not appear as entries
  echo "old index" > "$MEMORY_DIR/MEMORY.md"
  echo "old archive" > "$MEMORY_DIR/MEMORY-ARCHIVE.md"
  make_entry real_entry 5 "2026-06-01"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  # MEMORY.md should only contain real_entry, not MEMORY.md or MEMORY-ARCHIVE.md itself
  run grep -c "MEMORY" "$MEMORY_DIR/MEMORY.md"
  # The count of "MEMORY" in MEMORY.md should be 0 (no self-reference as entry)
  [ "$output" -eq 0 ]
}

@test "SE-073: SAVIA_MEMORY_DIR auto-creates auto/ subdir" {
  local newdir
  newdir="$(mktemp -d)"
  rm -rf "$newdir"  # remove so it doesn't exist
  SAVIA_MEMORY_DIR="$newdir" MEMORY_DIR="$newdir/auto" run bash "$SCRIPT"
  # Should succeed (creates dir, finds no files, exits cleanly)
  [ "$status" -eq 0 ]
  rm -rf "$newdir"
}
