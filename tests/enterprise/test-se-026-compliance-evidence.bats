#!/usr/bin/env bats
# test-se-026-compliance-evidence.bats — SPEC-SE-026 Compliance Evidence Automation
# Tests for compliance-evidence-collector.sh, compliance-report-generator.sh
# Reference: docs/propuestas/savia-enterprise/SPEC-SE-026-compliance-evidence.md

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  COLLECTOR="${REPO_ROOT}/scripts/enterprise/compliance-evidence-collector.sh"
  REPORTER="${REPO_ROOT}/scripts/enterprise/compliance-report-generator.sh"
  EVIDENCE_DOC="${REPO_ROOT}/docs/rules/domain/enterprise-compliance-evidence.md"
  export COLLECTOR REPORTER EVIDENCE_DOC
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: compliance-evidence-collector.sh exists and is executable ────────

@test "compliance-evidence-collector.sh exists and is executable" {
  [[ -f "$COLLECTOR" ]]
  [[ -x "$COLLECTOR" ]]
}

# ── Test 2: collector creates output directory ────────────────────────────────

@test "collector creates output/compliance-evidence directory" {
  # Patch OUTPUT_BASE to tmpdir
  sed "s|OUTPUT_BASE=.*|OUTPUT_BASE=\"${TEST_TMPDIR}/compliance-evidence\"|" "$COLLECTOR" > "${TEST_TMPDIR}/patched-collector.sh"
  chmod +x "${TEST_TMPDIR}/patched-collector.sh"

  run "${TEST_TMPDIR}/patched-collector.sh" --framework eu-ai-act --date "2026-06-24"
  [ "$status" -eq 0 ]
  [[ -d "${TEST_TMPDIR}/compliance-evidence" ]]
}

# ── Test 3: index.json has required fields ────────────────────────────────────

@test "index.json contains framework, artifacts, generated_at fields" {
  sed "s|OUTPUT_BASE=.*|OUTPUT_BASE=\"${TEST_TMPDIR}/compliance-evidence\"|" "$COLLECTOR" > "${TEST_TMPDIR}/patched-collector.sh"
  chmod +x "${TEST_TMPDIR}/patched-collector.sh"

  run "${TEST_TMPDIR}/patched-collector.sh" --framework eu-ai-act --date "2026-06-24"
  [ "$status" -eq 0 ]

  local index="${TEST_TMPDIR}/compliance-evidence/2026-06-24/index.json"
  [[ -f "$index" ]]

  grep -q '"framework"'     "$index"
  grep -q '"generated_at"' "$index"
  # artifacts field (either artifacts_total or artifacts array)
  grep -q '"artifacts' "$index"
}

# ── Test 4: compliance-report-generator.sh exists and is executable ──────────

@test "compliance-report-generator.sh exists and is executable" {
  [[ -f "$REPORTER" ]]
  [[ -x "$REPORTER" ]]
}

# ── Test 5: generated report contains required sections ──────────────────────

@test "generated report contains all required sections" {
  local report_file="${TEST_TMPDIR}/test-report.md"
  run "$REPORTER" --framework eu-ai-act --output-file "$report_file"
  [ "$status" -eq 0 ]
  [[ -f "$report_file" ]]

  grep -qi "Executive Summary" "$report_file"
  grep -qi "Findings"          "$report_file"
  grep -qi "Evidence"          "$report_file"
  grep -qi "Gaps"              "$report_file"
  grep -qi "Remediation"       "$report_file"
}

# ── Test 6: eu-ai-act collector produces more than 0 artifacts ───────────────

@test "eu-ai-act framework produces more than 0 artifact entries in index" {
  # Run against the real repo so ROOT_DIR is correct; redirect output to tmpdir
  local out_dir="${TEST_TMPDIR}/compliance-evidence"
  sed "s|OUTPUT_BASE=.*|OUTPUT_BASE=\"${out_dir}\"|" "$COLLECTOR" > "${TEST_TMPDIR}/patched-collector.sh"
  chmod +x "${TEST_TMPDIR}/patched-collector.sh"

  # Run with real REPO_ROOT so paths resolve correctly
  run bash -c "cd '${REPO_ROOT}' && '${TEST_TMPDIR}/patched-collector.sh' --framework eu-ai-act --date 2026-06-24"
  [ "$status" -eq 0 ]

  local index="${out_dir}/2026-06-24/index.json"
  [[ -f "$index" ]]

  # Index must reference at least 1 artifact label (collected or not — evidence of attempt)
  local label_count
  label_count="$(grep -o '"label"' "$index" | wc -l | tr -d ' ')"
  [ "$label_count" -gt 0 ]
}

# ── Test 7: enterprise-compliance-evidence.md exists ─────────────────────────

@test "enterprise-compliance-evidence.md exists" {
  [[ -f "$EVIDENCE_DOC" ]]
}
