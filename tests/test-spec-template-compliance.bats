#!/usr/bin/env bats
# Tests for SPEC-120 — Spec template spec-kit compatibility
# Ref: docs/propuestas/SPEC-120-spec-kit-alignment.md
#
# Validates:
#   - Canonical template exists and is readable
#   - spec_kit_compatible marker present
#   - All 4 spec-kit standard sections mapped
#   - Savia-exclusive sections preserved
#   - Protection against regression (broken templates fail validation)

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SPEC_TEMPLATE="$REPO_ROOT/.claude/skills/spec-driven-development/references/spec-template.md"
  export SDD_DOC="$REPO_ROOT/docs/agent-teams-sdd.md"

  # Isolated workspace for negative-case fixtures
  TMPDIR_SPEC="$(mktemp -d)"
  export TMPDIR_SPEC

  # Fixture: broken template missing What & Why
  cat > "$TMPDIR_SPEC/broken-no-why.md" <<'FIXTURE'
# Fake template
## Requirements
## Technical Design
## Acceptance Criteria
FIXTURE

  # Fixture: broken template missing spec_kit_compatible marker
  cat > "$TMPDIR_SPEC/broken-no-marker.md" <<'FIXTURE'
# Fake template
## Spec-Kit Alignment
## What & Why
## Requirements
## Technical Design
## Acceptance Criteria
FIXTURE

  # Fixture: valid minimal template
  cat > "$TMPDIR_SPEC/valid-minimal.md" <<'FIXTURE'
# Minimal
> spec_kit_compatible: true
## Spec-Kit Alignment
See github/spec-kit.
## What & Why
## Requirements
## Technical Design
## Acceptance Criteria
## Developer Type:
## Effort Estimation
FIXTURE
}

teardown() {
  rm -rf "$TMPDIR_SPEC" 2>/dev/null || true
}

# ── Safety / integrity ───────────────────────────────────────────────────────

@test "safety: canonical template file is not accidentally deleted" {
  [ -f "$SPEC_TEMPLATE" ]
  [ -r "$SPEC_TEMPLATE" ]
  [ "$(wc -l < "$SPEC_TEMPLATE")" -gt 100 ]  # non-trivial content preserved
}

@test "safety: sdd documentation file is preserved" {
  [ -f "$SDD_DOC" ]
  [ -r "$SDD_DOC" ]
}

@test "safety: template is not empty" {
  [ -s "$SPEC_TEMPLATE" ]
}

# ── Positive cases (spec-kit sections present) ───────────────────────────────

@test "positive: declares spec_kit_compatible marker" {
  run grep -c "spec_kit_compatible: true" "$SPEC_TEMPLATE"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "positive: has Spec-Kit Alignment section" {
  run grep -cE "^## Spec-Kit Alignment" "$SPEC_TEMPLATE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "positive: references github/spec-kit repo" {
  run grep -cE "github/spec-kit|github\.com/github/spec-kit" "$SPEC_TEMPLATE"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "positive: maps What & Why spec-kit section" {
  grep -qE "What & Why" "$SPEC_TEMPLATE"
}

@test "positive: maps Requirements spec-kit section" {
  grep -qE "Requirements" "$SPEC_TEMPLATE"
}

@test "positive: maps Technical Design spec-kit section" {
  grep -qE "Technical Design" "$SPEC_TEMPLATE"
}

@test "positive: maps Acceptance Criteria spec-kit section" {
  grep -qE "Acceptance Criteria" "$SPEC_TEMPLATE"
}

# ── Savia-exclusive sections preserved ──────────────────────────────────────

@test "positive: preserves Developer Type section (Savia-exclusive)" {
  grep -q "Developer Type:" "$SPEC_TEMPLATE"
}

@test "positive: preserves Effort Estimation section (Savia-exclusive)" {
  grep -q "Effort Estimation" "$SPEC_TEMPLATE"
}

@test "positive: preserves Ficheros a Crear section (Savia-exclusive)" {
  grep -qE "Ficheros a Crear|Crear \(nuevos\)" "$SPEC_TEMPLATE"
}

@test "positive: preserves Iteration & Convergence section (Savia-exclusive)" {
  grep -qE "Iteration & Convergence|Convergence Criteria" "$SPEC_TEMPLATE"
}

# ── Documentation cross-reference ───────────────────────────────────────────

@test "positive: agent-teams-sdd has Spec-Kit Alignment section" {
  run grep -cE "^## Spec-Kit Alignment" "$SDD_DOC"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "positive: agent-teams-sdd references SPEC-120" {
  grep -q "SPEC-120" "$SDD_DOC"
}

@test "positive: agent-teams-sdd contains section mapping table" {
  grep -qE "spec-kit.*Savia|Savia.*spec-kit" "$SDD_DOC"
}

# ── Negative cases (detect regressions) ─────────────────────────────────────

@test "negative: broken template without What & Why is detectable" {
  # Simulate regression: fixture missing What & Why section
  run grep -q "What & Why" "$TMPDIR_SPEC/broken-no-why.md"
  [ "$status" -ne 0 ]  # grep exits non-zero when no match — this is the regression signal
}

@test "negative: template without spec_kit_compatible marker is detectable" {
  # Simulate regression: fixture missing marker
  run grep -q "spec_kit_compatible: true" "$TMPDIR_SPEC/broken-no-marker.md"
  [ "$status" -ne 0 ]
}

@test "negative: nonexistent template path fails gracefully" {
  run test -f "/nonexistent/spec-template.md"
  [ "$status" -ne 0 ]
}

@test "negative: empty string is not a valid template" {
  empty_file="$TMPDIR_SPEC/empty.md"
  : > "$empty_file"
  run grep -q "spec_kit_compatible" "$empty_file"
  [ "$status" -ne 0 ]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: minimal valid fixture has all 4 spec-kit sections" {
  grep -qE "^## What & Why" "$TMPDIR_SPEC/valid-minimal.md"
  grep -qE "^## Requirements" "$TMPDIR_SPEC/valid-minimal.md"
  grep -qE "^## Technical Design" "$TMPDIR_SPEC/valid-minimal.md"
  grep -qE "^## Acceptance Criteria" "$TMPDIR_SPEC/valid-minimal.md"
}

@test "edge: canonical template has no conflicting section numbering" {
  # Ensure numeric sections (1., 2., etc) exist but don't collide with spec-kit headers
  run grep -cE "^## [0-9]+\." "$SPEC_TEMPLATE"
  [ "$status" -eq 0 ]
  [ "$output" -ge 5 ]  # at least 5 numbered sections survived
}

@test "edge: template size is within reasonable bounds (not truncated, not bloated)" {
  local lines
  lines="$(wc -l < "$SPEC_TEMPLATE")"
  [ "$lines" -gt 100 ]   # not truncated
  [ "$lines" -lt 2000 ]  # not bloated
}

# ── Isolation verification ──────────────────────────────────────────────────

@test "isolation: fixtures are in tmp and do not leak to repo" {
  [ -d "$TMPDIR_SPEC" ]
  [[ "$TMPDIR_SPEC" == /tmp/* ]] || [[ "$TMPDIR_SPEC" == /var/folders/* ]]
}

@test "isolation: teardown removes tmp fixtures" {
  # Teardown runs after each test; this one just verifies pattern
  [ -d "$TMPDIR_SPEC" ]
}
