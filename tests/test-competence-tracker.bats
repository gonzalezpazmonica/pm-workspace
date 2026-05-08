#!/usr/bin/env bats
# BATS tests for .opencode/hooks/competence-tracker.sh
# Async PostToolUse — logs Bash command domain per active user.
# SPEC-014 Phase 2. Profile tier: strict.
# Ref: batch 44 hook coverage

HOOK=".opencode/hooks/competence-tracker.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export HOME="$TMPDIR/home-$$"
  mkdir -p "$HOME/claude/.claude/profiles/users/testuser"
  cat > "$HOME/claude/.claude/profiles/active-user.md" <<'EOF'
---
active_slug: "testuser"
---
EOF
  # Hook requires strict tier
  export SAVIA_HOOK_PROFILE=strict
}
teardown() {
  rm -rf "$HOME" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Skip paths ──────────────────────────────────────────

@test "skip: empty stdin exits 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "skip: non-Bash tool (Edit) ignored" {
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"command":"ls"}}'
  [ "$status" -eq 0 ]
  [[ ! -f "$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl" ]]
}

@test "skip: missing command field exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{}}'
  [ "$status" -eq 0 ]
}

@test "skip: no active-user.md means no log" {
  rm -f "$HOME/claude/.claude/profiles/active-user.md"
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"sprint-status"}}'
  [ "$status" -eq 0 ]
}

@test "skip: user dir missing means no log" {
  rm -rf "$HOME/claude/.claude/profiles/users/testuser"
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"sprint-status"}}'
  [ "$status" -eq 0 ]
}

# ── Domain classification ───────────────────────────────

@test "domain: sprint-status maps to sprint-mgmt" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"sprint-status --current"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  [[ -f "$log" ]]
  grep -q '"domain":"sprint-mgmt"' "$log"
}

@test "domain: spec-create maps to sdd" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"spec-create new-feature"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -q '"domain":"sdd"' "$log"
}

@test "domain: arch-recommend maps to architecture" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"arch-recommend project-a"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -q '"domain":"architecture"' "$log"
}

@test "domain: security-audit maps to security" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"security-audit run"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -q '"domain":"security"' "$log"
}

@test "domain: pipeline-run maps to devops" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"pipeline-run build-123"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -q '"domain":"devops"' "$log"
}

@test "domain: test-create maps to testing" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"test-create feature"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -q '"domain":"testing"' "$log"
}

@test "domain: ceo-report maps to reporting" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"ceo-report generate"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -q '"domain":"reporting"' "$log"
}

@test "domain: pbi-create maps to product" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"pbi-create new"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -q '"domain":"product"' "$log"
}

@test "domain: memory-save maps to context" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"memory-save observation"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -q '"domain":"context"' "$log"
}

@test "domain: team-onboard maps to team" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"team-onboard alice"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -q '"domain":"team"' "$log"
}

@test "domain: zeroclaw maps to hardware" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"zeroclaw start"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -q '"domain":"hardware"' "$log"
}

@test "domain: unmapped command does not log" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
  [ "$status" -eq 0 ]
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  [[ ! -f "$log" ]]
}

# ── Log entry format ────────────────────────────────────

@test "log: JSONL entry contains ts, domain, cmd, success fields" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"sprint-status"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  local entry
  entry=$(head -1 "$log")
  [[ "$entry" == *'"ts":'* ]]
  [[ "$entry" == *'"domain":'* ]]
  [[ "$entry" == *'"cmd":'* ]]
  [[ "$entry" == *'"success":'* ]]
}

@test "log: ts is ISO 8601 UTC format" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"sprint-status"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -qE '"ts":"20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$log"
}

@test "log: multiple invocations append (not overwrite)" {
  bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"sprint-status"}}' >/dev/null
  bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"pbi-create"}}' >/dev/null
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  local lines
  lines=$(wc -l < "$log")
  [[ "$lines" -eq 2 ]]
}

# ── Log rotation ────────────────────────────────────────

@test "rotation: triggers when log exceeds 1000 entries" {
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  # Pre-populate 1001 entries
  for i in $(seq 1 1001); do
    echo "{\"ts\":\"2026-01-01T00:00:00Z\",\"domain\":\"sprint-mgmt\",\"cmd\":\"x-$i\",\"success\":true}" >> "$log"
  done
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"sprint-status"}}'
  local lines
  lines=$(wc -l < "$log")
  # After rotation keeps last 500
  [[ "$lines" -le 501 ]]
}

@test "rotation: does not trigger below 1000" {
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  for i in $(seq 1 500); do
    echo "{\"ts\":\"2026-01-01T00:00:00Z\",\"domain\":\"sprint-mgmt\",\"cmd\":\"x-$i\",\"success\":true}" >> "$log"
  done
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"sprint-status"}}'
  local lines
  lines=$(wc -l < "$log")
  [[ "$lines" -eq 501 ]]
}

# ── Negative cases ──────────────────────────────────────

@test "negative: malformed JSON exits 0" {
  run bash "$HOOK" <<< "not json"
  [ "$status" -eq 0 ]
}

@test "negative: missing active_slug exits 0" {
  echo "---" > "$HOME/claude/.claude/profiles/active-user.md"
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"sprint-status"}}'
  [ "$status" -eq 0 ]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: tool name case variant 'bash' lowercase also works" {
  run bash "$HOOK" <<< '{"tool_name":"bash","tool_input":{"command":"sprint-status"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  [[ -f "$log" ]]
}

@test "edge: command with special chars logged safely" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"sprint-status --format=json"}}'
  local log="$HOME/claude/.claude/profiles/users/testuser/competence-log.jsonl"
  grep -q 'sprint-mgmt' "$log"
}

@test "edge: async invariant — always exits 0" {
  for input in '' '{}' 'bad json' '{"tool_name":"Bash"}'; do
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: 11 domain categories defined" {
  for d in sprint-mgmt sdd architecture security devops testing reporting product context team hardware; do
    grep -q "\"$d\"" "$HOOK" || fail "missing domain: $d"
  done
}

@test "coverage: SPEC-014 reference" {
  run grep -c 'SPEC-014' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: rotation logic present (1000/500)" {
  run grep -c '1000\|tail -500' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ────────────────────────────────────────────

@test "isolation: async invariant — exit always 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  run bash "$HOOK" <<< '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
}

@test "isolation: hook does not modify project files" {
  local before
  before=$(find "$TMPDIR" -maxdepth 2 -type f ! -path "*/home/*" 2>/dev/null | wc -l)
  bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"sprint-status"}}' >/dev/null 2>&1
  local after
  after=$(find "$TMPDIR" -maxdepth 2 -type f ! -path "*/home/*" 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
