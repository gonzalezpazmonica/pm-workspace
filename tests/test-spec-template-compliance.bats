#!/usr/bin/env bats
# Tests for SPEC-120 — Spec template spec-kit compatibility
# Ref: docs/propuestas/SPEC-120-spec-kit-alignment.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SPEC_TEMPLATE="$REPO_ROOT/.claude/skills/spec-driven-development/references/spec-template.md"
  export SDD_DOC="$REPO_ROOT/docs/agent-teams-sdd.md"
}

@test "spec_template_exists" {
  [ -f "$SPEC_TEMPLATE" ]
}

@test "spec_template_declares_spec_kit_compatible" {
  grep -q "spec_kit_compatible: true" "$SPEC_TEMPLATE"
}

@test "spec_template_has_spec_kit_alignment_section" {
  grep -q "^## Spec-Kit Alignment" "$SPEC_TEMPLATE"
}

@test "spec_template_references_github_spec_kit" {
  grep -q "github/spec-kit\|github.com/github/spec-kit" "$SPEC_TEMPLATE"
}

@test "spec_template_maps_what_and_why" {
  grep -q "What & Why" "$SPEC_TEMPLATE"
}

@test "spec_template_maps_requirements" {
  grep -qE "## Requirements|\`## Requirements\`" "$SPEC_TEMPLATE"
}

@test "spec_template_maps_technical_design" {
  grep -qE "Technical Design" "$SPEC_TEMPLATE"
}

@test "spec_template_maps_acceptance_criteria" {
  grep -qE "Acceptance Criteria" "$SPEC_TEMPLATE"
}

@test "spec_template_preserves_savia_section_developer_type" {
  grep -q "Developer Type:" "$SPEC_TEMPLATE"
}

@test "spec_template_preserves_savia_section_effort_estimation" {
  grep -q "Effort Estimation" "$SPEC_TEMPLATE"
}

@test "sdd_doc_has_spec_kit_alignment_section" {
  grep -q "^## Spec-Kit Alignment" "$SDD_DOC"
}

@test "sdd_doc_references_spec_120" {
  grep -q "SPEC-120" "$SDD_DOC"
}
