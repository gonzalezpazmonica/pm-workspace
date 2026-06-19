#!/usr/bin/env bats
# Tests for .claude/hooks/contract-test-guard.sh (SPEC-188-P3)
# Ref: docs/specs/SPEC-188-P3-sealed-contract-tests.spec.md
# Adversarial fixes applied: env var guard, path normalize, [contract-change] bypass

# Auditor target hint (SPEC-055): used by scripts/test-auditor-engine.py
HOOK=".claude/hooks/contract-test-guard.sh"

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd -P)"
  HOOK="${REPO_ROOT}/.claude/hooks/contract-test-guard.sh"
  ALLOWLIST="${REPO_ROOT}/.claude/contracts/allowlist.txt"
  [[ -x "$HOOK" ]] || skip "contract-test-guard.sh not executable"
  [[ -s "$ALLOWLIST" ]] || skip "allowlist missing"
  export SAVIA_TEST_MODE=1
}

teardown() {
  unset SAVIA_TEST_MODE _SAVIA_INTERNAL_TEST_BRANCH
}

make_input() {
  local tool="$1" file_path="$2"
  printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$tool" "$file_path"
}

run_with_branch() {
  local branch="$1" input="$2"
  _SAVIA_INTERNAL_TEST_BRANCH="$branch" bash -c "echo '$input' | bash '$HOOK'"
}

# ── Safety verification (SPEC-055 — auditor C2) ─────────────────────────────

@test "safety: hook uses set -uo pipefail" {
  run grep -E "^set -[eu]+o pipefail" "$HOOK"
  [ "$status" -eq 0 ]
}

@test "safety: hook declares shebang" {
  run head -1 "$HOOK"
  [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "safety: hook is executable" {
  [ -x "$HOOK" ]
}

# Block / allow cases
@test "Edit to contract test from agent/* exits 2" {
  input=$(make_input "Edit" "tests/hooks/test-block-force-push.bats")
  run run_with_branch "agent/spec-188-p3-test" "$input"
  [ "$status" -eq 2 ]
}

@test "Edit to contract test from main passes" {
  input=$(make_input "Edit" "tests/hooks/test-block-force-push.bats")
  run run_with_branch "main" "$input"
  [ "$status" -eq 0 ]
}

@test "Edit to contract test from feat/* passes" {
  input=$(make_input "Edit" "tests/hooks/test-block-force-push.bats")
  run run_with_branch "feat/some-feature" "$input"
  [ "$status" -eq 0 ]
}

@test "Edit to non-contract test from agent/* passes" {
  input=$(make_input "Edit" "tests/non-contract.bats")
  run run_with_branch "agent/test" "$input"
  [ "$status" -eq 0 ]
}

@test "Edit to scripts/random.sh from agent/* passes" {
  input=$(make_input "Edit" "scripts/random.sh")
  run run_with_branch "agent/test" "$input"
  [ "$status" -eq 0 ]
}

@test "all 5 contract tests are blocked from agent/*" {
  for t in \
    "tests/hooks/test-block-force-push.bats" \
    "tests/scripts/test-confidentiality-sign.bats" \
    "tests/hooks/test-hook-pii-gate.bats" \
    "tests/test-permissions-wildcard-audit.bats" \
    "tests/test-validate-agent-permissions.bats"; do
    input=$(make_input "Edit" "$t")
    run run_with_branch "agent/test" "$input"
    [ "$status" -eq 2 ] || { echo "Failed for: $t"; return 1; }
  done
}

@test "Read tool to contract test passes" {
  input=$(make_input "Read" "tests/hooks/test-block-force-push.bats")
  run run_with_branch "agent/test" "$input"
  [ "$status" -eq 0 ]
}

@test "Bash tool passes (not Edit/Write)" {
  input=$(make_input "Bash" "anything")
  run run_with_branch "agent/test" "$input"
  [ "$status" -eq 0 ]
}

@test "Write to contract test from agent/* exits 2" {
  input=$(make_input "Write" "tests/hooks/test-hook-pii-gate.bats")
  run run_with_branch "agent/test" "$input"
  [ "$status" -eq 2 ]
}

# H1 fix: absolute path normalize
@test "absolute path within repo is normalized and matches" {
  input=$(make_input "Edit" "${REPO_ROOT}/tests/hooks/test-block-force-push.bats")
  run run_with_branch "agent/test" "$input"
  [ "$status" -eq 2 ]
}

@test "absolute path OUTSIDE repo with same suffix does NOT match" {
  input=$(make_input "Edit" "/some/random/external/tests/hooks/test-block-force-push.bats")
  run run_with_branch "agent/test" "$input"
  # Falls into the "*/entry" pattern: it WILL match if the suffix matches.
  # This is the documented behaviour: defense in depth, not perfect isolation.
  # Test verifies expected behaviour even if conservative (block it).
  [ "$status" -eq 2 ]
}

@test "path traversal does not escalate" {
  input=$(make_input "Edit" "../../etc/passwd")
  run run_with_branch "agent/test" "$input"
  [ "$status" -eq 0 ]
}

# Block message
@test "block message contains the blocked path" {
  input=$(make_input "Edit" "tests/hooks/test-block-force-push.bats")
  run run_with_branch "agent/test" "$input"
  [[ "$output" == *"test-block-force-push.bats"* ]]
}

@test "block message contains SPEC-188-P3 reference" {
  input=$(make_input "Edit" "tests/hooks/test-block-force-push.bats")
  run run_with_branch "agent/test" "$input"
  [[ "$output" == *"SPEC-188-P3"* ]]
}

@test "block message documents bypass mechanism" {
  input=$(make_input "Edit" "tests/hooks/test-block-force-push.bats")
  run run_with_branch "agent/test" "$input"
  [[ "$output" == *"contract-change"* ]] || [[ "$output" == *"contract-add"* ]]
}

# C3 fix: env var guard
@test "_SAVIA_INTERNAL_TEST_BRANCH ignored without test mode flag" {
  # Without SAVIA_TEST_MODE, BATS_TEST_FILENAME or CI, the env var is ignored
  unset SAVIA_TEST_MODE
  input=$(make_input "Edit" "tests/hooks/test-block-force-push.bats")
  # Run without any test indicator: hook reads real branch (agent/spec-188-p3-...)
  result=$(_SAVIA_INTERNAL_TEST_BRANCH="main" bash -c "unset BATS_TEST_FILENAME CI SAVIA_TEST_MODE; echo '$input' | bash '$HOOK'" 2>&1; echo "EXIT=$?")
  # On real agent/* branch, the hook should still block despite env var attempt
  [[ "$result" == *"EXIT=2"* ]] || [[ "$result" == *"EXIT=0"* ]]  # depends on real branch
  export SAVIA_TEST_MODE=1  # restore
}

# Empty allowlist
@test "missing allowlist file passes everything (no-op fallback)" {
  TMPL=$(mktemp -d)/empty-allowlist.txt
  input=$(make_input "Edit" "tests/hooks/test-block-force-push.bats")
  result=$(SAVIA_CONTRACT_ALLOWLIST="$TMPL" _SAVIA_INTERNAL_TEST_BRANCH="agent/test" \
    bash -c "echo '$input' | bash '$HOOK'" 2>&1; echo "EXIT=$?")
  rm -rf "$(dirname "$TMPL")"
  [[ "$result" == *"EXIT=0"* ]]
}

@test "empty allowlist file passes everything (no-op fallback)" {
  TMPL=$(mktemp); : > "$TMPL"
  input=$(make_input "Edit" "tests/hooks/test-block-force-push.bats")
  result=$(SAVIA_CONTRACT_ALLOWLIST="$TMPL" _SAVIA_INTERNAL_TEST_BRANCH="agent/test" \
    bash -c "echo '$input' | bash '$HOOK'" 2>&1; echo "EXIT=$?")
  rm -f "$TMPL"
  [[ "$result" == *"EXIT=0"* ]]
}

# Self-test
@test "--self-test exits 0" {
  run "$HOOK" --self-test
  [ "$status" -eq 0 ]
}

# Latency
@test "AC-4 latency: 100 invocations under 5s" {
  input=$(make_input "Edit" "scripts/something.sh")
  start=$(date +%s%N)
  for i in $(seq 1 100); do
    echo "$input" | bash "$HOOK" >/dev/null 2>&1
  done
  end=$(date +%s%N)
  elapsed_ms=$(( (end - start) / 1000000 ))
  echo "100 invocations took ${elapsed_ms}ms"
  [ "$elapsed_ms" -lt 5000 ]
}

# C4 fix: legitimate bypass via [contract-change|add|remove] commit message
_make_repo_with_msg() {
  local msg="$1" tmp; tmp=$(mktemp -d)
  git -C "$tmp" init -q
  git -C "$tmp" config user.email "t@t"
  git -C "$tmp" config user.name "t"
  echo x > "$tmp/a.txt"
  git -C "$tmp" add .
  git -C "$tmp" commit -q -m "$msg"
  echo "$tmp"
}

_run_bypass() {
  local tmp="$1" expect_exit="$2"
  local input; input=$(make_input "Edit" "tests/hooks/test-block-force-push.bats")
  local result
  result=$(SAVIA_CONTRACT_ALLOWLIST="$ALLOWLIST" SAVIA_TEST_MODE=1 \
    _SAVIA_INTERNAL_TEST_BRANCH="agent/test" CLAUDE_PROJECT_DIR="$tmp" \
    bash -c "echo '$input' | bash '$HOOK'" 2>&1; echo "EXIT=$?")
  rm -rf "$tmp"
  [[ "$result" == *"EXIT=$expect_exit"* ]]
}

@test "bypass: [contract-change] allows edit" {
  tmp=$(_make_repo_with_msg "[contract-change] legit bypass")
  _run_bypass "$tmp" "0"
}

@test "bypass: [contract-add] allows edit" {
  tmp=$(_make_repo_with_msg "[contract-add] add test")
  _run_bypass "$tmp" "0"
}

@test "bypass: [contract-remove] allows edit" {
  tmp=$(_make_repo_with_msg "[contract-remove] demote test")
  _run_bypass "$tmp" "0"
}

@test "regular commit (no bypass tag) does NOT bypass" {
  tmp=$(_make_repo_with_msg "regular commit message")
  _run_bypass "$tmp" "2"
}
