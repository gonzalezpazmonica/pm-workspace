#!/usr/bin/env bats
# test-se-016-valuation.bats — SE-016 Project Valuation
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-016-project-valuation.md

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  VALUATION="${REPO_ROOT}/scripts/enterprise/project-valuation.sh"
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR REPO_ROOT
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "SE-016: project-valuation.sh exists and is executable" {
  [[ -f "$VALUATION" ]]
  [[ -x "$VALUATION" ]]
}

@test "SE-016: project-valuation.sh fails without required args" {
  run bash "$VALUATION"
  [ "$status" -eq 2 ]
  [[ "$output" == *"required"* ]]
}

@test "SE-016: project-valuation.sh produces valid JSON output" {
  local config_file="${TEST_TMPDIR}/val.conf"
  cat > "$config_file" <<'EOF'
revenue_impact=100000
cost_reduction=50000
risk_mitigation=20000
strategic_value=7
investment=200000
wacc=0.08
years=3
risk_factor=0.20
EOF

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${VALUATION}' \
    --project myproject --tenant mytenant --config '${config_file}'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"npv_eur"* ]]
  [[ "$output" == *"irr_pct"* ]]
  [[ "$output" == *"payback_months"* ]]
  [[ "$output" == *"risk_adjusted_value"* ]]
  [[ "$output" == *"confidence"* ]]
}

@test "SE-016: project-valuation.sh NPV is negative for poor investment" {
  local config_file="${TEST_TMPDIR}/bad.conf"
  cat > "$config_file" <<'EOF'
revenue_impact=1000
cost_reduction=0
risk_mitigation=0
strategic_value=2
investment=500000
wacc=0.10
years=3
risk_factor=0.30
EOF

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${VALUATION}' \
    --project badproject --tenant t --config '${config_file}'"
  [ "$status" -eq 0 ]
  # NPV should be negative — value after -inv is deeply negative
  [[ "$output" == *"npv_eur\":-"* ]]
}

@test "SE-016: project-valuation.sh creates business-case.yaml in project dir" {
  local config_file="${TEST_TMPDIR}/ok.conf"
  cat > "$config_file" <<'EOF'
revenue_impact=80000
cost_reduction=40000
investment=150000
wacc=0.08
years=3
risk_factor=0.15
EOF

  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${VALUATION}' \
    --project erp-migration --tenant acme --config '${config_file}'" >/dev/null

  [[ -f "${TEST_TMPDIR}/tenants/acme/projects/erp-migration/valuation/business-case.yaml" ]]
}

@test "SE-016: project-valuation.sh payback is reasonable for good investment" {
  local config_file="${TEST_TMPDIR}/good.conf"
  cat > "$config_file" <<'EOF'
revenue_impact=200000
cost_reduction=100000
investment=150000
wacc=0.08
years=3
risk_factor=0.10
EOF

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${VALUATION}' \
    --project fast --tenant t --config '${config_file}'"
  [ "$status" -eq 0 ]
  # payback should be < 24 months for this ratio
  payback=$(echo "$output" | grep -o '"payback_months":[0-9]*' | cut -d: -f2)
  [[ "$payback" -lt 24 ]]
}
