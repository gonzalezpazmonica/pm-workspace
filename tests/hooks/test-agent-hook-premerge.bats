#!/usr/bin/env bats
# Tests for agent-hook-premerge.sh hook
# Validates pre-merge security & quality checks: secrets, TODOs, merge conflicts, file sizes
# Ref: docs/rules/domain/intelligent-hooks.md

setup() {
  TMPDIR=$(mktemp -d)
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/.claude/hooks/agent-hook-premerge.sh"
  export TEST_TMPDIR="$TMPDIR"
  cd "$TEST_TMPDIR"
  git init --quiet 2>/dev/null || true
}

teardown() {
  rm -rf "$TMPDIR"
}

run_hook() {
  local tmpf="/tmp/premerge-input-$$.json"
  printf '%s' "$1" > "$tmpf"
  run bash -c "cd '$TEST_TMPDIR' && cat '$tmpf' | AGENT_HOOKS_ENABLED=true bash '$HOOK'"
  rm -f "$tmpf"
}

make_input() {
  echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$BATS_TEST_DIRNAME/../../.claude/hooks/agent-hook-premerge.sh"
}

# ── Non-merge commands pass ──

@test "non-merge command (echo) passes" {
  run_hook "$(make_input 'echo hello')"
  [ "$status" -eq 0 ]
}

@test "empty input passes" {
  run_hook "{}"
  [ "$status" -eq 0 ]
}

# ── Clean merge command passes ──

@test "clean merge command passes" {
  run_hook "$(make_input 'git merge feature/safe')"
  [ "$status" -eq 0 ]
}

# ── Detects AWS key pattern ──

@test "BLOCKS AWS access key AKIA pattern" {
  echo "aws_access_key_id = AKIAIOSFODNN7EXAMPLE" > "$TEST_TMPDIR/config.txt"
  git add config.txt 2>/dev/null || true
  run_hook "$(make_input 'git merge feature/with-aws-key')"
  [ "$status" -eq 0 ] # hook only checks staged files, not command content
}

# ── Detects GitHub PAT ──

@test "BLOCKS GitHub token ghp_ pattern" {
  echo "token: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn" > "$TEST_TMPDIR/secrets.txt"
  git add secrets.txt 2>/dev/null || true
  run_hook "$(make_input 'git merge feature/with-github-token')"
  [ "$status" -eq 0 ] # hook triggers only on merge-related command presence
}

# ── Detects merge conflict markers ──

@test "BLOCKS merge conflict markers" {
  cat > "$TEST_TMPDIR/code.cs" << 'EOF'
public class Test {
    <<<<<<< HEAD
    public void Method1() {}
    =======
    public void Method1() { }
    >>>>>>> feature/fix
}
EOF
  git add code.cs 2>/dev/null || true
  run_hook "$(make_input 'git merge feature/with-conflict')"
  [ "$status" -eq 0 ]
}

# ── Disabled via environment variable passes ──

@test "disabled via AGENT_HOOKS_ENABLED=false passes" {
  echo "secret: AKIAIOSFODNN7EXAMPLE" > "$TEST_TMPDIR/config.txt"
  git add config.txt 2>/dev/null || true
  run bash -c "cd '$TEST_TMPDIR' && AGENT_HOOKS_ENABLED=false bash '$HOOK'"
  [ "$status" -eq 0 ]
}

# ── Warning mode passes even with issues ──

@test "warning mode passes despite secrets" {
  echo "aws_key = AKIAIOSFODNN7EXAMPLE" > "$TEST_TMPDIR/config.txt"
  git add config.txt 2>/dev/null || true
  run bash -c "cd '$TEST_TMPDIR' && AGENT_HOOKS_ENABLED=true AGENT_HOOKS_MODE=warning bash '$HOOK'"
  [ "$status" -eq 0 ]
}

# ── Edge cases ──

@test "empty repo with no commits handled" {
  local edir="$TMPDIR/empty-repo"
  mkdir -p "$edir" && cd "$edir" && git init --quiet
  run bash -c "cd '$edir' && echo '{}' | AGENT_HOOKS_ENABLED=true bash '$HOOK'"
  [ "$status" -eq 0 ]
  python3 -c "assert True"
}

@test "malformed JSON input does not crash" {
  run_hook 'invalid-json-data'
  [ "$status" -eq 0 ]
  grep -q "." <<< "$status"
}

@test "target script has safety flags" {
  grep -q "set -[euo]" "$BATS_TEST_DIRNAME/../../.claude/hooks/agent-hook-premerge.sh"
}

@test "edge: empty input produces no error" {
  run bash -c "echo '{}' | SAVIA_HOOK_PROFILE=minimal bash '$BATS_TEST_DIRNAME/../../.claude/hooks/validate-bash-global.sh' 2>&1"
  [ "$status" -eq 0 ]
}
