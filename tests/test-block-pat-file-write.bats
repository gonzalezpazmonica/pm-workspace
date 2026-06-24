#!/usr/bin/env bats
# BATS tests for block-pat-file-write.sh
# SPEC: SPEC-SE-036 Slice 3 (AC-06) — block PAT path writes outside gitignore

SCRIPT=".opencode/hooks/block-pat-file-write.sh"

setup() {
  export CLAUDE_PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  export SAVIA_HOOK_PROFILE="standard"
}

teardown() {
  unset SAVIA_HOOK_PROFILE
}

# --- existence and basics ---

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script has set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "script references SPEC-SE-036" {
  grep -q "SPEC-SE-036" "$SCRIPT"
}

# --- positive: non-PAT paths pass through ---

@test "positive: write to README.md is allowed" {
  echo '{"tool_input":{"file_path":"README.md"}}' | bash "$SCRIPT"
}

@test "positive: write to scripts/api-key-create.sh is allowed" {
  echo '{"tool_input":{"file_path":"scripts/enterprise/api-key-create.sh"}}' | bash "$SCRIPT"
}

@test "positive: write to docs/rules/domain/foo.md is allowed" {
  echo '{"tool_input":{"file_path":"docs/rules/domain/foo.md"}}' | bash "$SCRIPT"
}

@test "positive: empty input exits 0" {
  echo '{}' | bash "$SCRIPT"
}

@test "positive: missing file_path field exits 0" {
  echo '{"tool_input":{}}' | bash "$SCRIPT"
}

# --- negative: PAT paths outside gitignore are blocked ---

@test "negative: blocks write to devops-pat in non-gitignored path" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"scripts/devops-pat\"}}" | bash '"$SCRIPT"
  # script uses git check-ignore; scripts/ is not gitignored → should block
  [[ "$status" -eq 2 ]]
}

@test "negative: blocks write to my-pat-file.txt" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"my-pat-file.txt\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "negative: blocks write to .env.pat (case insensitive)" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\".env.PAT\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "negative: blocked message references SPEC-SE-036" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"scripts/devops-pat\"}}" | bash '"$SCRIPT"
  [[ "$output" =~ "SPEC-SE-036" ]] || [[ "$stderr" =~ "SPEC-SE-036" ]]
}

# --- edge: gitignored PAT paths are allowed ---

@test "edge: write to .gitignored PAT path is allowed" {
  # ~/.savia/ is outside repo = not tracked, but we simulate with a temp path
  # In a real run: if git check-ignore returns 0, the hook exits 0
  # We test a path that IS in .gitignore of the repo
  local gitignored_pat_path
  gitignored_pat_path=$(grep -m1 "pat" "$CLAUDE_PROJECT_DIR/.gitignore" 2>/dev/null | head -1 || echo "")
  if [[ -z "$gitignored_pat_path" ]]; then
    skip "No PAT gitignore entry found — skipping gitignored positive test"
  fi
  echo "{\"tool_input\":{\"file_path\":\"$gitignored_pat_path\"}}" | bash "$SCRIPT"
}

@test "edge: filePath camelCase is also handled" {
  run bash -c 'echo "{\"tool_input\":{\"filePath\":\"scripts/devops-pat\"}}" | bash '"$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "coverage: uses git check-ignore" {
  grep -q "git.*check-ignore" "$SCRIPT"
}
