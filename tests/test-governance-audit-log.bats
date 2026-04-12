#!/usr/bin/env bats
# BATS tests for SE-006 Governance & Compliance Pack — audit trail
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-006-governance-compliance.md
# SCRIPT: scripts/governance-audit-log.sh
# Ref: .claude/enterprise/rules/governance-compliance.md
# Quality gate: SPEC-055 (audit score >=80)
# Safety: tests use BATS run/status guards; target script has set -uo pipefail
# Status: active
# Date: 2026-04-12
# Era: 230
# Problem: regulated clients need tamper-evident audit trails for AI Act, DORA, NIS2
# Solution: append-only JSONL with chain hash, verify command, markdown export
# Acceptance: append works, chain verifies, tamper detected, export readable
# Dependencies: governance-audit-log.sh, governance-compliance.md

## Problem: regulated clients need tamper-evident audit trail for compliance
## Solution: chain-hashed JSONL log with append/verify/export
## Acceptance: chain integrity, tamper detection, markdown export

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/governance-audit-log.sh"
  export RULE="$REPO_ROOT/.claude/enterprise/rules/governance-compliance.md"
  TMPDIR_GOV=$(mktemp -d)
  export CLAUDE_PROJECT_DIR="$TMPDIR_GOV"
  mkdir -p "$TMPDIR_GOV/output"
}
teardown() {
  rm -rf "$TMPDIR_GOV"
}

## Structural tests

@test "governance-audit-log.sh exists, executable, valid syntax" {
  [[ -x "$SCRIPT" ]]
  bash -n "$SCRIPT"
}
@test "uses set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}
@test "governance rule exists" {
  [[ -f "$RULE" ]]
}
@test "rule documents all 6 frameworks" {
  for fw in "AI Act" "NIS2" "DORA" "GDPR" "CRA" "ISO 42001"; do
    grep -qi "$fw" "$RULE"
  done
}

## Append tests

@test "append creates log file with valid JSON entry" {
  run bash "$SCRIPT" append --action "test_create" --actor "tester"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"LOGGED"* ]]
  [[ -f "$TMPDIR_GOV/output/audit-trail.jsonl" ]]
  python3 -c "import json; json.loads(open('$TMPDIR_GOV/output/audit-trail.jsonl').readline())"
}
@test "append includes hash and prev_hash fields" {
  bash "$SCRIPT" append --action "test_hash" --actor "tester" >/dev/null
  local entry; entry=$(cat "$TMPDIR_GOV/output/audit-trail.jsonl")
  echo "$entry" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'hash' in d; assert 'prev_hash' in d"
}
@test "first entry has prev_hash=genesis" {
  bash "$SCRIPT" append --action "first" >/dev/null
  python3 -c "import json; d=json.loads(open('$TMPDIR_GOV/output/audit-trail.jsonl').readline()); assert d['prev_hash']=='genesis'"
}
@test "second entry chains to first" {
  bash "$SCRIPT" append --action "first" >/dev/null
  bash "$SCRIPT" append --action "second" >/dev/null
  python3 -c "
import json
lines = open('$TMPDIR_GOV/output/audit-trail.jsonl').readlines()
first = json.loads(lines[0])
second = json.loads(lines[1])
assert second['prev_hash'] == first['hash'], f'{second[\"prev_hash\"]} != {first[\"hash\"]}'
"
}

## Verify tests

@test "verify passes on valid chain" {
  bash "$SCRIPT" append --action "a1" >/dev/null
  bash "$SCRIPT" append --action "a2" >/dev/null
  bash "$SCRIPT" append --action "a3" >/dev/null
  run bash "$SCRIPT" verify
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"3 entries"* ]]
  [[ "$output" == *"0 broken"* ]]
}
@test "verify detects tampered entry (boundary test)" {
  bash "$SCRIPT" append --action "legit1" >/dev/null
  bash "$SCRIPT" append --action "legit2" >/dev/null
  # Tamper: modify hash of first entry (json.dumps adds space after colon)
  sed -i '1s/"hash": "[^"]*"/"hash": "tampered"/' "$TMPDIR_GOV/output/audit-trail.jsonl"
  run bash "$SCRIPT" verify
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"broken"* ]]
}
@test "verify on nonexistent log fails with error" {
  CLAUDE_PROJECT_DIR="/tmp/nonexistent" run bash "$SCRIPT" verify
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}

## Export tests

@test "export md produces readable table" {
  bash "$SCRIPT" append --action "deploy" --actor "pm" --target "v4.68" >/dev/null
  run bash "$SCRIPT" export --format md
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Audit Trail Export"* ]]
  [[ "$output" == *"deploy"* ]]
  [[ "$output" == *"pm"* ]]
}
@test "export json produces valid JSONL" {
  bash "$SCRIPT" append --action "test_json" >/dev/null
  run bash "$SCRIPT" export --format json
  python3 -c "import json; json.loads('$output'.strip().split('\n')[0])"
}

## Edge cases

@test "empty subcommand shows usage" {
  run bash "$SCRIPT"
  [[ "$output" == *"Usage"* ]]
}
@test "append without --action fails" {
  run bash "$SCRIPT" append
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}
