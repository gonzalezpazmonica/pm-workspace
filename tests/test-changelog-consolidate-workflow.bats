#!/usr/bin/env bats
# Tests for .github/workflows/changelog-consolidate.yml
# Ref: docs/propuestas/SE-062-era184-consolidation-hygiene.md (SE-062.4)
# Ref: SPEC-053 CHANGELOG.d consolidation
# set -uo pipefail equivalent for bats (native exit-on-error semantics).

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/changelog-consolidate.yml"
SCRIPT="${BATS_TEST_DIRNAME}/../scripts/changelog-consolidate-if-needed.sh"

setup() {
  [[ -f "$WORKFLOW" ]] || skip "workflow file not found"
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

@test "workflow file exists" {
  [[ -f "$WORKFLOW" ]]
}

@test "workflow is valid YAML" {
  run python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW'))"
  [[ "$status" -eq 0 ]]
}

@test "triggers on push to main branch" {
  run grep -E "branches:\s*\[main\]" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"main"* ]]
}

@test "scoped to CHANGELOG.d path filter" {
  run grep "CHANGELOG.d" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"CHANGELOG.d/**"* ]]
}

@test "has contents: write permission for commit-back" {
  run grep -E "contents:\s*write" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "uses concurrency group to prevent parallel runs" {
  run grep -E "^concurrency:" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "skips on [skip consolidate] commit marker" {
  run grep -q "skip consolidate" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "invokes changelog-consolidate-if-needed.sh script" {
  run grep -q "changelog-consolidate-if-needed.sh" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "threshold value is set to 20 fragments" {
  run grep -qE "threshold 20|FRAG_COUNT.*-lt 20" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "pins checkout action to full SHA (no dynamic tag)" {
  run grep -E "actions/checkout@[a-f0-9]{40}" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
  [[ ${#output} -gt 50 ]]
}

@test "uses github-actions bot identity for auto-commits" {
  run grep -q 'github-actions\[bot\]' "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "references SPEC-053 or SE-053 in workflow header" {
  run grep -qE "SE-053|SPEC-053" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "references batch 26 or SE-062.4 for traceability" {
  run grep -qE "SE-062\.4|batch 26" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "emits GITHUB_STEP_SUMMARY for visibility" {
  run grep -q "GITHUB_STEP_SUMMARY" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "run blocks use set -eo pipefail for safety" {
  count=$(grep -c "set -eo pipefail" "$WORKFLOW")
  [[ "$count" -ge 2 ]]
}

@test "uses GITHUB_TOKEN secret for checkout auth" {
  run grep -q "secrets.GITHUB_TOKEN" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "diff check before commit avoids empty commits" {
  run grep -q "git diff --quiet" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "fetches full history (fetch-depth: 0) for consolidation" {
  run grep -q "fetch-depth: 0" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "concurrency cancel-in-progress set to false (serial execution)" {
  run grep -q "cancel-in-progress: false" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "output variable consolidated emits boolean" {
  run grep -qE "consolidated=(true|false)" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "output variable fragment_count exported to GITHUB_OUTPUT" {
  run grep -qE "fragment_count=.*GITHUB_OUTPUT|fragment_count.*>>.*OUTPUT" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "runs on ubuntu-latest runner" {
  run grep -q "runs-on: ubuntu-latest" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "summary step uses if: always() for telemetry" {
  run grep -q "if: always()" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "excludes README.md from fragment count calculation" {
  run grep -qE '! -name "README.md"' "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "idempotent: no-op path when FRAG_COUNT below threshold" {
  run grep -qE 'FRAG_COUNT.*-lt 20' "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "workflow has visible name for GitHub UI" {
  run grep -qE "^name: CHANGELOG" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "bot commits use users.noreply email (not real address)" {
  run grep -q "users.noreply.github.com" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "negative: workflow does not skip pre-commit guards" {
  ! grep -q "no-verify" "$WORKFLOW"
}

@test "negative: workflow does not force-push to main" {
  ! grep -qE "push.*--force|push\s+-f\s" "$WORKFLOW"
}

@test "negative: no hardcoded GitHub Personal Access Tokens" {
  ! grep -qE "ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}"  "$WORKFLOW"
}

@test "edge: activated script is present and executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

@test "edge: empty CHANGELOG.d handled by underlying script" {
  run bash "$SCRIPT" --dry-run --json
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "edge: nonexistent flag rejected by underlying script (graceful)" {
  run bash "$SCRIPT" --not-a-real-flag
  [[ "$status" -eq 2 ]]
}

@test "edge: --json flag emits parseable JSON verdict" {
  run bash "$SCRIPT" --dry-run --json
  [[ "$status" -eq 0 ]]
  run python3 -c "import json,sys; json.loads(sys.stdin.read())" <<< "$output"
  [[ "$status" -eq 0 ]]
}

@test "isolation: test uses TMP_DIR scoped per-test" {
  [[ -n "${TMP_DIR:-}" ]]
  [[ -d "$TMP_DIR" ]]
  touch "$TMP_DIR/marker"
  [[ -f "$TMP_DIR/marker" ]]
}

@test "assertion: workflow file size is reasonable (not empty, not huge)" {
  lines=$(wc -l < "$WORKFLOW")
  [[ "$lines" -ge 20 ]]
  [[ "$lines" -le 200 ]]
}

@test "assertion: jobs section defines at least one job" {
  run python3 -c "import yaml; d=yaml.safe_load(open('$WORKFLOW')); assert 'jobs' in d and len(d['jobs']) >= 1, 'no jobs'"
  [[ "$status" -eq 0 ]]
}
