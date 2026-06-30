#!/usr/bin/env bats
# tests/test-generate-propuestas-index.bats — SE-222 S2
# Tests for scripts/generate-propuestas-index.sh
# Ref: docs/propuestas/SE-222-okf-adoptable-patterns.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/generate-propuestas-index.sh"

  # Isolated temp dir so tests never touch real docs/propuestas/index.md
  TMPDIR_PI="$(mktemp -d)"

  export PROPUESTAS_DIR_OVERRIDE="$TMPDIR_PI"
  export INDEX_FILE_OVERRIDE="$TMPDIR_PI/index.md"

  # Helper: create a minimal spec file
  make_spec() {
    local name="$1" id="$2" title="$3" status="$4" priority="$5"
    cat > "$TMPDIR_PI/$name" <<EOF
---
spec_id: $id
title: "$title"
status: $status
priority: $priority
---
# $title body
EOF
  }

  export -f make_spec 2>/dev/null || true  # not all bats versions support this
  export TMPDIR_PI
}

teardown() {
  rm -rf "$TMPDIR_PI"
}

# ── AC1: script exists and is executable ──────────────────────────────────────
@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# ── AC2: --help exits 0 ───────────────────────────────────────────────────────
@test "--help exits 0 and shows usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# ── AC3: unknown flag exits 2 ─────────────────────────────────────────────────
@test "unknown flag exits 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

# ── AC4: generates index.md with correct header ───────────────────────────────
@test "generates index.md with correct header format" {
  cat > "$TMPDIR_PI/SE-001.md" <<'EOF'
---
spec_id: SE-001
title: "Test spec one"
status: PROPOSED
priority: P1
---
# Body
EOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$INDEX_FILE_OVERRIDE" ]

  # Header: "# Propuestas Index — auto-generado YYYY-MM-DD · N specs"
  grep -q "^# Propuestas Index — auto-generado" "$INDEX_FILE_OVERRIDE"
  grep -q "specs$" "$INDEX_FILE_OVERRIDE"
}

# ── AC5: table contains required columns ─────────────────────────────────────
@test "generated table has id, title, status, priority columns" {
  cat > "$TMPDIR_PI/SE-002.md" <<'EOF'
---
spec_id: SE-002
title: "Column test spec"
status: APPROVED
priority: P2
---
EOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Check header row has all four columns
  grep -q "| id |" "$INDEX_FILE_OVERRIDE"
  grep -q "title" "$INDEX_FILE_OVERRIDE"
  grep -q "status" "$INDEX_FILE_OVERRIDE"
  grep -q "priority" "$INDEX_FILE_OVERRIDE"
}

# ── AC6: APPROVED appears before ARCHIVED ────────────────────────────────────
@test "APPROVED specs appear before ARCHIVED in the table" {
  cat > "$TMPDIR_PI/SE-ARCH.md" <<'EOF'
---
spec_id: SE-ARCH
title: "Archived spec"
status: ARCHIVED
priority: P3
---
EOF

  cat > "$TMPDIR_PI/SE-APPR.md" <<'EOF'
---
spec_id: SE-APPR
title: "Approved spec"
status: APPROVED
priority: P1
---
EOF

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Find line numbers for each status in the file
  APPR_LINE="$(grep -n "SE-APPR" "$INDEX_FILE_OVERRIDE" | head -1 | cut -d: -f1)"
  ARCH_LINE="$(grep -n "SE-ARCH" "$INDEX_FILE_OVERRIDE" | head -1 | cut -d: -f1)"

  [ -n "$APPR_LINE" ]
  [ -n "$ARCH_LINE" ]
  [ "$APPR_LINE" -lt "$ARCH_LINE" ]
}

# ── AC7: --check passes when index is up-to-date ─────────────────────────────
@test "--check exits 0 when index is up-to-date" {
  cat > "$TMPDIR_PI/SE-003.md" <<'EOF'
---
spec_id: SE-003
title: "Check test spec"
status: PROPOSED
priority: P2
---
EOF

  # Generate first
  bash "$SCRIPT"

  # Now check — should pass
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"CHECK OK"* ]]
}

# ── AC8: --check fails when index is stale ───────────────────────────────────
@test "--check exits 1 when index is stale" {
  cat > "$TMPDIR_PI/SE-004.md" <<'EOF'
---
spec_id: SE-004
title: "Stale test spec"
status: PROPOSED
priority: P1
---
EOF

  # Generate first
  bash "$SCRIPT"

  # Now add a new spec to make the index stale
  cat > "$TMPDIR_PI/SE-005.md" <<'EOF'
---
spec_id: SE-005
title: "New spec added after index generation"
status: APPROVED
priority: P0
---
EOF

  run bash "$SCRIPT" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"stale"* ]] || [[ "$output" == *"FAIL"* ]]
}

# ── AC9: no failure when dir has no specs with frontmatter ───────────────────
@test "exits 0 and writes empty table when no specs have frontmatter" {
  # Create a file without frontmatter
  echo "# Just a markdown file without frontmatter" > "$TMPDIR_PI/no-frontmatter.md"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$INDEX_FILE_OVERRIDE" ]
  # Should contain 0 specs in header
  grep -q "· 0 specs" "$INDEX_FILE_OVERRIDE"
}

# ── AC10: footer present ──────────────────────────────────────────────────────
@test "generated index has footer with source script reference" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "generate-propuestas-index.sh" "$INDEX_FILE_OVERRIDE"
}

# ── AC11: PROPOSED appears before IMPLEMENTED ────────────────────────────────
@test "PROPOSED appears before IMPLEMENTED in ordering" {
  cat > "$TMPDIR_PI/SE-IMP.md" <<'EOF'
---
spec_id: SE-IMP
title: "Implemented spec"
status: IMPLEMENTED
priority: P2
---
EOF

  cat > "$TMPDIR_PI/SE-PRO.md" <<'EOF'
---
spec_id: SE-PRO
title: "Proposed spec"
status: PROPOSED
priority: P2
---
EOF

  bash "$SCRIPT"

  PROP_LINE="$(grep -n "SE-PRO" "$INDEX_FILE_OVERRIDE" | head -1 | cut -d: -f1)"
  IMPL_LINE="$(grep -n "SE-IMP" "$INDEX_FILE_OVERRIDE" | head -1 | cut -d: -f1)"

  [ -n "$PROP_LINE" ]
  [ -n "$IMPL_LINE" ]
  [ "$PROP_LINE" -lt "$IMPL_LINE" ]
}

# ── AC12: hook registered in settings.json ───────────────────────────────────
@test "propuestas-index-refresh hook is registered in settings.json" {
  SETTINGS="$REPO_ROOT/.claude/settings.json"
  [ -f "$SETTINGS" ]
  grep -q "propuestas-index-refresh" "$SETTINGS"
}

# ── AC13: @generated marker present ──────────────────────────────────────────
@test "index.md has @generated marker" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "@generated" "$INDEX_FILE_OVERRIDE"
}
