#!/usr/bin/env bats
# Tests for spec-lifecycle.sh — SE-222 S1 spec status transitions + LOG.md
# Ref: SPEC SE-222, docs/propuestas/SE-222-okf-adoptable-patterns.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/spec-lifecycle.sh"
  TMPDIR_SL="$(mktemp -d)"

  # Isolate writes: override PROPUESTAS_DIR and LOG.md so tests don't
  # touch the real docs/propuestas/LOG.md.
  export PROPUESTAS_DIR_OVERRIDE="$TMPDIR_SL"
  export LOG_FILE_OVERRIDE="$TMPDIR_SL/LOG.md"

  cat > "$TMPDIR_SL/SE-TEST.md" <<'EOF'
---
spec_id: SE-TEST
title: "Test spec"
status: PROPOSED
priority: P2
---
# Test spec body
EOF
  export TMPDIR_SL
}

teardown() {
  rm -rf "$TMPDIR_SL"
}

# ── Usage / argument errors ────────────────────────────────────────────────

@test "no args exits 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"required"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "--help shows usage exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--status"* ]]
}

@test "unknown arg exits 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown"* ]]
}

@test "missing --spec exits 2" {
  run bash "$SCRIPT" --status IMPLEMENTED
  [ "$status" -eq 2 ]
}

@test "missing --status exits 2" {
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-TEST.md"
  [ "$status" -eq 2 ]
}

@test "script uses set -uo pipefail safety guard" {
  run grep -E 'set -uo pipefail' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script is executable" {
  [ -x "$SCRIPT" ]
}

# ── Invalid inputs ─────────────────────────────────────────────────────────

@test "nonexistent spec exits 1" {
  run bash "$SCRIPT" --spec "$TMPDIR_SL/missing.md" --status IMPLEMENTED
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "invalid status exits 1" {
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-TEST.md" --status BOGUS_STATUS
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a canonical"* ]] || [[ "$output" == *"Valid"* ]]
}

# ── Function presence (script structure) ───────────────────────────────────

@test "is_canonical_status function exists" {
  run grep -E '^is_canonical_status\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "append_log_entry function exists" {
  run grep -E '^append_log_entry\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "update_status function exists" {
  run grep -E '^update_status\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "bootstrap_log function exists" {
  run grep -E '^bootstrap_log\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "get_field function exists" {
  run grep -E '^get_field\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "usage function exists" {
  run grep -E '^usage\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── --dry-run mode ─────────────────────────────────────────────────────────

@test "--dry-run does not modify spec file" {
  local before_hash
  before_hash=$(sha256sum "$TMPDIR_SL/SE-TEST.md" | awk '{print $1}')
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-TEST.md" --status IMPLEMENTED --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  local after_hash
  after_hash=$(sha256sum "$TMPDIR_SL/SE-TEST.md" | awk '{print $1}')
  [ "$before_hash" = "$after_hash" ]
}

@test "--dry-run shows status transition" {
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-TEST.md" --status IMPLEMENTED --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROPOSED"* ]]
  [[ "$output" == *"IMPLEMENTED"* ]]
}

@test "--dry-run shows note in log entry" {
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-TEST.md" --status DISCARDED --note "Test rationale" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Test rationale"* ]]
}

# ── Canonical status accepted ──────────────────────────────────────────────

@test "PROPOSED is canonical (dry-run)" {
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-TEST.md" --status PROPOSED --dry-run
  [ "$status" -eq 0 ]
}

@test "APPROVED is canonical (dry-run)" {
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-TEST.md" --status APPROVED --dry-run
  [ "$status" -eq 0 ]
}

@test "IMPLEMENTED is canonical (dry-run)" {
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-TEST.md" --status IMPLEMENTED --dry-run
  [ "$status" -eq 0 ]
}

@test "DISCARDED is canonical (dry-run)" {
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-TEST.md" --status DISCARDED --dry-run
  [ "$status" -eq 0 ]
}

@test "lowercase status is not canonical" {
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-TEST.md" --status proposed
  [ "$status" -eq 1 ]
  [[ "$output" == *"canonical"* ]] || [[ "$output" == *"Valid"* ]]
}

# ── --bootstrap mode ───────────────────────────────────────────────────────

@test "--bootstrap with --dry-run does not write" {
  run bash "$SCRIPT" --bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
}

# ── Existing LOG.md preserves entries ──────────────────────────────────────

@test "real LOG.md exists in repo (S1 deliverable)" {
  [ -f "$REPO_ROOT/docs/propuestas/LOG.md" ]
}

@test "real LOG.md has header marker" {
  run grep -E '^# Specs Lifecycle Log' "$REPO_ROOT/docs/propuestas/LOG.md"
  [ "$status" -eq 0 ]
}

@test "real LOG.md is referenced by spec-lifecycle.sh path" {
  run grep -E 'LOG\.md' "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Real spec transition smoke test (with isolated spec file) ──────────────

@test "real transition updates status: in spec frontmatter" {
  cat > "$TMPDIR_SL/SE-FULL.md" <<'EOF'
---
spec_id: SE-FULL
title: "Full test"
status: PROPOSED
priority: P3
---
EOF
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-FULL.md" --status APPROVED --note "BATS smoke test"
  [ "$status" -eq 0 ]
  run grep -E '^status: APPROVED' "$TMPDIR_SL/SE-FULL.md"
  [ "$status" -eq 0 ]
}

@test "real transition appends entry to LOG.md (isolated)" {
  cat > "$TMPDIR_SL/SE-LOG.md" <<'EOF'
---
spec_id: SE-LOG
title: "Log test"
status: PROPOSED
---
EOF
  run bash "$SCRIPT" --spec "$TMPDIR_SL/SE-LOG.md" --status IMPLEMENTED --note "LOG smoke"
  [ "$status" -eq 0 ]
  [ -f "$LOG_FILE_OVERRIDE" ]
  run grep -E 'SE-LOG IMPLEMENTED' "$LOG_FILE_OVERRIDE"
  [ "$status" -eq 0 ]
}

@test "LOG.md inserts new entries at top (after header)" {
  cat > "$TMPDIR_SL/SE-FIRST.md" <<'EOF'
---
spec_id: SE-FIRST
status: PROPOSED
---
EOF
  cat > "$TMPDIR_SL/SE-SECOND.md" <<'EOF'
---
spec_id: SE-SECOND
status: PROPOSED
---
EOF
  bash "$SCRIPT" --spec "$TMPDIR_SL/SE-FIRST.md" --status IMPLEMENTED --note "First"
  bash "$SCRIPT" --spec "$TMPDIR_SL/SE-SECOND.md" --status IMPLEMENTED --note "Second"

  # SE-SECOND should appear earlier in the file (newer at top)
  local first_line second_line
  first_line=$(grep -n 'SE-FIRST IMPLEMENTED' "$LOG_FILE_OVERRIDE" | head -1 | cut -d: -f1)
  second_line=$(grep -n 'SE-SECOND IMPLEMENTED' "$LOG_FILE_OVERRIDE" | head -1 | cut -d: -f1)
  [ -n "$first_line" ]
  [ -n "$second_line" ]
  [ "$second_line" -lt "$first_line" ]
}

@test "--bootstrap creates LOG.md when absent (isolated)" {
  rm -f "$LOG_FILE_OVERRIDE"
  run bash "$SCRIPT" --bootstrap
  [ "$status" -eq 0 ]
  [ -f "$LOG_FILE_OVERRIDE" ]
  run grep -E '# Specs Lifecycle Log' "$LOG_FILE_OVERRIDE"
  [ "$status" -eq 0 ]
}
