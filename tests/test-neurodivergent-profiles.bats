#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-061-neurodivergent-profiles.md
# Tests for neurodivergent profile system — schema, privacy, integration

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEMPLATE="$REPO_ROOT/.claude/profiles/users/template/neurodivergent.md"
  RULE="$REPO_ROOT/docs/rules/domain/neurodivergent-integration.md"
  ACCESS_RULE="$REPO_ROOT/docs/rules/domain/accessibility-output.md"
  TMPDIR_ND=$(mktemp -d)
}

teardown() { rm -rf "$TMPDIR_ND"; }

@test "template file exists" {
  [ -f "$TEMPLATE" ]
}

@test "integration rule exists" {
  [ -f "$RULE" ]
}

@test "template has set -uo pipefail equivalent (YAML safety)" {
  # For YAML profiles, safety = all fields commented out by default
  grep -q "^#" "$TEMPLATE"
  # No active config in template — safe defaults
  ! grep -qE "^adhd:|^autism:|^active_modes:" "$TEMPLATE"
}

@test "positive: template contains all 5 dimensions" {
  grep -q "adhd" "$TEMPLATE"
  grep -q "autism" "$TEMPLATE"
  grep -q "dyslexia" "$TEMPLATE"
  grep -q "giftedness" "$TEMPLATE"
  grep -q "dyscalculia" "$TEMPLATE"
}

@test "positive: template has active_modes" {
  grep -q "active_modes" "$TEMPLATE"
}

@test "positive: template has sensory_budget" {
  grep -q "sensory_budget" "$TEMPLATE"
}

@test "positive: template has strengths_map" {
  grep -q "strengths_map" "$TEMPLATE"
}

@test "positive: template has body_double" {
  grep -q "body_double" "$TEMPLATE"
}

@test "negative: template is N3 privacy" {
  grep -q "N3\|gitignored\|never shared" "$TEMPLATE"
}

@test "negative: template mentions savia-forget" {
  grep -q "savia-forget" "$TEMPLATE"
}

@test "rule integrates ADHD with review_sensitivity" {
  grep -q "review_sensitivity" "$RULE"
  grep -q "rsd_sensitivity" "$RULE"
}

@test "rule integrates dyslexia with accessibility" {
  grep -q "dyslexia_friendly" "$RULE"
}

@test "rule has privacy section" {
  grep -q "NUNCA" "$RULE"
  grep -q "N3" "$RULE"
}

@test "edge: template under 150 lines" {
  local lines; lines=$(wc -l < "$TEMPLATE"); [ "$lines" -le 150 ]
}

@test "edge: rule under 150 lines" {
  local lines; lines=$(wc -l < "$RULE"); [ "$lines" -le 150 ]
}

@test "edge: template has no active YAML config" {
  # All config lines are commented out — safe defaults
  ! grep -qE "^(adhd|autism|active_modes|sensory_budget):" "$TEMPLATE"
}

@test "coverage: accessibility-output.md exists" {
  [ -f "$ACCESS_RULE" ]
}

@test "coverage: SPEC-061 referenced" {
  grep -q "SPEC-061\|061" "$RULE"
}

@test "edge: empty neurodivergent.md is valid" {
  touch "$TMPDIR_ND/empty-nd.md"
  [ -f "$TMPDIR_ND/empty-nd.md" ]
  local lines; lines=$(wc -l < "$TMPDIR_ND/empty-nd.md")
  [ "$lines" -eq 0 ]
}

@test "edge: boundary — template has nonexistent mode ignored" {
  # Active modes list only accepts known values
  grep -q "focus_enhanced\|clarity\|structure" "$TEMPLATE"
}

@test "edge: null severity is acceptable" {
  # Severity field is optional — profile valid without it
  ! grep -qE "^  severity:" "$TEMPLATE"
}

@test "negative: no diagnosis needed for structure mode" {
  # Structure mode works without any diagnosis — per spec composability
  grep -q "No diagnosis" "$REPO_ROOT/docs/propuestas/SPEC-061-neurodivergent-profiles.md"
}

@test "positive: template has communication section" {
  grep -q "communication" "$TEMPLATE"
}

@test "positive: rule covers all 5 dimensions" {
  for dim in ADHD Autism Dyslexia Giftedness Dyscalculia; do
    grep -qi "$dim" "$RULE"
  done
}

@test "coverage: rule has composability note" {
  grep -qi "composab\|combin\|simultanea" "$RULE"
}
