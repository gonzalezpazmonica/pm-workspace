#!/usr/bin/env bash
# contract-test-guard.sh — SPEC-188-P3 Sealed Contract Tests enforcement
# Blocks Edit/Write to allowlisted paths from agent/* branches.
# See: docs/specs/SPEC-188-P3-sealed-contract-tests.spec.md
set -uo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ALLOWLIST="${SAVIA_CONTRACT_ALLOWLIST:-${REPO_ROOT}/.claude/contracts/allowlist.txt}"

current_branch() {
  if [[ -n "${_SAVIA_INTERNAL_TEST_BRANCH:-}" && -n "${BATS_TEST_FILENAME:-}${CI:-}${SAVIA_TEST_MODE:-}" ]]; then
    echo "$_SAVIA_INTERNAL_TEST_BRANCH"; return
  fi
  git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

self_test() {
  local self="${BASH_SOURCE[0]}" errs=0
  export SAVIA_TEST_MODE=1
  for case in "agent/x|tests/hooks/test-block-force-push.bats|2" \
              "main|tests/hooks/test-block-force-push.bats|0" \
              "agent/x|scripts/random.sh|0"; do
    IFS='|' read -r br fp expect <<< "$case"
    export _SAVIA_INTERNAL_TEST_BRANCH="$br"
    actual=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$fp" \
             | bash "$self" >/dev/null 2>&1; echo $?)
    [[ "$actual" == "$expect" ]] || { echo "FAIL: $br $fp expect=$expect got=$actual" >&2; errs=$((errs+1)); }
  done
  unset _SAVIA_INTERNAL_TEST_BRANCH SAVIA_TEST_MODE
  (( errs == 0 )) && { echo "self-test OK"; return 0; } || { echo "self-test FAILED: $errs" >&2; return 1; }
}

main() {
  [[ "${1:-}" == "--self-test" ]] && { self_test; return $?; }
  command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required for contract-test-guard" >&2; return 1; }
  [[ -s "$ALLOWLIST" ]] || return 0
  local input tool target branch
  input=$(cat 2>/dev/null) || return 0
  [[ -z "$input" ]] && return 0
  tool=$(jq -r '.tool_name // ""' <<< "$input" 2>/dev/null)
  [[ "$tool" == "Edit" || "$tool" == "Write" ]] || return 0
  branch=$(current_branch)
  [[ "$branch" =~ ^agent/ ]] || return 0
  target=$(jq -r '.tool_input.file_path // ""' <<< "$input" 2>/dev/null)
  [[ -z "$target" ]] && return 0
  # Normalize: strip REPO_ROOT prefix if path is absolute and within repo
  [[ "$target" == "$REPO_ROOT"/* ]] && target="${target#$REPO_ROOT/}"
  # Bypass: commit message contains [contract-change|add|remove]
  local msg
  msg=$(git -C "$REPO_ROOT" log -1 --pretty=%B 2>/dev/null)
  if [[ "$msg" =~ \[contract-(change|add|remove)\] ]]; then
    return 0  # legitimate signed bypass
  fi
  while IFS= read -r entry; do
    [[ -z "$entry" || "$entry" == "#"* ]] && continue
    if [[ "$target" == "$entry" || "$target" == */"$entry" ]]; then
      cat >&2 <<EOF
BLOCKED [contract-test-guard]: $target is a SEALED contract test (SPEC-188-P3).
Agents on agent/* branches cannot modify sealed contract tests.
Bypass: commit with [contract-change], [contract-add], or [contract-remove] prefix
and human review obligatory. See docs/specs/SPEC-188-P3-precommitment.md
EOF
      return 2
    fi
  done < "$ALLOWLIST"
  return 0
}

main "$@"
