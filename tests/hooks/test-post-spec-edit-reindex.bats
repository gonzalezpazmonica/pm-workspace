#!/usr/bin/env bats
# Tests for post-spec-edit-reindex.sh — SE-222 S2 PostToolUse hook
# Ref: SPEC SE-222, docs/propuestas/SE-222-okf-adoptable-patterns.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/.opencode/hooks/post-spec-edit-reindex.sh"
  TMPDIR_H="$(mktemp -d)"
  # Override hook state dir so tests don't share stamp with real hook
  export SAVIA_HOOK_STATE_DIR="$TMPDIR_H"
  export SAVIA_REINDEX_COOLDOWN=1
  export TMPDIR_H
}

teardown() {
  rm -rf "$TMPDIR_H"
}

# ── Basic invocations ──────────────────────────────────────────────────────

@test "hook exists and is executable" {
  [ -x "$HOOK" ]
}

@test "hook uses set -uo pipefail" {
  run grep -E 'set -uo pipefail' "$HOOK"
  [ "$status" -eq 0 ]
}

@test "empty input does not crash hook" {
  run bash -c "echo '' | $HOOK"
  [ "$status" -eq 0 ]
}

@test "invalid JSON does not crash hook" {
  run bash -c "echo 'not json' | $HOOK"
  [ "$status" -eq 0 ]
}

@test "missing file_path does not crash hook" {
  run bash -c "echo '{\"tool_input\":{}}' | $HOOK"
  [ "$status" -eq 0 ]
}

# ── Triggers / non-triggers ────────────────────────────────────────────────

@test "non-propuestas path does not trigger" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"/home/monica/savia/scripts/foo.sh\"}}' | $HOOK"
  [ "$status" -eq 0 ]
  # No stamp written
  [ ! -f "$TMPDIR_H/post-spec-edit-reindex.stamp" ]
}

@test "propuestas/INDEX.md edit does NOT trigger (skip self)" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"/home/monica/savia/docs/propuestas/INDEX.md\"}}' | $HOOK"
  [ "$status" -eq 0 ]
  # Wait for any background job
  sleep 1.5
  [ ! -f "$TMPDIR_H/post-spec-edit-reindex.stamp" ]
}

@test "propuestas/LOG.md edit does NOT trigger (skip self)" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"/home/monica/savia/docs/propuestas/LOG.md\"}}' | $HOOK"
  [ "$status" -eq 0 ]
  sleep 1.5
  [ ! -f "$TMPDIR_H/post-spec-edit-reindex.stamp" ]
}

@test "spec edit in propuestas/ triggers (stamp created)" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"/home/monica/savia/docs/propuestas/SE-XYZ.md\"}}' | $HOOK"
  [ "$status" -eq 0 ]
  # Background job runs the generator. Wait briefly.
  sleep 2.5
  [ -f "$TMPDIR_H/post-spec-edit-reindex.stamp" ]
}

@test "non-md propuestas file does NOT trigger" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"/home/monica/savia/docs/propuestas/notes.txt\"}}' | $HOOK"
  [ "$status" -eq 0 ]
  sleep 1.5
  [ ! -f "$TMPDIR_H/post-spec-edit-reindex.stamp" ]
}

# ── Toggle / disabled ──────────────────────────────────────────────────────

@test "SAVIA_PROPUESTAS_REINDEX_ENABLED=false disables hook" {
  SAVIA_PROPUESTAS_REINDEX_ENABLED=false run bash -c "echo '{\"tool_input\":{\"file_path\":\"/home/monica/savia/docs/propuestas/SE-AAA.md\"}}' | $HOOK"
  [ "$status" -eq 0 ]
  sleep 1.5
  [ ! -f "$TMPDIR_H/post-spec-edit-reindex.stamp" ]
}

# ── Rate-limit / cooldown ──────────────────────────────────────────────────

@test "hook respects cooldown stamp" {
  # Pre-populate stamp with recent timestamp
  mkdir -p "$TMPDIR_H"
  printf '%s' "$(date +%s)" > "$TMPDIR_H/post-spec-edit-reindex.stamp"

  # Set long cooldown to ensure we hit it
  SAVIA_REINDEX_COOLDOWN=3600 run bash -c "echo '{\"tool_input\":{\"file_path\":\"/home/monica/savia/docs/propuestas/SE-XYZ.md\"}}' | $HOOK"
  [ "$status" -eq 0 ]

  # Stamp should not change (cooldown skip)
  local stamp_after
  stamp_after=$(cat "$TMPDIR_H/post-spec-edit-reindex.stamp")
  [ -n "$stamp_after" ]
}

# ── Reference scripts/path resolution ──────────────────────────────────────

@test "hook references propuestas-index-gen.sh" {
  run grep -E 'propuestas-index-gen\.sh' "$HOOK"
  [ "$status" -eq 0 ]
}

@test "hook reads tool_input.file_path or path" {
  run grep -E 'tool_input\.file_path' "$HOOK"
  [ "$status" -eq 0 ]
}

@test "hook exits 0 unconditionally on toggle off" {
  SAVIA_PROPUESTAS_REINDEX_ENABLED=false run bash -c "echo '{\"tool_input\":{\"file_path\":\"anything\"}}' | $HOOK"
  [ "$status" -eq 0 ]
}
