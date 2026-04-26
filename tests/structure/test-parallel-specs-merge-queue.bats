#!/usr/bin/env bats
# Ref: SE-074 Slice 2 — parallel-specs-merge-queue.sh

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/parallel-specs-merge-queue.sh"

  # Isolated git repo per test
  REPO=$(mktemp -d)
  cd "$REPO"
  git init -q -b main
  git config user.email "test@savia.local"
  git config user.name "Savia Test"
  echo "# repo" > README.md
  git add README.md
  git commit -q -m "init"

  # Keep the queue file outside the repo so it never trips the dirty-tree gate
  QUEUE_FILE=$(mktemp -u --tmpdir parallel-merge-queue.XXXXXX)
  export QUEUE_FILE
  export PROJECT_ROOT="$REPO"
}

teardown() {
  cd /
  rm -rf "$REPO"
  rm -f "$QUEUE_FILE"
}

# Helper: create a branch from main with a single fragment commit
make_branch_with_fragment() {
  local branch="$1" fragname="$2" body="${3:-changelog body}"
  git checkout -q -b "$branch" main
  mkdir -p CHANGELOG.d
  printf "## [%s] — 2026-04-26\n\n%s\n" "$fragname" "$body" > "CHANGELOG.d/${fragname}.md"
  git add "CHANGELOG.d/${fragname}.md"
  git commit -q -m "feat: add ${fragname}"
  git checkout -q main
}

# Helper: create a branch that ALSO touches CHANGELOG.md (the rebase-conflict scenario)
make_branch_touching_changelog_md() {
  local branch="$1" line="$2"
  git checkout -q -b "$branch" main
  echo "$line" >> CHANGELOG.md
  git add CHANGELOG.md
  git commit -q -m "feat: bump CHANGELOG ($line)"
  git checkout -q main
}

# Helper: bump main forward with a CHANGELOG.md change so the branch will conflict
bump_main_changelog() {
  local line="$1"
  git checkout -q main
  echo "$line" >> CHANGELOG.md
  git add CHANGELOG.md
  git commit -q -m "main: bump ${line}"
}

# Helper: real (non-CHANGELOG) divergence so we test escalation
make_branch_modifying_readme() {
  local branch="$1" body="$2"
  git checkout -q -b "$branch" main
  echo "$body" >> README.md
  git add README.md
  git commit -q -m "feat: edit README"
  git checkout -q main
}

bump_main_readme() {
  local body="$1"
  git checkout -q main
  echo "$body" >> README.md
  git add README.md
  git commit -q -m "main: edit README"
}

# ── Usage / dispatch ─────────────────────────────────────────────────────────

@test "queue: prints usage when no args" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "queue: --help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "queue: rejects unknown subcommand" {
  run bash "$SCRIPT" frobnicate
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown"* ]]
}

# ── add / remove / list ──────────────────────────────────────────────────────

@test "queue: add appends branch and is idempotent" {
  run bash "$SCRIPT" add agent/foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"queued: agent/foo"* ]]
  run bash "$SCRIPT" add agent/foo
  [ "$status" -eq 0 ]
  [[ "$output" == *"already queued"* ]]
  [ "$(grep -c '^agent/foo$' "$QUEUE_FILE")" -eq 1 ]
}

@test "queue: add requires a branch argument" {
  run bash "$SCRIPT" add
  [ "$status" -eq 2 ]
}

@test "queue: list on empty queue prints (empty)" {
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"(empty)"* ]]
}

@test "queue: list shows missing-branch tag for queued-but-deleted branch" {
  bash "$SCRIPT" add agent/never-existed >/dev/null
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"missing-branch"* ]]
}

@test "queue: list flags branch fully merged into main" {
  make_branch_with_fragment "agent/already-merged" "1.0.0" "merged body"
  git merge -q --no-ff agent/already-merged -m "merge"
  bash "$SCRIPT" add agent/already-merged >/dev/null
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"merged"* ]]
}

@test "queue: list shows ready when branch is ahead 0/N from main" {
  make_branch_with_fragment "agent/ready" "1.0.0"
  bash "$SCRIPT" add agent/ready >/dev/null
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"ready ahead=1"* ]]
}

@test "queue: list shows needs-rebase when main has moved" {
  make_branch_with_fragment "agent/stale" "1.0.0"
  bump_main_changelog "[2.0.0]: link"
  bash "$SCRIPT" add agent/stale >/dev/null
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"needs-rebase"* ]]
  [[ "$output" == *"behind=1"* ]]
}

@test "queue: remove drops a branch and is idempotent" {
  bash "$SCRIPT" add agent/x >/dev/null
  bash "$SCRIPT" add agent/y >/dev/null
  run bash "$SCRIPT" remove agent/x
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed"* ]]
  ! grep -q '^agent/x$' "$QUEUE_FILE"
  grep -q '^agent/y$' "$QUEUE_FILE"
  run bash "$SCRIPT" remove agent/x
  [[ "$output" == *"not queued"* ]]
}

# ── status ───────────────────────────────────────────────────────────────────

@test "queue: status reports zero on empty queue" {
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"total=0"* ]]
}

@test "queue: status counts ready / needs-rebase / merged / missing" {
  # Order matters: create stale BEFORE bumping main, then merge done so main
  # advances, THEN branch ready off the new tip so it's at zero-behind.
  make_branch_with_fragment "agent/stale" "1.0.0"
  make_branch_with_fragment "agent/done" "2.0.0"
  git merge -q --no-ff agent/done -m "merge done"
  make_branch_with_fragment "agent/ready" "3.0.0"
  bash "$SCRIPT" add agent/ready >/dev/null
  bash "$SCRIPT" add agent/stale >/dev/null
  bash "$SCRIPT" add agent/done >/dev/null
  bash "$SCRIPT" add agent/ghost >/dev/null
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"total=4"* ]]
  [[ "$output" == *"merged=1"* ]]
  [[ "$output" == *"ready=1"* ]]
  [[ "$output" == *"needs-rebase=1"* ]]
  [[ "$output" == *"missing=1"* ]]
}

# ── clear ────────────────────────────────────────────────────────────────────

@test "queue: clear refuses without --confirm" {
  bash "$SCRIPT" add agent/foo >/dev/null
  run bash "$SCRIPT" clear
  [ "$status" -eq 2 ]
  grep -q 'agent/foo' "$QUEUE_FILE"
}

@test "queue: clear --confirm empties queue file" {
  bash "$SCRIPT" add agent/foo >/dev/null
  run bash "$SCRIPT" clear --confirm
  [ "$status" -eq 0 ]
  [ ! -s "$QUEUE_FILE" ]
}

# ── rebase ───────────────────────────────────────────────────────────────────

@test "rebase: requires existing local branch" {
  run bash "$SCRIPT" rebase agent/does-not-exist
  [ "$status" -eq 3 ]
  [[ "$output" == *"local branch not found"* ]]
}

@test "rebase: refuses on dirty working tree" {
  make_branch_with_fragment "agent/dirty-test" "1.0.0"
  echo "uncommitted" > scratch.txt
  run bash "$SCRIPT" rebase agent/dirty-test
  [ "$status" -eq 3 ]
  [[ "$output" == *"working tree dirty"* ]]
  rm -f scratch.txt
}

@test "rebase: skips branch already merged" {
  make_branch_with_fragment "agent/done" "1.0.0"
  git merge -q --no-ff agent/done -m "merge"
  run bash "$SCRIPT" rebase agent/done
  [ "$status" -eq 0 ]
  [[ "$output" == *"already merged"* ]]
}

@test "rebase: no-op when branch is already up-to-date and ahead" {
  make_branch_with_fragment "agent/ahead" "1.0.0"
  run bash "$SCRIPT" rebase agent/ahead
  [ "$status" -eq 0 ]
  [[ "$output" == *"rebased OK"* ]]
}

@test "rebase: auto-resolves CHANGELOG.md conflict (cascade pattern)" {
  # Both main and branch touch CHANGELOG.md → real rebase conflict.
  # The script must take main's version and keep going.
  make_branch_touching_changelog_md "agent/branch-changelog" "[1.0.0]: branch"
  bump_main_changelog "[2.0.0]: main"
  run bash "$SCRIPT" rebase agent/branch-changelog
  [ "$status" -eq 0 ]
  [[ "$output" == *"rebased OK"* ]]
  # Verify the branch tip has main's CHANGELOG.md content
  git checkout -q agent/branch-changelog
  grep -q '\[2.0.0\]: main' CHANGELOG.md
  git checkout -q main
}

@test "rebase: auto-resolves when branch only adds a CHANGELOG.d/ fragment" {
  # Branch adds a fragment; main bumped CHANGELOG.md. No real conflict — fragment
  # is a new file. Rebase should succeed cleanly.
  make_branch_with_fragment "agent/fragment-only" "9.9.9"
  bump_main_changelog "[main-bump]: link"
  run bash "$SCRIPT" rebase agent/fragment-only
  [ "$status" -eq 0 ]
  [[ "$output" == *"rebased OK"* ]]
  git checkout -q agent/fragment-only
  [ -f "CHANGELOG.d/9.9.9.md" ]
  git checkout -q main
}

@test "rebase: ESCALATES on non-CHANGELOG conflict" {
  make_branch_modifying_readme "agent/readme-edit" "from branch"
  bump_main_readme "from main"
  run bash "$SCRIPT" rebase agent/readme-edit
  [ "$status" -eq 1 ]
  [[ "$output" == *"ESCALATE"* ]]
  [[ "$output" == *"README.md"* ]]
  # Working tree must be left clean — rebase aborted
  run git -C "$REPO" status --porcelain
  [ -z "$output" ]
  # And we must not be mid-rebase
  [ ! -d "$REPO/.git/rebase-merge" ]
  [ ! -d "$REPO/.git/rebase-apply" ]
}

@test "rebase: returns to original branch after escalation" {
  make_branch_modifying_readme "agent/readme-edit-2" "from branch"
  bump_main_readme "from main"
  git checkout -q main
  bash "$SCRIPT" rebase agent/readme-edit-2 || true
  current=$(git symbolic-ref --short HEAD)
  [ "$current" = "main" ]
}

# ── rebase-next ──────────────────────────────────────────────────────────────

@test "rebase-next: empty queue is a no-op" {
  run bash "$SCRIPT" rebase-next
  [ "$status" -eq 0 ]
  [[ "$output" == *"no rebase candidate"* ]]
}

@test "rebase-next: skips merged branches and rebases the first stale one" {
  make_branch_with_fragment "agent/done-1" "1.0.0"
  git merge -q --no-ff agent/done-1 -m "merge done-1"
  make_branch_with_fragment "agent/stale-1" "2.0.0"
  bump_main_changelog "[main-bump]: link"
  bash "$SCRIPT" add agent/done-1 >/dev/null
  bash "$SCRIPT" add agent/stale-1 >/dev/null
  run bash "$SCRIPT" rebase-next
  [ "$status" -eq 0 ]
  [[ "$output" == *"rebased OK: agent/stale-1"* ]]
}

@test "rebase-next: returns 0 when first branch is already up-to-date" {
  make_branch_with_fragment "agent/ahead" "1.0.0"
  bash "$SCRIPT" add agent/ahead >/dev/null
  run bash "$SCRIPT" rebase-next
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up-to-date"* ]]
}

# ── safety / hard-cap behaviour ──────────────────────────────────────────────

@test "safety: script never invokes git push or merge" {
  # Static check — defence in depth alongside the runtime tests
  ! grep -E '^[^#]*git[[:space:]]+(push|merge[[:space:]]+--no-ff[[:space:]]+--no-edit)' "$SCRIPT"
  ! grep -E '^[^#]*gh[[:space:]]+pr[[:space:]]+merge' "$SCRIPT"
}

@test "safety: script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: max-rebase-steps guard rail prevents infinite loop" {
  # If the auto-resolve loop ever spins, MAX_REBASE_STEPS=1 + a deliberate
  # CHANGELOG.md conflict that can't be resolved in one pass should abort
  # cleanly. We synthesise that by setting the cap to 0.
  make_branch_touching_changelog_md "agent/spin" "[1.0.0]: branch"
  bump_main_changelog "[2.0.0]: main"
  MAX_REBASE_STEPS=0 run bash "$SCRIPT" rebase agent/spin
  [ "$status" -eq 1 ]
  [[ "$output" == *"MAX_REBASE_STEPS"* ]]
  [ ! -d "$REPO/.git/rebase-merge" ]
  [ ! -d "$REPO/.git/rebase-apply" ]
}

# ── spec references ─────────────────────────────────────────────────────────

@test "spec ref: SE-074 Slice 2 cited in script header" {
  grep -q "SE-074 Slice 2" "$SCRIPT"
}

@test "spec ref: parallel-spec-execution.md and autonomous-safety.md referenced" {
  grep -q "parallel-spec-execution.md" "$SCRIPT"
  grep -q "autonomous-safety.md" "$SCRIPT"
}

@test "spec ref: cascade-rebase pattern named in header" {
  grep -qi "cascade-rebase" "$SCRIPT"
}
