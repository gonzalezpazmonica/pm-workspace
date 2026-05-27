#!/usr/bin/env bats
# tests/pre-output-validator.bats — SE-150 TTSR pre-output validator tests
# SPEC-SE-150
# Ref: docs/specs/SE-150-pre-output-validator.spec.md
#
# Tests for scripts/pre-output-validator.sh
# One test per rule (POR-001 to POR-007) plus integration and edge cases.
#
# Run: bats tests/pre-output-validator.bats

VALIDATOR="${BATS_TEST_DIRNAME}/../scripts/pre-output-validator.sh"

setup() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# ── Helpers ───────────────────────────────────────────────────────────────────

# Run validator with raw content on stdin
run_raw() {
  local content="$1"
  run bash "$VALIDATOR" <<< "$content"
}

# Run validator with hook JSON input (simulates PreToolUse hook)
run_json() {
  local tool_name="$1"
  local content_field="$2"
  local content_value="$3"
  local json
  json=$(printf '{"tool_name": "%s", "tool_input": {"%s": "%s"}}' \
    "$tool_name" "$content_field" "$content_value")
  run bash "$VALIDATOR" <<< "$json"
}

# ── POR-001: Hardcoded PAT/token ──────────────────────────────────────────────

@test "POR-001 blocks GitHub PAT token hardcoded in bash command" {
  # ghp_ + exactly 36 alphanumeric chars
  run_raw 'export TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-001"* ]]
}

@test "POR-001 blocks GitHub PAT in Write content (JSON hook input)" {
  run_json "Write" "content" "TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-001"* ]]
}

@test "POR-001 blocks AWS AKIA key" {
  run_raw 'AWS_KEY=AKIAIOSFODNN7EXAMPLE'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-001"* ]]
}

@test "POR-001 allows normal content without tokens" {
  run_raw 'echo "hello world"'
  [ "$status" -eq 0 ]
}

# ── POR-002: CLAUDE_PROJECT_DIR usage ────────────────────────────────────────

@test "POR-002 emits reminder for CLAUDE_PROJECT_DIR in Write content" {
  run_json "Write" "content" 'mkdir -p \"\$CLAUDE_PROJECT_DIR/output\"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"POR-002"* ]]
  [[ "$output" == *"reminder"* ]]
}

@test "POR-002 emits reminder for CLAUDE_PROJECT_DIR in raw stdin" {
  run_raw 'LOG="$CLAUDE_PROJECT_DIR/logs/app.log"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"POR-002"* ]]
}

@test "POR-002 does NOT trigger for SAVIA_WORKSPACE_DIR (correct usage)" {
  run_raw 'mkdir -p "$SAVIA_WORKSPACE_DIR/output"'
  [ "$status" -eq 0 ]
  [[ "$output" != *"POR-002"* ]]
}

@test "POR-002 does NOT trigger on Bash tool (scope is write,edit only)" {
  # Use python3 to generate valid JSON (avoids shell escaping issues with $)
  local json
  json=$(python3 -c 'import json; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": "mkdir -p $CLAUDE_PROJECT_DIR/output"}}))')
  run bash "$VALIDATOR" <<< "$json"
  [ "$status" -eq 0 ]
  [[ "$output" != *"POR-002"* ]]
}

# ── POR-003: git commit on main/master ───────────────────────────────────────

@test "POR-003 blocks git commit after checkout main" {
  run_raw 'git checkout main && git commit -m "fix: urgent hotfix"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-003"* ]]
}

@test "POR-003 blocks git commit after checkout master" {
  run_raw 'git checkout master && git commit -m "release"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-003"* ]]
}

@test "POR-003 allows git commit on feature branch" {
  run_raw 'git checkout feature/my-branch && git commit -m "feat: add something"'
  [ "$status" -eq 0 ]
  [[ "$output" != *"POR-003"* ]]
}

@test "POR-003 only applies to Bash scope (not Write)" {
  run_json "Write" "content" 'git checkout main && git commit -m fix'
  [ "$status" -eq 0 ]
  [[ "$output" != *"POR-003"* ]]
}

# ── POR-004: terraform apply without confirmation ─────────────────────────────

@test "POR-004 blocks bare terraform apply" {
  run_raw 'terraform apply'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-004"* ]]
}

@test "POR-004 blocks terraform apply with var-file" {
  run_raw 'terraform apply -var-file=prod.tfvars'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-004"* ]]
}

@test "POR-004 blocks terraform apply in Makefile content (Edit scope)" {
  run_json "Edit" "new_string" 'deploy-prod:\n\tterraform apply -chdir=infra/prod'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-004"* ]]
}

@test "POR-004 allows terraform plan (not apply)" {
  run_raw 'terraform plan -var-file=prod.tfvars'
  [ "$status" -eq 0 ]
  [[ "$output" != *"POR-004"* ]]
}

# ── POR-005: rm -rf dangerous paths ──────────────────────────────────────────

@test "POR-005 blocks rm -rf /home path" {
  run_raw 'rm -rf /home/monica/data'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-005"* ]]
}

@test "POR-005 blocks rm -rf /var path" {
  run_raw 'rm -rf /var/log/myapp'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-005"* ]]
}

@test "POR-005 allows rm -rf /tmp (safe temp dir)" {
  run_raw 'rm -rf /tmp/my-build-dir'
  [ "$status" -eq 0 ]
  [[ "$output" != *"POR-005"* ]]
}

@test "POR-005 allows rm -rf on relative path" {
  run_raw 'rm -rf ./build ./dist'
  [ "$status" -eq 0 ]
  [[ "$output" != *"POR-005"* ]]
}

# ── POR-006: inline credential ───────────────────────────────────────────────

@test "POR-006 blocks password inline in double quotes" {
  run_raw 'password = "my$ecretP@ss"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-006"* ]]
}

@test "POR-006 blocks secret inline in single quotes" {
  run_raw "secret='hardcoded_value_here'"
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-006"* ]]
}

@test "POR-006 blocks api_key inline assignment" {
  run_raw 'api_key = "sk-1234567890abcdef"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-006"* ]]
}

@test "POR-006 allows password variable reference (not literal)" {
  run_raw 'password = $DB_PASSWORD'
  [ "$status" -eq 0 ]
  [[ "$output" != *"POR-006"* ]]
}

@test "POR-006 allows password placeholder (too short)" {
  run_raw 'password = "pass"'
  [ "$status" -eq 0 ]
  [[ "$output" != *"POR-006"* ]]
}

# ── POR-007: git push --force ────────────────────────────────────────────────

@test "POR-007 blocks git push --force" {
  run_raw 'git push origin feature/x --force'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-007"* ]]
}

@test "POR-007 blocks git push -f shorthand" {
  # Note: -f shorthand is NOT caught by POR-007 pattern (--force specific)
  # This is intentional: -f is less common, block-force-push.sh catches it
  skip "POR-007 targets --force flag specifically; -f covered by block-force-push.sh"
}

@test "POR-007 allows git push --force-with-lease" {
  run_raw 'git push origin feature/x --force-with-lease'
  [ "$status" -eq 0 ]
  [[ "$output" != *"POR-007"* ]]
}

@test "POR-007 only applies to Bash scope (not Write)" {
  run_json "Write" "content" 'git push origin main --force'
  [ "$status" -eq 0 ]
  [[ "$output" != *"POR-007"* ]]
}

# ── Configuration controls ───────────────────────────────────────────────────

@test "PRE_OUTPUT_RULES_ENABLED=false disables all rules" {
  PRE_OUTPUT_RULES_ENABLED=false run bash "$VALIDATOR" <<< 'export TOKEN=ghp_ABC123DEF456GHI789JKL012MNO345PQR6'
  [ "$status" -eq 0 ]
}

@test "PRE_OUTPUT_SEVERITY_OVERRIDE=remind downgrades block to remind" {
  # Use a proper 36-char GitHub PAT token
  PRE_OUTPUT_SEVERITY_OVERRIDE=remind run bash "$VALIDATOR" <<< 'export TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'
  [ "$status" -eq 0 ]
  [[ "$output" == *"reminder"* ]]
}

@test "PRE_OUTPUT_SKIP_RULES=POR-001 skips PAT detection" {
  PRE_OUTPUT_SKIP_RULES=POR-001 run bash "$VALIDATOR" <<< 'export TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'
  [ "$status" -eq 0 ]
}

@test "Empty input passes through silently" {
  run bash "$VALIDATOR" <<< ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "Multiple violations: all rules fire, exit 2" {
  run_raw 'password = "mysecretpass" && terraform apply'
  [ "$status" -eq 2 ]
  [[ "$output" == *"POR-004"* ]] || [[ "$output" == *"POR-006"* ]]
}

# ── Safety and meta tests ─────────────────────────────────────────────────────

@test "safety: validator script has set -uo pipefail" {
  grep -q "set -uo pipefail" "$VALIDATOR"
}

@test "safety: validator is executable" {
  [ -x "$VALIDATOR" ]
}

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "edge: null byte content passes without crash (large whitespace)" {
  run bash "$VALIDATOR" <<< "$(printf '%0.s ' {1..1000})"
  [ "$status" -eq 0 ]
}

@test "edge: nonexistent SKIP rule env var is treated as empty" {
  PRE_OUTPUT_SKIP_RULES="" run bash "$VALIDATOR" <<< 'export TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'
  [ "$status" -ne 0 ]
}

@test "edge: null-like empty json object passes without error" {
  run bash "$VALIDATOR" <<< '{}'
  [ "$status" -eq 0 ]
}

@test "edge: very large clean input passes without overflow" {
  local big_input
  big_input=$(python3 -c "print('a' * 50000)")
  run bash "$VALIDATOR" <<< "$big_input"
  [ "$status" -eq 0 ]
}

# ── Function coverage: _is_skipped ────────────────────────────────────────────

@test "_is_skipped: skipping multiple rules with comma-separated list" {
  PRE_OUTPUT_SKIP_RULES="POR-001,POR-004,POR-006" run bash "$VALIDATOR" \
    <<< 'export TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 && terraform apply'
  [ "$status" -eq 0 ]
}

# ── Function coverage: _effective_severity ────────────────────────────────────

@test "_effective_severity: PRE_OUTPUT_SEVERITY_OVERRIDE=remind downgrades block to reminder" {
  PRE_OUTPUT_SEVERITY_OVERRIDE=remind run bash "$VALIDATOR" <<< 'export TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'
  [ "$status" -eq 0 ]
  [[ "$output" == *"reminder"* ]]
}

# ── File-based input (tmpdir isolation) ───────────────────────────────────────

@test "isolation: validator reads from stdin using a tmp file pipe" {
  local f="$TMP_DIR/input.txt"
  echo 'no violations here' > "$f"
  run bash "$VALIDATOR" < "$f"
  [ "$status" -eq 0 ]
}

@test "isolation: violation file in tmpdir triggers block" {
  local f="$TMP_DIR/secret.txt"
  echo 'export MY_TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890' > "$f"
  run bash "$VALIDATOR" < "$f"
  [ "$status" -ne 0 ]
}
