#!/usr/bin/env bats
# test-sealed-contracts.bats — SPEC-188 Fase 2 validation
# Verifica la estructura y coherencia del sistema de contract tests

ALLOWLIST=".claude/contracts/allowlist.txt"
CONTRACTS_DIR="tests/contracts"
HOOK=".opencode/hooks/contract-test-guard.sh"

setup() {
  export CLAUDE_PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
}

# --- Estructura del sistema ---

@test "allowlist exists and is non-empty" {
  [[ -s "$ALLOWLIST" ]]
}

@test "allowlist has at least 5 sealed paths" {
  count=$(grep -v '^#' "$ALLOWLIST" | grep -v '^$' | wc -l)
  [[ "$count" -ge 5 ]]
}

@test "contracts/ directory exists" {
  [[ -d "$CONTRACTS_DIR" ]]
}

@test "contracts/README.md exists" {
  [[ -f "$CONTRACTS_DIR/README.md" ]]
}

@test "contract-test-guard hook exists and is executable" {
  [[ -x "$HOOK" ]]
}

@test "sealed-contract-tests.md doc exists" {
  [[ -f "docs/rules/domain/sealed-contract-tests.md" ]]
}

# --- Coherencia allowlist <-> contracts/ ---

@test "each allowlist path exists on disk" {
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == "#"* ]] && continue
    [[ -f "$line" ]] || { echo "MISSING: $line"; false; }
  done < "$ALLOWLIST"
}

@test "each allowlist path has a symlink in contracts/" {
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == "#"* ]] && continue
    fname=$(basename "$line")
    [[ -e "$CONTRACTS_DIR/$fname" ]] || { echo "NO SYMLINK: $fname in $CONTRACTS_DIR"; false; }
  done < "$ALLOWLIST"
}

@test "all symlinks in contracts/ resolve to existing files" {
  for link in "$CONTRACTS_DIR"/*.bats; do
    [[ -e "$link" ]] || { echo "BROKEN SYMLINK: $link"; false; }
  done
}

# --- Tests sellados pasan ---

@test "sealed test: block-force-push passes" {
  bats "$CONTRACTS_DIR/test-block-force-push.bats" >/dev/null 2>&1
}

@test "sealed test: confidentiality-sign passes" {
  bats "$CONTRACTS_DIR/test-confidentiality-sign.bats" >/dev/null 2>&1
}

@test "sealed test: hook-pii-gate passes" {
  bats "$CONTRACTS_DIR/test-hook-pii-gate.bats" >/dev/null 2>&1
}

@test "sealed test: permissions-wildcard-audit passes" {
  ( cd "$CLAUDE_PROJECT_DIR" && bats "tests/test-permissions-wildcard-audit.bats" ) >/dev/null 2>&1
}

@test "sealed test: validate-agent-permissions passes" {
  ( cd "$CLAUDE_PROJECT_DIR" && bats "tests/test-validate-agent-permissions.bats" ) >/dev/null 2>&1
}

# --- Guard hook funciona sobre contracts/ ---

@test "guard blocks edit to allowlisted path from agent branch" {
  local path
  path=$(grep -v '^#' "$ALLOWLIST" | grep -v '^$' | head -1)
  export _SAVIA_INTERNAL_TEST_BRANCH="agent/test-branch"
  export SAVIA_TEST_MODE=1
  run bash -c "printf '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"%s\"}}' '$path' | bash '$HOOK'"
  unset _SAVIA_INTERNAL_TEST_BRANCH SAVIA_TEST_MODE
  [[ "$status" -eq 2 ]]
}

@test "guard allows edit from main branch" {
  local path
  path=$(grep -v '^#' "$ALLOWLIST" | grep -v '^$' | head -1)
  export _SAVIA_INTERNAL_TEST_BRANCH="main"
  export SAVIA_TEST_MODE=1
  run bash -c "printf '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"%s\"}}' '$path' | bash '$HOOK'"
  unset _SAVIA_INTERNAL_TEST_BRANCH SAVIA_TEST_MODE
  [[ "$status" -eq 0 ]]
}

@test "guard allows non-contract path from agent branch" {
  export _SAVIA_INTERNAL_TEST_BRANCH="agent/test-branch"
  export SAVIA_TEST_MODE=1
  run bash -c "printf '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"docs/README.md\"}}' | bash '$HOOK'"
  unset _SAVIA_INTERNAL_TEST_BRANCH SAVIA_TEST_MODE
  [[ "$status" -eq 0 ]]
}

# --- Doc quality ---

@test "sealed-contract-tests.md mentions allowlist" {
  grep -q "allowlist" docs/rules/domain/sealed-contract-tests.md
}

@test "sealed-contract-tests.md mentions contract-test-guard" {
  grep -q "contract-test-guard" docs/rules/domain/sealed-contract-tests.md
}

@test "sealed-contract-tests.md mentions bypass keyword" {
  grep -q "contract-change\|contract-add\|contract-remove" docs/rules/domain/sealed-contract-tests.md
}
