#!/usr/bin/env bats
# Ref: SE-074 Slice 3 — parallel-specs-cleanup-stale.sh

setup() {
  ROOT_DIR_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$ROOT_DIR_REAL/scripts/parallel-specs-cleanup-stale.sh"

  # Build an isolated git repo with a worktrees subdirectory
  REPO=$(mktemp -d)
  cd "$REPO"
  git init -q -b main
  git config user.email "t@t"
  git config user.name "t"
  echo "# r" > README.md
  git add README.md
  git commit -q -m init

  WT_DIR="$REPO/.claude/worktrees"
  mkdir -p "$WT_DIR"
  export PROJECT_ROOT="$REPO"
  export WORKTREES_DIR="$WT_DIR"
  export MAIN_BRANCH="main"
}

teardown() {
  cd /
  rm -rf "$REPO"
}

# Helper: create a fresh worktree on a branch derived from main
make_worktree() {
  local name="$1"
  git -C "$REPO" worktree add -q -b "agent/${name}" "$WT_DIR/${name}" main
}

# Helper: backdate a path so it appears stale (uses touch -d)
backdate_hours() {
  local path="$1" hours="$2"
  touch -d "${hours} hours ago" "$path"
}

# ── Usage / dispatch ─────────────────────────────────────────────────────────

@test "cleanup: --help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "cleanup: rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "cleanup: list mode is the default" {
  make_worktree foo
  backdate_hours "$WT_DIR/foo" 48
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stale"* ]]
}

@test "cleanup: empty WORKTREES_DIR exits 0 with friendly message" {
  rm -rf "$WT_DIR"
  WORKTREES_DIR="$REPO/missing" run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"no worktrees directory"* ]]
}

# ── Stale detection ─────────────────────────────────────────────────────────

@test "cleanup: detects stale worktree past threshold" {
  make_worktree stale
  backdate_hours "$WT_DIR/stale" 48
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"stale: $WT_DIR/stale"* ]]
}

@test "cleanup: skips fresh worktree below threshold" {
  make_worktree fresh
  # Default mtime is now → should be too young
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"keep:"* ]]
  [[ "$output" == *"below threshold"* ]]
}

# ── Refusal cases ───────────────────────────────────────────────────────────

@test "cleanup: REFUSES worktree with uncommitted changes" {
  make_worktree dirty
  echo "wip" > "$WT_DIR/dirty/scratch.txt"
  backdate_hours "$WT_DIR/dirty" 48
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"keep:"* ]]
  [[ "$output" == *"uncommitted"* ]]
}

@test "cleanup: REFUSES worktree with commits ahead of main and no upstream" {
  make_worktree ahead
  cd "$WT_DIR/ahead"
  echo "more" > extra.txt
  git add extra.txt
  git -c user.email=t@t -c user.name=t commit -q -m "extra"
  cd "$REPO"
  backdate_hours "$WT_DIR/ahead" 48
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"keep:"* ]]
  [[ "$output" == *"commits ahead"* ]]
}

@test "cleanup: respects .do-not-clean sentinel" {
  make_worktree pinned
  touch "$WT_DIR/pinned/.do-not-clean"
  backdate_hours "$WT_DIR/pinned" 48
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"do-not-clean"* ]]
}

@test "cleanup: respects active worker pidfile" {
  make_worktree busy
  echo $$ > "$WT_DIR/busy/.parallel-spec-running.pid"
  backdate_hours "$WT_DIR/busy" 48
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"active worker"* ]]
}

# ── --confirm + prune behaviour ─────────────────────────────────────────────

@test "cleanup: prune without --confirm is the same as list" {
  make_worktree to-prune
  backdate_hours "$WT_DIR/to-prune" 48
  run bash "$SCRIPT" prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"running list mode instead"* ]]
  # Worktree must still exist
  [ -d "$WT_DIR/to-prune" ]
}

@test "cleanup: prune --confirm actually removes a stale worktree" {
  make_worktree disposable
  backdate_hours "$WT_DIR/disposable" 48
  run bash "$SCRIPT" prune --confirm
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed:"* ]]
  [ ! -d "$WT_DIR/disposable" ]
}

@test "cleanup: prune --confirm leaves dirty worktrees alone" {
  make_worktree dirty
  echo "wip" > "$WT_DIR/dirty/scratch.txt"
  backdate_hours "$WT_DIR/dirty" 48
  run bash "$SCRIPT" prune --confirm
  [ "$status" -eq 0 ]
  [ -d "$WT_DIR/dirty" ]   # NOT removed
}

# ── Threshold / foot-gun ───────────────────────────────────────────────────

@test "cleanup: --threshold-hours 0 rejected (foot-gun guard)" {
  run bash "$SCRIPT" list --threshold-hours 0
  [ "$status" -eq 2 ]
  [[ "$output" == *"≥ 1"* ]]
}

@test "cleanup: --threshold-hours non-numeric rejected" {
  run bash "$SCRIPT" list --threshold-hours abc
  [ "$status" -eq 2 ]
}

# ── Static / safety / spec ref ──────────────────────────────────────────────

@test "spec ref: SE-074 Slice 3 cited in script header" {
  grep -q "SE-074 Slice 3" "$SCRIPT"
}

@test "safety: cleanup-stale.sh has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: cleanup-stale.sh never invokes git push or remote branch deletion" {
  ! grep -E '^[^#]*git[[:space:]]+push' "$SCRIPT"
  ! grep -E '^[^#]*git[[:space:]]+push[[:space:]]+--delete' "$SCRIPT"
}

@test "safety: cleanup-stale.sh has path traversal guard" {
  grep -qE 'path outside WORKTREES_DIR' "$SCRIPT"
}
