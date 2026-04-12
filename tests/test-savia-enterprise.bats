#!/usr/bin/env bats
# BATS tests for SE-010 Migration Path & Backward Compat
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-010-migration-path.md
# SCRIPT: scripts/savia-enterprise.sh
# Ref: .claude/enterprise/manifest.json
# Quality gate: SPEC-055 (audit score >=80)
# Safety: tests use BATS run/status guards; target script has set -uo pipefail
# Status: active
# Date: 2026-04-12
# Era: 227
# Problem: Enterprise modules must be opt-in, reversible, no residue on uninstall
# Solution: savia-enterprise.sh with status/modules/enable/disable/uninstall/migrate-data
# Acceptance: 6 criteria (command, manifest respect, golden set, reversibility, docs, clean uninstall)
# Dependencies: savia-enterprise.sh, enterprise-helpers.sh, manifest.json

## Problem: Enterprise activation must be opt-in, reversible, zero residue
## Solution: lifecycle manager with 6 subcommands + helper library
## Acceptance: enable/disable cycle, status reflects changes, manifest updated

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/savia-enterprise.sh"
  export HELPERS="$REPO_ROOT/scripts/lib/enterprise-helpers.sh"
  export MANIFEST="$REPO_ROOT/.claude/enterprise/manifest.json"
  # Save manifest state for restore
  cp "$MANIFEST" "$MANIFEST.bak"
}
teardown() {
  # Restore manifest to original state
  [[ -f "$MANIFEST.bak" ]] && mv "$MANIFEST.bak" "$MANIFEST"
}

## Structural tests

@test "savia-enterprise.sh exists, executable, valid syntax" {
  [[ -x "$SCRIPT" ]]
  bash -n "$SCRIPT"
}
@test "enterprise-helpers.sh exists and valid syntax" {
  [[ -f "$HELPERS" ]]
  bash -n "$HELPERS"
}
@test "savia-enterprise.sh uses set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

## Status command

@test "status shows Community mode when all modules disabled" {
  run bash "$SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Community"* ]]
  [[ "$output" == *"0/"* ]]
}
@test "status shows Enterprise mode after enabling a module" {
  bash "$SCRIPT" enable code-review-court >/dev/null
  run bash "$SCRIPT" status
  [[ "$output" == *"Enterprise"* ]]
  [[ "$output" == *"1/"* ]]
}

## Modules command

@test "modules lists all 16 entries" {
  run bash "$SCRIPT" modules
  [[ "$status" -eq 0 ]]
  local count; count=$(echo "$output" | grep -c "\[OFF\]\|\[ON \]")
  [[ "$count" -ge 16 ]]
}

## Enable/disable cycle (reversibility test — AC4)

@test "enable activates a module in manifest" {
  run bash "$SCRIPT" enable multi-tenant
  [[ "$output" == *"ENABLED"* ]]
  grep -q '"enabled": true' "$MANIFEST" || python3 -c "import json; assert json.load(open('$MANIFEST'))['modules']['multi-tenant']['enabled']"
}
@test "disable deactivates a module" {
  bash "$SCRIPT" enable multi-tenant >/dev/null
  run bash "$SCRIPT" disable multi-tenant
  [[ "$output" == *"DISABLED"* ]]
  [[ "$output" == *"Core behavior restored"* ]]
}
@test "enable then disable returns to original state" {
  local before; before=$(cat "$MANIFEST")
  bash "$SCRIPT" enable governance-pack >/dev/null
  bash "$SCRIPT" disable governance-pack >/dev/null
  local after; after=$(cat "$MANIFEST")
  [[ "$before" == "$after" ]]
}
@test "enable nonexistent module fails" {
  run bash "$SCRIPT" enable nonexistent-module
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}
@test "enable already-enabled module is idempotent" {
  bash "$SCRIPT" enable code-review-court >/dev/null
  run bash "$SCRIPT" enable code-review-court
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"already enabled"* ]]
}

## Helper library

@test "enterprise_enabled returns 1 when module disabled" {
  source "$HELPERS"
  ! enterprise_enabled "multi-tenant"
}
@test "enterprise_enabled returns 0 when module enabled" {
  bash "$SCRIPT" enable multi-tenant >/dev/null
  source "$HELPERS"
  enterprise_enabled "multi-tenant"
}
@test "enterprise_mode returns community when all disabled" {
  source "$HELPERS"
  [[ "$(enterprise_mode)" == "community" ]]
}
@test "enterprise_mode returns enterprise when any enabled" {
  bash "$SCRIPT" enable observability >/dev/null
  source "$HELPERS"
  [[ "$(enterprise_mode)" == "enterprise" ]]
}

## Edge cases

@test "empty subcommand shows usage" {
  run bash "$SCRIPT"
  [[ "$output" == *"Usage"* ]]
}
@test "migrate-data without module shows error" {
  run bash "$SCRIPT" migrate-data
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}
@test "nonexistent manifest gives clear error" {
  CLAUDE_PROJECT_DIR="/tmp/nonexistent" run bash "$SCRIPT" status
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}
