#!/usr/bin/env bats
# Tests for .github/workflows/changelog-consolidate.yml (SE-062.4 / SE-053 activation)

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/changelog-consolidate.yml"

setup() {
  [[ -f "$WORKFLOW" ]] || skip "workflow file not found"
}

@test "workflow file exists" {
  [[ -f "$WORKFLOW" ]]
}

@test "workflow is valid YAML" {
  run python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW'))"
  [[ "$status" -eq 0 ]]
}

@test "triggers on push to main" {
  run grep -E "branches:\s*\[main\]" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "scoped to CHANGELOG.d path filter" {
  run grep "CHANGELOG.d" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
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
  run grep "skip consolidate" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "invokes changelog-consolidate-if-needed.sh" {
  run grep "changelog-consolidate-if-needed.sh" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "threshold value is 20" {
  run grep -E "threshold 20|FRAG_COUNT.*-lt 20" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "pins checkout action to SHA (no @vN)" {
  run grep -E "actions/checkout@[a-f0-9]{40}" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "github-actions bot authored commits" {
  run grep "github-actions\[bot\]" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "references SE-053 in workflow header" {
  run grep "SE-053" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "references batch 26 / SE-062.4" {
  run grep -E "SE-062\.4|batch 26" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "emits step summary" {
  run grep "GITHUB_STEP_SUMMARY" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "set -eo pipefail in run blocks" {
  run grep -E "set -eo pipefail" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "uses GITHUB_TOKEN for checkout" {
  run grep "secrets.GITHUB_TOKEN" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "diff check before commit to avoid empty commits" {
  run grep "git diff --quiet" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "fetches full history for consolidation context" {
  run grep "fetch-depth: 0" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "uses concurrency cancel-in-progress false (serial)" {
  run grep "cancel-in-progress: false" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "output variable consolidated boolean" {
  run grep "consolidated=true\|consolidated=false" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "output variable fragment_count" {
  run grep "fragment_count=" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "runs on ubuntu-latest" {
  run grep "runs-on: ubuntu-latest" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "summary always runs (if: always)" {
  run grep "if: always()" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "excludes README.md from fragment count" {
  run grep -E "! -name \"README.md\"" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "idempotent: safe on zero fragments" {
  # The workflow checks FRAG_COUNT < 20 before consolidating
  run grep -E '\$FRAG_COUNT.*-lt 20' "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "workflow name visible in UI" {
  run grep "^name: CHANGELOG Consolidate" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "git config uses noreply email" {
  run grep "users.noreply.github.com" "$WORKFLOW"
  [[ "$status" -eq 0 ]]
}

@test "does not skip hooks with --no-verify" {
  ! grep -q "no-verify" "$WORKFLOW"
}

@test "does not force push" {
  ! grep -qE "push.*--force|push.*-f " "$WORKFLOW"
}

@test "no hardcoded secrets" {
  ! grep -qE "ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}" "$WORKFLOW"
}

@test "existing consolidate script is executable" {
  [[ -x "${BATS_TEST_DIRNAME}/../scripts/changelog-consolidate-if-needed.sh" ]]
}
