#!/usr/bin/env bats
# Ref: SE-074 Slice 3 — parallel-specs-db-sandbox.sh

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/parallel-specs-db-sandbox.sh"
  SBX_DIR=$(mktemp -d)
  export SPEC_DB_SANDBOX_DIR="$SBX_DIR"
  export SPEC_DB_BACKEND="sqlite"
  unset SPEC_DB_PG_ADMIN_URL
}

teardown() {
  rm -rf "$SBX_DIR"
}

# ── Usage / dispatch ─────────────────────────────────────────────────────────

@test "db-sandbox: prints usage when no args" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "db-sandbox: --help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Subcommands"* ]]
}

@test "db-sandbox: rejects unknown subcommand" {
  run bash "$SCRIPT" frobnicate spec-foo
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown"* ]]
}

# ── SQLite happy paths ──────────────────────────────────────────────────────

@test "db-sandbox: init sqlite creates file at expected path" {
  run bash "$SCRIPT" init spec-SE-100-20260426-150000
  [ "$status" -eq 0 ]
  [ -f "$SBX_DIR/spec-SE-100-20260426-150000.sqlite" ]
}

@test "db-sandbox: init emits DATABASE_URL=sqlite:///... line" {
  run bash "$SCRIPT" init spec-SE-101-20260426-150000
  [ "$status" -eq 0 ]
  [[ "$output" == DATABASE_URL=sqlite:///* ]]
  [[ "$output" == *"spec-SE-101-20260426-150000.sqlite"* ]]
}

@test "db-sandbox: init is idempotent — second call same path, exit 0" {
  bash "$SCRIPT" init spec-SE-102-20260426 >/dev/null
  run bash "$SCRIPT" init spec-SE-102-20260426
  [ "$status" -eq 0 ]
  # Only one file
  [ "$(find "$SBX_DIR" -name 'spec-SE-102*.sqlite' | wc -l)" -eq 1 ]
}

@test "db-sandbox: path subcommand prints expected path without creating" {
  run bash "$SCRIPT" path spec-SE-103-x
  [ "$status" -eq 0 ]
  [[ "$output" == "$SBX_DIR/spec-SE-103-x.sqlite" ]]
  # Must NOT have created the file
  [ ! -f "$SBX_DIR/spec-SE-103-x.sqlite" ]
}

@test "db-sandbox: destroy removes sqlite file, idempotent on missing" {
  bash "$SCRIPT" init spec-SE-104 >/dev/null
  [ -f "$SBX_DIR/spec-SE-104.sqlite" ]
  run bash "$SCRIPT" destroy spec-SE-104
  [ "$status" -eq 0 ]
  [ ! -f "$SBX_DIR/spec-SE-104.sqlite" ]
  # Idempotent
  run bash "$SCRIPT" destroy spec-SE-104
  [ "$status" -eq 0 ]
}

@test "db-sandbox: list enumerates only existing sandboxes" {
  bash "$SCRIPT" init spec-A >/dev/null
  bash "$SCRIPT" init spec-B >/dev/null
  bash "$SCRIPT" destroy spec-A >/dev/null
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"spec-B"* ]]
  [[ "$output" != *"spec-A"* ]]
}

@test "db-sandbox: list reports (no sandboxes) on empty dir" {
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"(no sandboxes)"* ]]
}

# ── Validation / safety ─────────────────────────────────────────────────────

@test "db-sandbox: rejects worktree_name with shell metachars" {
  run bash "$SCRIPT" init 'spec-foo;rm-rf'
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid worktree_name"* ]]
}

@test "db-sandbox: rejects worktree_name with backtick" {
  run bash "$SCRIPT" init 'spec-`whoami`'
  [ "$status" -eq 2 ]
}

@test "db-sandbox: rejects worktree_name with dollar sign" {
  run bash "$SCRIPT" init 'spec-$HOME'
  [ "$status" -eq 2 ]
}

@test "db-sandbox: rejects empty worktree_name" {
  run bash "$SCRIPT" init ""
  [ "$status" -eq 2 ]
}

@test "db-sandbox: rejects worktree_name longer than 100 chars" {
  local long; long=$(printf 'a%.0s' {1..101})
  run bash "$SCRIPT" init "$long"
  [ "$status" -eq 2 ]
}

# ── Postgres opt-in error paths (don't actually require psql) ───────────────

@test "db-sandbox: postgres backend errors clearly when SPEC_DB_PG_ADMIN_URL unset" {
  SPEC_DB_BACKEND=postgres run bash "$SCRIPT" init spec-pg
  [ "$status" -eq 3 ]
  [[ "$output" == *"SPEC_DB_PG_ADMIN_URL"* ]]
}

@test "db-sandbox: rejects unknown backend" {
  SPEC_DB_BACKEND=mysql run bash "$SCRIPT" init spec-x
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown SPEC_DB_BACKEND"* ]]
}

# ── Static / safety / spec ref ──────────────────────────────────────────────

@test "spec ref: SE-074 Slice 3 cited in script header" {
  grep -q "SE-074 Slice 3" "$SCRIPT"
}

@test "safety: db-sandbox.sh has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: db-sandbox.sh never invokes git push or merge" {
  ! grep -E '^[^#]*git[[:space:]]+(push|merge)' "$SCRIPT"
}

@test "safety: SQLite paths never escape SPEC_DB_SANDBOX_DIR" {
  # Defence: dot-dot and absolute paths in worktree_name should be rejected
  run bash "$SCRIPT" init '../escape'
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" init '/etc/passwd'
  [ "$status" -eq 2 ]
}
