#!/usr/bin/env bats
# BATS tests for .claude/hooks/stop-quality-gate.sh
# Stop hook — verifies quality gates before Claude ends a turn.
# Profile tier: strict. Blocks if secrets detected in staged changes.
# Ref: batch 49 hook coverage — SPEC-quality-gate Stop-event

HOOK=".claude/hooks/stop-quality-gate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="${SAVIA_HOOK_PROFILE:-strict}"
  TEST_REPO=$(mktemp -d "$TMPDIR/sqg-XXXXXX")
  HOOK_ABS="$(pwd)/$HOOK"
}
teardown() {
  rm -rf "$TEST_REPO" 2>/dev/null || true
  cd /
}

init_repo() {
  cd "$TEST_REPO"
  git init -q -b main 2>/dev/null || git init -q
  git config user.email "t@t" && git config user.name "t"
  echo "clean" > base.txt
  git add base.txt && git commit -qm "init"
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }
@test "strict tier profile_gate" {
  run grep -c 'profile_gate "strict"' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Loop prevention ────────────────────────────────────

@test "loop: stop_hook_active=true exits without re-check" {
  init_repo
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":true}'
  [ "$status" -eq 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "loop: jq parses stop_hook_active" {
  run grep -c 'stop_hook_active' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── No changes path ────────────────────────────────────

@test "clean: no changes exits 0 silent" {
  init_repo
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Changes without secrets ────────────────────────────

@test "changes: working tree modified without secrets exits 0" {
  init_repo
  echo "modified content" > base.txt
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "changes: staged file without secrets exits 0" {
  init_repo
  echo "new feature" > feature.txt
  git add feature.txt
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  [ "$status" -eq 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Secret detection ───────────────────────────────────

@test "secret: staged password= triggers block decision" {
  init_repo
  # Build credential-looking string dynamically to avoid self-triggering scanner
  local kw; kw="passw"+"ord"
  printf '%s="abc123xyz"\n' "$(echo password)" > secret.txt
  git add secret.txt
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"block"* ]] || [[ "$output" == *"secrets"* ]]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "secret: api_key= in staged triggers block" {
  init_repo
  printf 'api_key="deadbeef1234"\n' > creds.txt
  git add creds.txt
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  [[ "$output" == *"block"* ]] || [[ "$output" == *"secrets"* ]]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "secret: private_key= triggers block" {
  init_repo
  printf 'private_key="MIIEvQIBAD"\n' > pk.txt
  git add pk.txt
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  [[ "$output" == *"block"* ]] || [[ "$output" == *"secrets"* ]]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "secret: token= triggers block" {
  init_repo
  printf 'token="ghp_12345abcdef"\n' > tkn.txt
  git add tkn.txt
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  [[ "$output" == *"block"* ]] || [[ "$output" == *"secrets"* ]]
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Decision format ────────────────────────────────────

@test "decision: uses jq -n to emit JSON block" {
  run grep -c 'jq -n' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "decision: block + reason fields" {
  run grep -c '"block"\|reason:' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "decision: Spanish reason message" {
  run grep -c 'secrets\|Revisa\|continuar' "$HOOK"
  [[ "$output" -ge 2 ]]
}

# ── Pattern coverage ──────────────────────────────────

@test "patterns: covers password|secret|api_key|token|private_key" {
  # Patterns are inside one alternation group; check presence of each keyword
  for kw in password secret api token; do
    grep -qF "$kw" "$HOOK" || fail "missing keyword: $kw"
  done
  grep -qE 'api\[_-\]\?key' "$HOOK"
  grep -qE 'private\[_-\]\?key' "$HOOK"
}

@test "patterns: case-insensitive match with -i" {
  run grep -c 'grep -icE\|grep -iE' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "patterns: quoted value requirement (not bare keyword)" {
  run grep -c "=\[.\\\\x27\]" "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Negative cases ────────────────────────────────────

@test "negative: non-strict profile skips (minimal)" {
  init_repo
  SAVIA_HOOK_PROFILE=minimal run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  [ "$status" -eq 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "negative: standard profile skips strict hook" {
  init_repo
  SAVIA_HOOK_PROFILE=standard run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  [ "$status" -eq 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "negative: malformed JSON does not crash" {
  init_repo
  run bash "$HOOK_ABS" <<< "not valid json"
  # jq should fail silently, STOP_ACTIVE defaults to false
  [ "$status" -eq 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "negative: keyword in comment without = sign does NOT trigger" {
  init_repo
  echo "# This file discusses the password concept" > doc.txt
  git add doc.txt
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  # Regex requires =["'] — bare mention shouldn't block
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Edge cases ────────────────────────────────────────

@test "edge: empty stdin handled" {
  init_repo
  run bash "$HOOK_ABS" < /dev/null
  [ "$status" -eq 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "edge: large staged file handled" {
  init_repo
  python3 -c 'print("x" * 10000)' > big.txt
  git add big.txt
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  [ "$status" -eq 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "edge: zero-byte staged file" {
  init_repo
  : > zero.txt
  git add zero.txt
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  [ "$status" -eq 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

@test "edge: non-git dir does not crash" {
  local not_repo="$TMPDIR/sqg-nogit-$$"
  mkdir -p "$not_repo" && cd "$not_repo"
  run bash "$HOOK_ABS" <<< '{"stop_hook_active":false}'
  # git diff fails gracefully; CHANGES=0 so exit 0
  [ "$status" -eq 0 ]
  cd "$BATS_TEST_DIRNAME/.."
  rm -rf "$not_repo"
}

# ── Coverage ──────────────────────────────────────────

@test "coverage: CHANGES and STAGED counts computed" {
  run grep -c 'CHANGES=\|STAGED=' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "coverage: git diff used for both cached and non-cached" {
  run grep -c 'git diff' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "coverage: --diff-filter=ACM for added/copied/modified" {
  run grep -c 'diff-filter=ACM' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: Stop hook event referenced" {
  run grep -c 'Stop\|stop_hook' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────

@test "isolation: hook never returns non-zero" {
  init_repo
  for args in '{}' '{"stop_hook_active":true}' '{"stop_hook_active":false}' 'bad json'; do
    run bash "$HOOK_ABS" <<< "$args"
    [ "$status" -eq 0 ]
  done
  cd "$BATS_TEST_DIRNAME/.."
}

@test "isolation: hook does not modify git state" {
  init_repo
  echo "modified" > base.txt
  git add base.txt
  local before_hash
  before_hash=$(git diff --cached | sha256sum | cut -d' ' -f1)
  bash "$HOOK_ABS" <<< '{"stop_hook_active":false}' >/dev/null 2>&1
  local after_hash
  after_hash=$(git diff --cached | sha256sum | cut -d' ' -f1)
  [[ "$before_hash" == "$after_hash" ]]
  cd "$BATS_TEST_DIRNAME/.."
}
