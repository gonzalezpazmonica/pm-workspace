#!/usr/bin/env bats
# SE-272 S2 — Tests for KPI antagonist gate and validation
# Slice 2: Contractual KPIs with verification and anti-Goodhart

setup() {
  REAL_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export ANTAGONIST_SH="$REAL_ROOT/scripts/kpi-antagonist-gate.sh"
  export CATALOG_SH="$REAL_ROOT/scripts/kpi-catalog-validate.sh"
  export COMPUTE_SH="$REAL_ROOT/scripts/kpi-compute.sh"
  export CHAIN_SH="$REAL_ROOT/scripts/kpi-custody-chain.sh"
  export REVIEW_SH="$REAL_ROOT/scripts/kpi-review-report.sh"
  TMPDIR_KPI=$(mktemp -d)
  export TMPDIR_KPI
  export REPO_ROOT="$TMPDIR_KPI"
  export ENGAGEMENT="test-client/se272-test"
  export ENG_DIR="$REPO_ROOT/engagements/test-client/se272-test"
  mkdir -p "$ENG_DIR"

  # Create a valid KPI catalog for testing
  cat > "$ENG_DIR/kpis.yaml" << 'YAMLEOF'
version: 1
last_modified: "2026-07-25"

kpis:
  - id: "kpi-001"
    name: "Sprint Velocity"
    definition: "Average SP per sprint over 3 months"
    primary_source: "commit_history"
    formula: "sum(completed_sp) / count(sprints)"
    window_months: 3
    target_threshold: 40
    warning_threshold: 30
    antagonist_kpi_id: "kpi-002"
    version: 1
    signature_1:
      name: "Alice"
      date: "2026-01-01"
      role: "stakeholder"
    signature_2:
      name: "Bob"
      date: "2026-01-01"
      role: "delivery_manager"

  - id: "kpi-002"
    name: "Defect Escape Rate"
    definition: "Production defects / total defects"
    primary_source: "incident_log"
    formula: "prod_defects / total_defects * 100"
    window_months: 3
    target_threshold: 5
    warning_threshold: 10
    antagonist_kpi_id: "kpi-001"
    version: 1
    signature_1:
      name: "Alice"
      date: "2026-01-01"
      role: "stakeholder"
    signature_2:
      name: "Bob"
      date: "2026-01-01"
      role: "delivery_manager"
YAMLEOF
}

teardown() {
  rm -rf "$TMPDIR_KPI"
}

# ──────────────────────────────────────────────────────────────────────
# 1. antagonist-gate check passes for valid pair
# ──────────────────────────────────────────────────────────────────────

@test "kpi-antagonist-gate check passes with valid pairs" {
  run bash "$ANTAGONIST_SH" check --engagement "$ENGAGEMENT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"PASSED"* ]]
}

# ──────────────────────────────────────────────────────────────────────
# 2. antagonist-gate blocks KPIs without antagonist
# ──────────────────────────────────────────────────────────────────────

@test "kpi-antagonist-gate blocks KPI without antagonist" {
  # Create catalog with missing antagonist
  cat > "$ENG_DIR/kpis.yaml" << 'YAMLEOF'
version: 1
kpis:
  - id: "bad-kpi-001"
    name: "Sprint Velocity"
    definition: "Average SP per sprint"
    primary_source: "commit_history"
    formula: "sum(sp) / count(sprints)"
    window_months: 3
    target_threshold: 40
    warning_threshold: 30
    antagonist_kpi_id: ""
    version: 1
    signature_1:
      name: "Alice"
      date: "2026-01-01"
      role: "stakeholder"
    signature_2:
      name: "Bob"
      date: "2026-01-01"
      role: "delivery_manager"
YAMLEOF

  run bash "$ANTAGONIST_SH" check --engagement "$ENGAGEMENT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"no antagonist"* || "$output" == *"BLOCKED"* ]]
}

# ──────────────────────────────────────────────────────────────────────
# 3. antagonist-gate validate-pair confirms valid pairing
# ──────────────────────────────────────────────────────────────────────

@test "kpi-antagonist-gate validate-pair confirms valid pair" {
  run bash "$ANTAGONIST_SH" validate-pair \
    --kpi-id "kpi-001" \
    --antagonist-id "kpi-002" \
    --engagement "$ENGAGEMENT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"valid"* || "$output" == *"OK"* ]]
}

# ──────────────────────────────────────────────────────────────────────
# 4. antagonist-gate validate-pair rejects mismatched pair
# ──────────────────────────────────────────────────────────────────────

@test "kpi-antagonist-gate validate-pair rejects mismatched pair" {
  run bash "$ANTAGONIST_SH" validate-pair \
    --kpi-id "kpi-001" \
    --antagonist-id "kpi-999" \
    --engagement "$ENGAGEMENT"
  [[ "$status" -ne 0 ]]
}

# ──────────────────────────────────────────────────────────────────────
# 5. kpi-catalog-validate passes for valid catalog
# ──────────────────────────────────────────────────────────────────────

@test "kpi-catalog-validate passes for valid catalog" {
  run bash "$CATALOG_SH" validate --file "$ENG_DIR/kpis.yaml"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"PASS"* ]]
}

# ──────────────────────────────────────────────────────────────────────
# 6. kpi-catalog-validate fails for catalog without version header
# ──────────────────────────────────────────────────────────────────────

@test "kpi-catalog-validate fails without version header" {
  cat > "$ENG_DIR/kpis.yaml" << 'YAMLEOF'
kpis:
  - id: "kpi-001"
    name: "Test"
    primary_source: "commit_history"
    antagonist_kpi_id: "kpi-002"
YAMLEOF

  run bash "$CATALOG_SH" validate --file "$ENG_DIR/kpis.yaml"
  [[ "$status" -ne 0 ]]
}

# ──────────────────────────────────────────────────────────────────────
# 7. kpi-catalog-validate detects missing antagonist reference
# ──────────────────────────────────────────────────────────────────────

@test "kpi-catalog-validate detects dangling antagonist reference" {
  cat > "$ENG_DIR/kpis.yaml" << 'YAMLEOF'
version: 1
kpis:
  - id: "kpi-001"
    name: "Sprint Velocity"
    definition: "Avg SP"
    primary_source: "commit_history"
    formula: "sum(sp)/count(sprints)"
    window_months: 3
    target_threshold: 40
    warning_threshold: 30
    antagonist_kpi_id: "kpi-999"
    version: 1
    signature_1:
      name: "A"
      date: "2026-01-01"
      role: "s"
    signature_2:
      name: "B"
      date: "2026-01-01"
      role: "d"
YAMLEOF

  run bash "$CATALOG_SH" validate --file "$ENG_DIR/kpis.yaml"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"FAIL"* ]]
}

# ──────────────────────────────────────────────────────────────────────
# 8. kpi-custody-chain append and verify
# ──────────────────────────────────────────────────────────────────────

@test "kpi-custody-chain append and verify works" {
  run bash "$CHAIN_SH" append \
    --engagement "$ENGAGEMENT" \
    --period "2026-07"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OK"* ]]

  # Second period
  bash "$CHAIN_SH" append \
    --engagement "$ENGAGEMENT" \
    --period "2026-08"

  run bash "$CHAIN_SH" verify --engagement "$ENGAGEMENT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"CHAIN OK"* ]]
}

# ──────────────────────────────────────────────────────────────────────
# 9. kpi-custody-chain detects tampered chain
# ──────────────────────────────────────────────────────────────────────

@test "kpi-custody-chain detects tampered chain" {
  bash "$CHAIN_SH" append --engagement "$ENGAGEMENT" --period "2026-07"
  bash "$CHAIN_SH" append --engagement "$ENGAGEMENT" --period "2026-08"

  # Tamper
  echo '{"tampered":true}' >> "$ENG_DIR/kpi-chain.jsonl"

  run bash "$CHAIN_SH" verify --engagement "$ENGAGEMENT"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"TAMPERED"* || "$output" == *"CHAIN FAIL"* ]]
}

# ──────────────────────────────────────────────────────────────────────
# 10. kpi-review-report generate
# ──────────────────────────────────────────────────────────────────────

@test "kpi-review-report generates period report" {
  bash "$CHAIN_SH" append --engagement "$ENGAGEMENT" --period "2026-07"

  run bash "$REVIEW_SH" generate \
    --engagement "$ENGAGEMENT" \
    --period "2026-07"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Review report generated"* ]]
}

# ──────────────────────────────────────────────────────────────────────
# 11. kpi-review-report amend with dual signatures
# ──────────────────────────────────────────────────────────────────────

@test "kpi-review-report amend records with dual signatures" {
  run bash "$REVIEW_SH" amend \
    --engagement "$ENGAGEMENT" \
    --kpi-id "kpi-001" \
    --field "target_threshold" \
    --old-value "40" \
    --new-value "45" \
    --signature-1 "Alice,Stakeholder" \
    --signature-2 "Bob,Delivery Manager" \
    --justification "Updated based on Q2 performance review"

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OK"* ]]
  [[ "$output" == *"Version bumped"* ]]
  [[ -f "$ENG_DIR/kpi-amendments.jsonl" ]]
  [[ -f "$ENG_DIR/kpi-versions.jsonl" ]]
}

# ──────────────────────────────────────────────────────────────────────
# 12. kpi-review-report version-catalog shows history
# ──────────────────────────────────────────────────────────────────────

@test "kpi-review-report version-catalog shows version history" {
  bash "$REVIEW_SH" amend \
    --engagement "$ENGAGEMENT" \
    --kpi-id "kpi-001" \
    --field "target_threshold" \
    --old-value "40" \
    --new-value "45" \
    --signature-1 "Alice,Stakeholder" \
    --signature-2 "Bob,Delivery Manager"

  bash "$REVIEW_SH" amend \
    --engagement "$ENGAGEMENT" \
    --kpi-id "kpi-001" \
    --field "warning_threshold" \
    --old-value "30" \
    --new-value "35" \
    --signature-1 "Alice,Stakeholder" \
    --signature-2 "Bob,Delivery Manager"

  run bash "$REVIEW_SH" version-catalog --engagement "$ENGAGEMENT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"KPI Version Catalog"* ]]
  [[ "$output" == *"kpi-001"* ]]
}

# ──────────────────────────────────────────────────────────────────────
# 13. kpi-antagonist-gate anomaly detection
# ──────────────────────────────────────────────────────────────────────

@test "kpi-antagonist-gate anomaly runs without crash" {
  bash "$CHAIN_SH" append --engagement "$ENGAGEMENT" --period "2026-07"
  bash "$CHAIN_SH" append --engagement "$ENGAGEMENT" --period "2026-08"

  run bash "$ANTAGONIST_SH" anomaly --engagement "$ENGAGEMENT"
  [[ "$status" -eq 0 ]]
}

# ──────────────────────────────────────────────────────────────────────
# 14. kpi-catalog-validate rejects self-declared source warning
# ──────────────────────────────────────────────────────────────────────

@test "kpi-catalog-validate warns on non-verifiable source" {
  cat > "$ENG_DIR/kpis.yaml" << 'YAMLEOF'
version: 1
kpis:
  - id: "kpi-001"
    name: "Self Reported"
    definition: "A self-reported metric"
    primary_source: "self_declared_survey"
    formula: "avg(responses)"
    window_months: 3
    target_threshold: 80
    warning_threshold: 60
    antagonist_kpi_id: "kpi-002"
    version: 1
    signature_1:
      name: "A"
      date: "2026-01-01"
      role: "s"
    signature_2:
      name: "B"
      date: "2026-01-01"
      role: "d"
  - id: "kpi-002"
    name: "Quality Check"
    definition: "QA check metric"
    primary_source: "qa_certificates"
    formula: "pass/total*100"
    window_months: 3
    target_threshold: 95
    warning_threshold: 90
    antagonist_kpi_id: "kpi-001"
    version: 1
    signature_1:
      name: "A"
      date: "2026-01-01"
      role: "s"
    signature_2:
      name: "B"
      date: "2026-01-01"
      role: "d"
YAMLEOF

  run bash "$CATALOG_SH" validate --file "$ENG_DIR/kpis.yaml"
  # May pass or fail - self_declared_survey warns but catalog may still pass
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  # Must at least mention the warning
  [[ "$output" == *"self_declared_survey"* || "$output" == *"WARN"* || "$output" == *"warn"* ]]
}

# ──────────────────────────────────────────────────────────────────────
# 15. kpi-compute.sh exists and is executable
# ──────────────────────────────────────────────────────────────────────

@test "kpi-compute scripts exist and are executable" {
  [[ -x "$ANTAGONIST_SH" ]]
  [[ -x "$CATALOG_SH" ]]
  [[ -x "$COMPUTE_SH" ]]
  [[ -x "$CHAIN_SH" ]]
  [[ -x "$REVIEW_SH" ]]
}
