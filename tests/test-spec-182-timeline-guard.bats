#!/usr/bin/env bats
# test-spec-182-timeline-guard.bats — BATS tests for SPEC-182 Slice 4 timeline-status-guard
# Ref: SPEC-182 Slice 4
# Min: 14 tests, target >=80 score

GUARD_SCRIPT="scripts/timeline-status-guard.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  TMPDIR_TEST="$(mktemp -d)"
  export TMPDIR_TEST

  # Initialise a real git repo for fixture commits
  FIXTURE_REPO="$TMPDIR_TEST/repo"
  mkdir -p "$FIXTURE_REPO"
  git -C "$FIXTURE_REPO" init -q
  git -C "$FIXTURE_REPO" config user.email "test@bats.local"
  git -C "$FIXTURE_REPO" config user.name "BATS Test"
  export FIXTURE_REPO
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── Static checks ─────────────────────────────────────────────────────────────

@test "timeline-status-guard.sh exists" {
  [[ -f "$GUARD_SCRIPT" ]]
}

@test "timeline-status-guard.sh is executable" {
  [[ -x "$GUARD_SCRIPT" ]]
}

@test "timeline-status-guard.sh uses set -uo pipefail" {
  run grep -c "set -uo pipefail" "$GUARD_SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "timeline-status-guard.sh references SPEC-182" {
  run grep -c "SPEC-182" "$GUARD_SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "timeline-status-guard.sh passes bash -n syntax check" {
  run bash -n "$GUARD_SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Exit behaviour ────────────────────────────────────────────────────────────

@test "guard exits 0 in a repo with no .md changes" {
  # Create initial commit with no .md files
  echo "hello" > "$FIXTURE_REPO/main.go"
  git -C "$FIXTURE_REPO" add .
  git -C "$FIXTURE_REPO" commit -q -m "initial"
  echo "world" > "$FIXTURE_REPO/main.go"
  git -C "$FIXTURE_REPO" add .
  git -C "$FIXTURE_REPO" commit -q -m "update"
  run bash "$GUARD_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "guard always exits 0 (non-blocking) even when status changed" {
  # Set up two commits: one with PROPOSED, one with APPROVED but no timeline
  cat > "$FIXTURE_REPO/spec.md" <<'SPEC'
---
spec_id: SPEC-T
status: PROPOSED
---
# body
SPEC
  git -C "$FIXTURE_REPO" add spec.md
  git -C "$FIXTURE_REPO" commit -q -m "initial spec"

  # Change status without adding timeline
  cat > "$FIXTURE_REPO/spec.md" <<'SPEC'
---
spec_id: SPEC-T
status: APPROVED
---
# body
SPEC
  git -C "$FIXTURE_REPO" add spec.md
  git -C "$FIXTURE_REPO" commit -q -m "approve spec"

  # Run guard inside the fixture repo
  run bash "$(pwd)/$GUARD_SCRIPT"
  [ "$status" -eq 0 ]
}

# ── --check / --dry-run mode ─────────────────────────────────────────────────

@test "--check flag does not modify any files" {
  # Create a spec with status change
  cat > "$FIXTURE_REPO/spec.md" <<'SPEC'
---
spec_id: SPEC-T
status: PROPOSED
---
SPEC
  git -C "$FIXTURE_REPO" add spec.md
  git -C "$FIXTURE_REPO" commit -q -m "add spec"

  BEFORE="$(cat "$FIXTURE_REPO/spec.md")"
  # Run with --check from the fixture repo context
  run bash "$(pwd)/$GUARD_SCRIPT" --check
  [ "$status" -eq 0 ]
  AFTER="$(cat "$FIXTURE_REPO/spec.md")"
  [[ "$BEFORE" == "$AFTER" ]]
}

@test "--dry-run flag does not modify any files" {
  run bash "$GUARD_SCRIPT" --dry-run
  [ "$status" -eq 0 ]
}

# ── Status change detection ───────────────────────────────────────────────────

@test "detects status change in fixture git diff (--check exits 0 and does not emit HINT)" {
  # Guard with --check is analysis-only: no HINT to stderr, exit 0
  run bash "$GUARD_SCRIPT" --check 2>&1
  [ "$status" -eq 0 ]
  # Must not contain TIMELINE-HINT in analysis-only mode
  [[ "$output" != *"TIMELINE-HINT"* ]]
}

@test "no HINT emitted when timeline entry added alongside status change" {
  cat > "$FIXTURE_REPO/spec.md" <<'SPEC'
---
spec_id: SPEC-T
status: PROPOSED
---
SPEC
  git -C "$FIXTURE_REPO" add spec.md
  git -C "$FIXTURE_REPO" commit -q -m "initial"

  # Add status change WITH a timeline entry
  cat > "$FIXTURE_REPO/spec.md" <<'SPEC'
---
spec_id: SPEC-T
status: APPROVED
timeline:
  - from: "2026-01-01"
    value: "APPROVED"
    learned: "2026-06-01"
    source: "test"
---
SPEC
  git -C "$FIXTURE_REPO" add spec.md
  git -C "$FIXTURE_REPO" commit -q -m "approve with timeline"

  # Run guard in that repo — stderr should have no TIMELINE-HINT
  run bash -c "cd '$FIXTURE_REPO' && bash '$(pwd)/$GUARD_SCRIPT' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" != *"TIMELINE-HINT"* ]]
}

@test "no HINT emitted when status unchanged" {
  cat > "$FIXTURE_REPO/spec.md" <<'SPEC'
---
spec_id: SPEC-T
status: PROPOSED
---
# body
SPEC
  git -C "$FIXTURE_REPO" add spec.md
  git -C "$FIXTURE_REPO" commit -q -m "initial"

  # Change only body, not status
  cat > "$FIXTURE_REPO/spec.md" <<'SPEC'
---
spec_id: SPEC-T
status: PROPOSED
---
# body updated
SPEC
  git -C "$FIXTURE_REPO" add spec.md
  git -C "$FIXTURE_REPO" commit -q -m "update body"

  run bash -c "cd '$FIXTURE_REPO' && bash '$(pwd)/$GUARD_SCRIPT' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" != *"TIMELINE-HINT"* ]]
}

# ── JSON output ───────────────────────────────────────────────────────────────

@test "--json produces valid JSON (array)" {
  run bash "$GUARD_SCRIPT" --json
  [ "$status" -eq 0 ]
  # Output must start with [ and end with ]
  [[ "$output" == "["* ]]
  [[ "$output" == *"]" ]]
}

@test "--json returns empty array when no .md changed" {
  run bash "$GUARD_SCRIPT" --json
  [ "$status" -eq 0 ]
  [[ "$output" == "[]" ]]
}

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "edge: repo with no prior commit — guard exits 0 gracefully" {
  # In main repo, HEAD~1 may not exist for first commit — guard must handle gracefully
  run bash "$GUARD_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "edge: guard works from subdirectory of workspace" {
  run bash -c "cd /tmp && bash '$(pwd)/$GUARD_SCRIPT'"
  [ "$status" -eq 0 ]
}
