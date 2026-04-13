#!/usr/bin/env bats
# tests/test-business-case-valuation.bats
# BATS tests for SE-016 Project Valuation (Business-Case-as-Code)
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-016-project-valuation.md
# Quality gate: SPEC-055 (audit score >=80)
# Safety: set -uo pipefail in target script; tests use run/status guards
# Date: 2026-04-14 | Era: 233

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/case-validate.sh"
  export RULE="$REPO_ROOT/.claude/rules/domain/business-case-as-code.md"
  export SCHEMA="$REPO_ROOT/schemas/business-case-frontmatter.schema.json"
  TMPDIR_CASE=$(mktemp -d)
}
teardown() {
  rm -rf "$TMPDIR_CASE"
}

# ── Script structure ───────────────────────────────────────────────────────

@test "case-validate.sh exists and is executable" {
  [[ -x "$SCRIPT" ]]
}
@test "case-validate.sh uses set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}
@test "case-validate.sh defines validate_case function" {
  grep -q "validate_case()" "$SCRIPT"
}
@test "case-validate.sh defines check_duplicate_cases function" {
  grep -q "check_duplicate_cases()" "$SCRIPT"
}

# ── Rule file ──────────────────────────────────────────────────────────────

@test "business-case-as-code.md exists" {
  [[ -f "$RULE" ]]
}
@test "business-case-as-code.md is <=150 lines" {
  local lines
  lines=$(wc -l < "$RULE")
  [[ $lines -le 150 ]]
}
@test "rule references SE-016" {
  grep -q "SE-016" "$RULE"
}
@test "rule references 4 agents" {
  local count
  count=$(grep -cE "valuation-recomputer|benefit-reviewer|portfolio-scorer|valuation-sentinel" "$RULE")
  [[ $count -ge 4 ]]
}
@test "rule references 6 failure modes" {
  grep -q "6 failure modes" "$RULE"
}
@test "rule documents NPV formula" {
  grep -qi "NPV" "$RULE"
}

# ── JSON Schema ────────────────────────────────────────────────────────────

@test "business-case-frontmatter.schema.json exists and is valid JSON" {
  [[ -f "$SCHEMA" ]]
  python3 -c "import json; json.load(open('$SCHEMA'))" 2>/dev/null || \
    jq . "$SCHEMA" >/dev/null 2>&1
}
@test "schema requires case_id and status fields" {
  grep -q '"case_id"' "$SCHEMA"
  grep -q '"status"' "$SCHEMA"
}
@test "schema defines status enum with 5 values" {
  grep -q '"draft"' "$SCHEMA"
  grep -q '"active"' "$SCHEMA"
  grep -q '"paused"' "$SCHEMA"
  grep -q '"completed"' "$SCHEMA"
  grep -q '"killed"' "$SCHEMA"
}
@test "schema defines benefit_realization_status enum" {
  grep -q '"not-started"' "$SCHEMA"
  grep -q '"tracking"' "$SCHEMA"
  grep -q '"realized"' "$SCHEMA"
  grep -q '"missed"' "$SCHEMA"
}
@test "schema requires variance_alerts object" {
  grep -q '"variance_alerts"' "$SCHEMA"
}

# ── Commands ───────────────────────────────────────────────────────────────

@test "case-init command exists" {
  [[ -f "$REPO_ROOT/.claude/commands/case-init.md" ]]
}
@test "case-recompute command exists" {
  [[ -f "$REPO_ROOT/.claude/commands/case-recompute.md" ]]
}
@test "case-review command exists" {
  [[ -f "$REPO_ROOT/.claude/commands/case-review.md" ]]
}
@test "case-kill-check command exists" {
  [[ -f "$REPO_ROOT/.claude/commands/case-kill-check.md" ]]
}
@test "case commands have name in frontmatter" {
  for cmd in case-init case-recompute case-review case-kill-check; do
    grep -q "^name:" "$REPO_ROOT/.claude/commands/${cmd}.md"
  done
}

# ── Script behavior ────────────────────────────────────────────────────────

@test "case-validate.sh runs without error on empty filesystem" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"No valuation directories"* ]]
}
@test "case-validate.sh shows SE-016 banner when cases exist" {
  local val_dir="$TMPDIR_CASE/banner-test"
  mkdir -p "$val_dir"
  cat > "$val_dir/business-case.md" <<'CASE'
---
case_id: "BC-2026-099"
status: "draft"
---
CASE
  run bash "$SCRIPT" "$val_dir"
  [[ "$output" == *"Business Case Validation"* ]]
  [[ "$output" == *"SE-016"* ]]
}
@test "case-validate.sh fails with nonexistent directory" {
  run bash "$SCRIPT" "/tmp/nonexistent-$(date +%s)"
  [[ "$status" -eq 1 ]]
}

# ── Failure mode: risk without probability ─────────────────────────────────

@test "case-validate detects risk without probability" {
  local val_dir="$TMPDIR_CASE/valuation"
  mkdir -p "$val_dir"
  cat > "$val_dir/business-case.md" <<'CASE'
---
case_id: "BC-2026-001"
status: "active"
variance_alerts:
  cost: { threshold_pct: 15, current_pct: 5, status: "green" }
---
CASE
  cat > "$val_dir/risk-register.yaml" <<'RISK'
risks:
  - id: "R-001"
    description: "Test risk"
    impact_eur: 50000
RISK
  run bash "$SCRIPT" "$val_dir"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"probability"* ]] || [[ "$output" == *"FAIL"* ]]
}

# ── Failure mode: risk without impact ──────────────────────────────────────

@test "case-validate detects risk without impact" {
  local val_dir="$TMPDIR_CASE/valuation2"
  mkdir -p "$val_dir"
  cat > "$val_dir/business-case.md" <<'CASE'
---
case_id: "BC-2026-002"
status: "draft"
---
CASE
  cat > "$val_dir/risk-register.yaml" <<'RISK'
risks:
  - id: "R-001"
    description: "Test risk"
    probability: 0.5
RISK
  run bash "$SCRIPT" "$val_dir"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"impact"* ]] || [[ "$output" == *"FAIL"* ]]
}

# ── Valid case passes ──────────────────────────────────────────────────────

@test "case-validate passes on valid case" {
  local val_dir="$TMPDIR_CASE/valuation3"
  mkdir -p "$val_dir"
  cat > "$val_dir/business-case.md" <<'CASE'
---
case_id: "BC-2026-003"
status: "draft"
---
CASE
  run bash "$SCRIPT" "$val_dir"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"PASS"* ]]
}
