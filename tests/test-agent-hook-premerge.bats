#!/usr/bin/env bats
# BATS tests for .opencode/hooks/agent-hook-premerge.sh
# Pre-merge security + quality gate. Deterministic, no LLM.
# Hook detects bare TODO(AB#0) markers without ticket refs.
# Ref: batch 42 hook coverage

HOOK=".opencode/hooks/agent-hook-premerge.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export TEST_REPO="$TMPDIR/repo-$$"
  mkdir -p "$TEST_REPO"
  (cd "$TEST_REPO" && git init -q && git config user.email t@t && git config user.name t && git config commit.gpgsign false)
  export AGENT_HOOKS_MODE=warning
  export AGENT_HOOKS_ENABLED=true
  export HOOK_ABS="$(pwd)/$HOOK"
}
teardown() {
  rm -rf "$TEST_REPO" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Skip paths ───────────────────────────────────────────

@test "skip: AGENT_HOOKS_ENABLED=false disables hook" {
  export AGENT_HOOKS_ENABLED=false
  export CLAUDE_TOOL_INPUT='git merge feature-x'
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "skip: non-merge command ignored" {
  export CLAUDE_TOOL_INPUT='ls -la'
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "skip: git status ignored (not a merge)" {
  export CLAUDE_TOOL_INPUT='git status'
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "skip: no staged files exits 0" {
  cd "$TEST_REPO"
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}

# ── Check 1: secrets detection ───────────────────────────

@test "detect: AWS key pattern in staged file flagged" {
  cd "$TEST_REPO"
  local prefix="AKIA" body="XXXXXXXXXXXXXXXX"
  printf "key: %s%s\n" "$prefix" "$body" > secret.txt
  git add secret.txt
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"secret"* ]]
}

@test "detect: github PAT pattern flagged" {
  cd "$TEST_REPO"
  local prefix="ghp" sep="_" body="abcdefghijklmnopqrstuvwxyz0123456789"
  printf "token=%s%s%s\n" "$prefix" "$sep" "$body" > secret.txt
  git add secret.txt
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"secret"* ]]
}

@test "detect: private key header flagged" {
  cd "$TEST_REPO"
  printf -- "-----BEGIN RSA PRIVATE KEY-----\nMIIE\n" > key.pem
  git add key.pem
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"secret"* ]]
}

# ── Check 2: bare shortcut marker detection (AB#0 exempt block) ──

@test "detect: bare shortcut marker without ticket flagged" {
  cd "$TEST_REPO"
  # Construct marker dynamically (avoid tripping S-06 on the test file itself)
  local p1="TO" p2="DO"
  printf "def foo():\n    # %s%s: fix this later\n    pass\n" "$p1" "$p2" > code.py
  git add code.py
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"marker"* ]] || [[ "$output" == *"ticket"* ]] || [[ "$output" == *"Agent Hook"* ]]
}

@test "pass: marker with AB#1234 ticket reference (AB#0 exempt) not flagged" {
  cd "$TEST_REPO"
  local p1="TO" p2="DO"
  printf "# %s%s(AB#1234): refactor\n" "$p1" "$p2" > code.py
  git add code.py
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  # Should not flag since ticket ref present
  [[ "$output" != *"without ticket"* ]]
}

# ── Check 3: merge conflict markers ──────────────────────

@test "detect: merge conflict markers <<<<<<< flagged" {
  cd "$TEST_REPO"
  printf '<<<<<<< HEAD\nline a\n=======\nline b\n>>>>>>> feature\n' > conflict.txt
  git add conflict.txt
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"conflict markers"* ]]
}

@test "pass: normal text without conflict markers" {
  cd "$TEST_REPO"
  echo "clean content" > clean.txt
  git add clean.txt
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" != *"conflict markers"* ]]
}

# ── Check 4: 150-line file size limit ───────────────────

@test "detect: .opencode/agents/ file > 150 lines flagged" {
  cd "$TEST_REPO"
  mkdir -p .claude/agents .opencode/agents
  for i in $(seq 1 160); do echo "line $i"; done > .opencode/agents/big.md
  git add .opencode/agents/big.md
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"exceeds 150"* ]]
}

@test "pass: file at 150 lines not flagged" {
  cd "$TEST_REPO"
  mkdir -p .claude/agents .opencode/agents
  for i in $(seq 1 150); do echo "line $i"; done > .opencode/agents/border.md
  git add .opencode/agents/border.md
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" != *"exceeds 150"* ]]
}

@test "pass: non-scope file (src/*.py) not subject to 150 limit" {
  cd "$TEST_REPO"
  mkdir -p src
  for i in $(seq 1 200); do echo "line $i"; done > src/code.py
  git add src/code.py
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" != *"exceeds 150"* ]]
}

# ── Mode handling ───────────────────────────────────────

@test "mode: warning mode exits 0 with issues" {
  cd "$TEST_REPO"
  printf '<<<<<<< HEAD\nx\n' > f.txt
  git add f.txt
  export AGENT_HOOKS_MODE=warning
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}

@test "mode: soft-block exits 2" {
  cd "$TEST_REPO"
  printf '<<<<<<< HEAD\nx\n' > f.txt
  git add f.txt
  export AGENT_HOOKS_MODE=soft-block
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 2 ]
  [[ "$output" == *"soft-block"* ]]
}

@test "mode: hard-block exits 2 with blocked message" {
  cd "$TEST_REPO"
  printf '<<<<<<< HEAD\nx\n' > f.txt
  git add f.txt
  export AGENT_HOOKS_MODE=hard-block
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 2 ]
  [[ "$output" == *"blocked"* ]]
}

# ── gh pr merge command support ─────────────────────────

@test "trigger: gh pr merge also runs hook" {
  cd "$TEST_REPO"
  printf '<<<<<<< HEAD\nx\n' > f.txt
  git add f.txt
  export CLAUDE_TOOL_INPUT='gh pr merge 123 --squash'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"conflict markers"* ]]
}

# ── Negative cases ──────────────────────────────────────

@test "negative: no CLAUDE_TOOL_INPUT env exits 0" {
  unset CLAUDE_TOOL_INPUT
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "negative: outside git repo exits 0" {
  cd "$TMPDIR"
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: empty file staged does not trigger false positive" {
  cd "$TEST_REPO"
  : > empty.txt
  git add empty.txt
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}

@test "edge: clean commit triggers no issues" {
  cd "$TEST_REPO"
  echo "clean file" > ok.txt
  git add ok.txt
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
  [[ "$output" != *"Agent Hook"* ]]
}

@test "edge: 150-limit applies to .opencode/skills/" {
  cd "$TEST_REPO"
  mkdir -p .opencode/skills/foo
  for i in $(seq 1 200); do echo "l $i"; done > .opencode/skills/foo/SKILL.md
  git add .opencode/skills/foo/SKILL.md
  export CLAUDE_TOOL_INPUT='git merge main'
  run bash "$HOOK_ABS"
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *"exceeds"* ]]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: 4 check categories present" {
  for check in 'secrets' 'conflict' '150 lines'; do
    grep -qi "$check" "$HOOK" || fail "missing check: $check"
  done
  # shortcut marker pattern check
  grep -q 'FIXME' "$HOOK"
}

@test "coverage: 3 modes (warning, soft-block, hard-block)" {
  for mode in warning soft-block hard-block; do
    grep -q "\"$mode\"" "$HOOK" || fail "missing mode: $mode"
  done
}

@test "coverage: deterministic (no LLM invocation)" {
  run grep -c 'Does NOT invoke LLM' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ────────────────────────────────────────────

@test "isolation: hook does not modify repo state" {
  cd "$TEST_REPO"
  echo "ok" > f.txt
  git add f.txt
  local before
  before=$(git status --porcelain)
  export CLAUDE_TOOL_INPUT='git merge main'
  bash "$HOOK_ABS" >/dev/null 2>&1 || true
  local after
  after=$(git status --porcelain)
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$before" == "$after" ]]
}

@test "isolation: exit codes bounded to {0, 2}" {
  run bash "$HOOK"
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}
