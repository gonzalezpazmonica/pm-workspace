#!/usr/bin/env bats
# BATS tests for block-gitignored-references.sh
# SCRIPT=.claude/hooks/block-gitignored-references.sh
# SPEC: Era 194 — Confidentiality hardening, gitignored content leak prevention

HOOK=".claude/hooks/block-gitignored-references.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="standard"
  export CLAUDE_PROJECT_DIR="$(pwd)"
}
teardown() { unset SAVIA_HOOK_PROFILE CLAUDE_PROJECT_DIR; }

# Helper: build hook input JSON
make_input() {
  printf '{"tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2"
}

# === STRUCTURAL: script integrity ===
@test "script exists and is executable" { [[ -x "$HOOK" ]]; }

@test "script has set -uo pipefail safety flags" {
  head -3 "$HOOK" | grep -q "set -uo pipefail"
}

# === COVERAGE: verify detection patterns exist in hook source ===
@test "coverage: hook checks output/ date pattern" { grep -qE 'output/\[0-9\]' "$HOOK"; }
@test "coverage: hook checks private-agent-memory" { grep -q 'private-agent-memory' "$HOOK"; }
@test "coverage: hook checks config.local pattern" { grep -q 'config\.local/' "$HOOK"; }
@test "coverage: hook checks audit score pattern" { grep -qE '/10 score|score.*100' "$HOOK"; }
@test "coverage: hook checks vulnerability count" { grep -qi 'vulnerabilit' "$HOOK"; }
@test "coverage: hook checks debt-score pattern" { grep -q 'debt-score' "$HOOK"; }
@test "coverage: hook checks .human-maps pattern" { grep -q 'human-maps' "$HOOK"; }

# === BLOCKING: content that must be rejected in N1 files ===
@test "BLOCK: output/ path with date in CHANGELOG" {
  # Dated output paths are internal report references (zero-project-leakage)
  run bash -c "printf '%s' '$(make_input "CHANGELOG.md" "Added output/20260407-audit-report.md")' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
  [[ "$output" == *"output/"* ]]
}

@test "BLOCK: private-agent-memory reference in README" {
  # Private agent memory is N2 gitignored, never in public docs
  run bash -c "printf '%s' '$(make_input "README.md" "Memory in private-agent-memory/savia/MEMORY.md")' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "BLOCK: config.local path in docs" {
  # config.local/ contains secrets, must not leak to N1
  run bash -c "printf '%s' '$(make_input "docs/setup.md" "Put secrets in config.local/secrets.env")' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"config.local"* ]]
}

@test "BLOCK: audit score pattern X.Y/10" {
  # Internal audit scores are derived metrics
  run bash -c "printf '%s' '$(make_input "CHANGELOG.md" "Audit report: 8.8/10 score, 0 critical")' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "BLOCK: quality score pattern XX/100" {
  # Score XX/100 reveals internal quality metrics
  run bash -c "printf '%s' '$(make_input "CHANGELOG.md" "Tests: 17 tests (score 85/100)")' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "BLOCK: vulnerability count in public file" {
  # Vulnerability counts are security audit internals
  run bash -c "printf '%s' '$(make_input "CHANGELOG.md" "24 vulnerabilities found, all resolved")' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"vulnerabilid"* ]]
}

@test "BLOCK: debt-score with concrete value" {
  # Concrete debt-score per project is an internal metric
  run bash -c "printf '%s' '$(make_input "CHANGELOG.md" "Human Code Map with debt-score: 3/10")' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"Debt-score"* ]]
}

@test "BLOCK: .human-maps project path" {
  # Project-specific .human-maps are internal content
  run bash -c "printf '%s' '$(make_input "CHANGELOG.md" "Added projects/savia-web/.human-maps/savia-web.hcm")' | bash $HOOK"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"human-maps"* ]]
}

# === ALLOWING: content that must pass through ===
@test "ALLOW: generic text without gitignored paths" {
  # Clean content with no sensitive references should pass
  run bash -c "printf '%s' '$(make_input "CHANGELOG.md" "Added new BATS test suite")' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

@test "ALLOW: writing TO a gitignored destination (output/)" {
  # Writing to output/ is fine — only referencing it in N1 is blocked
  run bash -c "printf '%s' '$(make_input "output/report.md" "Score: 8.8/10 score with details")' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

@test "ALLOW: writing TO projects/ directory" {
  # projects/ is itself gitignored (N4), writing there is fine
  run bash -c "printf '%s' '$(make_input "projects/alpha/notes.md" "output/20260407-audit.md")' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

@test "ALLOW: template references with placeholders" {
  # Template paths like {proyecto} are documentation, not real references
  run bash -c "printf '%s' '$(make_input "docs/guide.md" "Store in projects/{proyecto}/agent-memory/")' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

# === EDGE CASES: malformed input, missing tools, boundary conditions ===
@test "edge: empty content exits 0" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"README.md\",\"content\":\"\"}}' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

@test "edge: no stdin exits 0 gracefully" {
  # Hook must handle missing stdin without crashing
  run bash "$HOOK" < /dev/null
  [[ "$status" -eq 0 ]]
}

@test "edge: malformed JSON exits 0 gracefully" {
  run bash -c "echo 'not valid json at all' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

@test "edge: missing file_path field exits 0" {
  run bash -c "echo '{\"tool_input\":{\"content\":\"private-agent-memory/x\"}}' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}

@test "edge: test file paths are skipped (no false positives)" {
  # Hook must skip its own test files to avoid blocking test development
  run bash -c "printf '%s' '$(make_input "tests/test-foo.bats" "output/20260407-audit.md private-agent-memory/x")' | bash $HOOK"
  [[ "$status" -eq 0 ]]
}
