#!/usr/bin/env bats
# test-block-gitignored-references.bats — Tests for gitignored content leak prevention
# Verifies that the hook blocks references to gitignored paths in public files.

HOOK=".claude/hooks/block-gitignored-references.sh"

setup() {
  [[ -f "$HOOK" ]] || skip "Hook not found"
  command -v jq &>/dev/null || skip "jq required"
  export CLAUDE_PROJECT_DIR="$PWD"
  export SAVIA_HOOK_PROFILE="standard"
}

# Helper: create hook input JSON for Edit/Write
make_input() {
  local file_path="$1"
  local content="$2"
  printf '{"tool_input":{"file_path":"%s","content":"%s"}}' "$file_path" "$content"
}

# === BLOCKING: should detect and reject ===

@test "BLOCK: output/ path with date in CHANGELOG" {
  input=$(make_input "CHANGELOG.md" "Added output/20260407-audit-report.md with results")
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
  [[ "$output" == *"output/"* ]]
}

@test "BLOCK: private-agent-memory reference in README" {
  input=$(make_input "README.md" "Memory stored in private-agent-memory/savia/MEMORY.md")
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "BLOCK: config.local path in docs" {
  input=$(make_input "docs/setup.md" "Put secrets in config.local/secrets.env")
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"config.local"* ]]
}

@test "BLOCK: audit score pattern (X.Y/10)" {
  input=$(make_input "CHANGELOG.md" "Audit report: 8.8/10 score, 0 critical")
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "BLOCK: quality score pattern (XX/100)" {
  input=$(make_input "CHANGELOG.md" "Tests: 17 tests (score 85/100)")
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 2 ]]
}

@test "BLOCK: vulnerability count in public file" {
  input=$(make_input "CHANGELOG.md" "24 vulnerabilities found, all resolved")
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"vulnerabilid"* ]]
}

@test "BLOCK: debt-score with concrete value" {
  input=$(make_input "CHANGELOG.md" "Human Code Map with debt-score: 3/10")
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"Debt-score"* ]]
}

@test "BLOCK: .human-maps project path" {
  input=$(make_input "CHANGELOG.md" "Added projects/savia-web/.human-maps/savia-web.hcm")
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"human-maps"* ]]
}

# === ALLOWING: should pass through ===

@test "ALLOW: generic text without gitignored paths" {
  input=$(make_input "CHANGELOG.md" "Added new BATS test suite for credential scanning")
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

@test "ALLOW: writing TO a gitignored file (output/)" {
  input=$(make_input "output/report.md" "Score: 8.8/10 with private-agent-memory details")
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

@test "ALLOW: writing TO projects/ directory" {
  input=$(make_input "projects/alpha/notes.md" "output/20260407-audit.md details here")
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

@test "ALLOW: generic project template references" {
  input=$(make_input "docs/guide.md" 'Store data in projects/{proyecto}/agent-memory/')
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

@test "ALLOW: empty content" {
  input='{"tool_input":{"file_path":"README.md","content":""}}'
  run bash -c "printf '%s' '$input' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

@test "ALLOW: no input" {
  run bash $HOOK < /dev/null
  [[ "$status" -eq 0 ]]
}
