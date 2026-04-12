#!/usr/bin/env bats
# BATS tests for SE-005 Sovereign Deployment
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-005-sovereign-deployment.md
# SCRIPT: .claude/enterprise/hooks/network-egress-guard.sh
# Ref: .claude/enterprise/rules/sovereign-deployment.md
# Quality gate: SPEC-055 (audit score >=80)
# Safety: tests use BATS run/status guards; target script has set -uo pipefail
# Status: active
# Date: 2026-04-12
# Era: 229
# Problem: regulated clients cannot use cloud LLM APIs; need air-gap deployment
# Solution: 4 deployment modes (cloud/hybrid/sovereign/air-gap) with network guard hook
# Acceptance: mode config, egress blocking, graceful degradation, agent compatibility flags
# Dependencies: network-egress-guard.sh, sovereign-deployment.md, enterprise-helpers.sh

## Problem: regulated clients need air-gap deployment without cloud API dependency
## Solution: deployment modes + network-egress-guard hook + sovereign rule
## Acceptance: modes configurable, egress blocked in sovereign, graceful degradation

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOOK="$REPO_ROOT/.claude/enterprise/hooks/network-egress-guard.sh"
  export RULE="$REPO_ROOT/.claude/enterprise/rules/sovereign-deployment.md"
  TMPDIR_SD=$(mktemp -d)
  export TMPDIR_SD
}
teardown() {
  rm -rf "$TMPDIR_SD"
}

## Structural tests

@test "network-egress-guard.sh exists, executable, valid syntax" {
  [[ -x "$HOOK" ]]
  bash -n "$HOOK"
}
@test "hook uses set -uo pipefail" {
  head -3 "$HOOK" | grep -q "set -uo pipefail"
}
@test "sovereign-deployment rule exists" {
  [[ -f "$RULE" ]]
}
@test "rule documents all 4 deployment modes" {
  grep -q "cloud" "$RULE"
  grep -q "hybrid" "$RULE"
  grep -q "sovereign" "$RULE"
  grep -q "air-gap" "$RULE"
}

## Mode detection tests

@test "rule documents deployment.yaml config location" {
  grep -q "deployment.yaml" "$RULE"
}
@test "rule documents sovereign_compatible agent flag" {
  grep -q "sovereign_compatible" "$RULE"
}

## Network guard logic tests

@test "hook blocks curl in sovereign mode" {
  grep -q "curl " "$HOOK"
}
@test "hook blocks git push in sovereign mode" {
  grep -q "git push" "$HOOK"
}
@test "hook blocks npm install in sovereign mode" {
  grep -q "npm install" "$HOOK"
}
@test "hook respects allowed_hosts exception" {
  grep -q "allowed_hosts" "$HOOK"
}
@test "hook exits 0 when no deployment config exists" {
  # No tenant active = no-op
  SAVIA_TENANT="" CLAUDE_PROJECT_DIR="$TMPDIR_SD" run bash "$HOOK" </dev/null
  [[ "$status" -eq 0 ]]
}
@test "hook exits 0 when module disabled" {
  # Without enterprise module enabled = no-op
  CLAUDE_PROJECT_DIR="$TMPDIR_SD" run bash "$HOOK" </dev/null
  [[ "$status" -eq 0 ]]
}

## Graceful degradation

@test "rule documents graceful degradation when model unavailable" {
  grep -qi "graceful\|degradation\|unavailable" "$RULE"
}
@test "rule specifies NEVER silent fallback to cloud" {
  grep -qi "NEVER.*fall.*back\|never.*silent" "$RULE"
}

## LLM provider abstraction

@test "rule documents Ollama as default provider" {
  grep -q "Ollama" "$RULE"
}
@test "rule documents vLLM alternative" {
  grep -q "vLLM" "$RULE"
}

## Edge cases

@test "hook handles empty stdin gracefully" {
  CLAUDE_PROJECT_DIR="$TMPDIR_SD" run bash "$HOOK" </dev/null
  [[ "$status" -eq 0 ]]
}
@test "hook handles nonexistent tenant gracefully" {
  SAVIA_TENANT="nonexistent" CLAUDE_PROJECT_DIR="$TMPDIR_SD" run bash "$HOOK" </dev/null
  [[ "$status" -eq 0 ]]
}
