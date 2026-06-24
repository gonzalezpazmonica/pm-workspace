#!/usr/bin/env bats
# Tests for propuestas-index-gen.sh — SE-222 S2 INDEX.md auto-generator
# Ref: SPEC SE-222, docs/propuestas/SE-222-okf-adoptable-patterns.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/propuestas-index-gen.sh"
  TMPDIR_IDX="$(mktemp -d)"

  # Use override env vars for full isolation
  export PROPUESTAS_DIR_OVERRIDE="$TMPDIR_IDX"
  export INDEX_FILE_OVERRIDE="$TMPDIR_IDX/INDEX.md"

  # Create a few sample specs with varied frontmatter
  cat > "$TMPDIR_IDX/SE-AAA.md" <<'EOF'
---
spec_id: SE-AAA
title: First test spec
status: PROPOSED
priority: P2
effort: M
era: 100
---
# SE-AAA
EOF

  cat > "$TMPDIR_IDX/SE-BBB.md" <<'EOF'
---
spec_id: SE-BBB
title: Second test spec
status: IMPLEMENTED
priority: P1
effort: S
era: 101
---
# SE-BBB
EOF

  cat > "$TMPDIR_IDX/SE-CCC.md" <<'EOF'
---
spec_id: SE-CCC
title: Third test spec
status: DISCARDED
---
# SE-CCC
EOF

  cat > "$TMPDIR_IDX/no-frontmatter.md" <<'EOF'
# Not a spec
Body only.
EOF

  export TMPDIR_IDX
}

teardown() {
  rm -rf "$TMPDIR_IDX"
}

# ── Usage / args ───────────────────────────────────────────────────────────

@test "--help shows usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "unknown arg exits 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "script uses set -uo pipefail safety guard" {
  run grep -E 'set -uo pipefail' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script is executable" {
  [ -x "$SCRIPT" ]
}

# ── Function presence ──────────────────────────────────────────────────────

@test "get_field function exists" {
  run grep -E '^get_field\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "generate_index function exists" {
  run grep -E '^generate_index\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "normalize_status function exists" {
  run grep -E '^normalize_status\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "usage function exists" {
  run grep -E '^usage\(\)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── --dry-run ──────────────────────────────────────────────────────────────

@test "--dry-run prints to stdout" {
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Specs Index"* ]]
}

@test "--dry-run does not write INDEX.md" {
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$INDEX_FILE_OVERRIDE" ]
}

# ── Generate mode ──────────────────────────────────────────────────────────

@test "default mode writes INDEX.md" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$INDEX_FILE_OVERRIDE" ]
}

@test "generated INDEX.md has @generated marker" {
  bash "$SCRIPT"
  run grep -E '@generated' "$INDEX_FILE_OVERRIDE"
  [ "$status" -eq 0 ]
}

@test "generated INDEX.md groups by PROPOSED status" {
  bash "$SCRIPT"
  run grep -E '^## PROPOSED' "$INDEX_FILE_OVERRIDE"
  [ "$status" -eq 0 ]
}

@test "generated INDEX.md groups by IMPLEMENTED status" {
  bash "$SCRIPT"
  run grep -E '^## IMPLEMENTED' "$INDEX_FILE_OVERRIDE"
  [ "$status" -eq 0 ]
}

@test "generated INDEX.md groups by DISCARDED status" {
  bash "$SCRIPT"
  run grep -E '^## DISCARDED' "$INDEX_FILE_OVERRIDE"
  [ "$status" -eq 0 ]
}

@test "generated INDEX.md links to spec files" {
  bash "$SCRIPT"
  run grep -E '\[SE-AAA\.md\]\(\./SE-AAA\.md\)' "$INDEX_FILE_OVERRIDE"
  [ "$status" -eq 0 ]
}

@test "no-frontmatter file is excluded from INDEX.md" {
  bash "$SCRIPT"
  run grep -E 'no-frontmatter' "$INDEX_FILE_OVERRIDE"
  [ "$status" -ne 0 ]
}

@test "INDEX.md itself is excluded (not self-listed)" {
  bash "$SCRIPT"
  # Now INDEX.md exists. Regenerate again — it shouldn't list itself.
  bash "$SCRIPT"
  # Count INDEX.md occurrences in the file links column
  local count
  count=$(grep -cE '\[INDEX\.md\]' "$INDEX_FILE_OVERRIDE" || true)
  [ "$count" -eq 0 ]
}

@test "LOG.md is excluded (not self-listed)" {
  cat > "$TMPDIR_IDX/LOG.md" <<'EOF'
# Lifecycle log
EOF
  bash "$SCRIPT"
  local count
  count=$(grep -cE '\[LOG\.md\]' "$INDEX_FILE_OVERRIDE" || true)
  [ "$count" -eq 0 ]
}

# ── --check mode ───────────────────────────────────────────────────────────

@test "--check passes when INDEX.md is up-to-date" {
  bash "$SCRIPT"
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]] || [[ "$output" == *"up-to-date"* ]]
}

@test "--check fails when INDEX.md is stale" {
  bash "$SCRIPT"
  # Add a new spec → INDEX.md now stale
  cat > "$TMPDIR_IDX/SE-NEW.md" <<'EOF'
---
spec_id: SE-NEW
title: New spec
status: PROPOSED
---
EOF
  run bash "$SCRIPT" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"STALE"* ]] || [[ "$output" == *"differs"* ]]
}

@test "--check fails when INDEX.md absent" {
  run bash "$SCRIPT" --check
  [ "$status" -eq 1 ]
}

# ── Real propuestas dir smoke test ─────────────────────────────────────────

@test "real propuestas dir generates without errors (dry-run)" {
  unset PROPUESTAS_DIR_OVERRIDE
  unset INDEX_FILE_OVERRIDE
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Specs Index"* ]]
}

@test "real INDEX.md exists in repo (S2 deliverable)" {
  [ -f "$REPO_ROOT/docs/propuestas/INDEX.md" ]
}

@test "real INDEX.md has @generated sentinel marker" {
  run grep -E '@generated' "$REPO_ROOT/docs/propuestas/INDEX.md"
  [ "$status" -eq 0 ]
}
