#!/usr/bin/env bats
# BATS tests for .claude/hooks/emotional-regulation-monitor.sh
# Stop hook: assesses session stress, persists high-friction sessions to memory.
# Source: Anthropic "Emotion concepts in LLMs" (2026-04-02)
# Ref: batch 41 hook coverage

HOOK=".claude/hooks/emotional-regulation-monitor.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  # Isolate HOME so memory writes go to TMPDIR
  export HOME="$TMPDIR/home-$$"
  mkdir -p "$HOME/.savia" "$HOME/.claude"
  # Fake workspace with tracker mock
  export CLAUDE_PROJECT_DIR="$TMPDIR/ws-$$"
  mkdir -p "$CLAUDE_PROJECT_DIR/scripts"
  export STATE_FILE="$HOME/.savia/session-stress.json"
}
teardown() {
  rm -rf "$HOME" "$CLAUDE_PROJECT_DIR" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Skip paths (tracker/state missing) ───────────────────

@test "skip: tracker script missing exits 0" {
  # No scripts/emotional-state-tracker.sh in our fake workspace
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "skip: state file missing exits 0" {
  # Create fake tracker but no state file
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
echo "0"
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

# ── Low friction (score < 5) — no persist ───────────────

@test "low-friction: score < 5 exits 0 with no memory write" {
  # Fake tracker returns 2
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
case "$1" in score) echo "2" ;; *) echo "score: 2" ;; esac
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo '{"retry":1}' > "$STATE_FILE"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  # No memory file created for low friction
  local memfiles
  memfiles=$(find "$HOME/.claude" -name "session_stress_*.md" 2>/dev/null | wc -l)
  [[ "$memfiles" -eq 0 ]]
}

# ── Significant friction (5+) — memory persist ──────────

@test "persist: score 5 writes memory file" {
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
case "$1" in score) echo "5" ;; status) echo "score: 5 with 3 retries" ;; esac
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo '{"retry":3,"failure":2}' > "$STATE_FILE"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  # Memory file created
  local memfiles
  memfiles=$(find "$HOME/.claude" -name "session_stress_*.md" 2>/dev/null | wc -l)
  [[ "$memfiles" -eq 1 ]]
}

@test "level: score 9+ labelled overload" {
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
case "$1" in score) echo "9" ;; status) echo "overload state" ;; esac
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo '{"retry":5}' > "$STATE_FILE"
  run bash "$HOOK" <<< ""
  local memfile
  memfile=$(find "$HOME/.claude" -name "session_stress_*.md" 2>/dev/null | head -1)
  [[ -n "$memfile" ]]
  grep -q 'overload' "$memfile"
}

@test "level: score 7-8 labelled high_stress" {
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
case "$1" in score) echo "7" ;; status) echo "high stress" ;; esac
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo '{"failure":4}' > "$STATE_FILE"
  run bash "$HOOK" <<< ""
  local memfile
  memfile=$(find "$HOME/.claude" -name "session_stress_*.md" 2>/dev/null | head -1)
  grep -q 'high_stress' "$memfile"
}

@test "level: score 5-6 labelled significant_friction" {
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
case "$1" in score) echo "5" ;; status) echo "moderate friction" ;; esac
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo '{"retry":2}' > "$STATE_FILE"
  run bash "$HOOK" <<< ""
  local memfile
  memfile=$(find "$HOME/.claude" -name "session_stress_*.md" 2>/dev/null | head -1)
  grep -q 'significant_friction' "$memfile"
}

# ── Dedup: don't persist twice per day ──────────────────

@test "dedup: same-day re-invocation does not create duplicate" {
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
case "$1" in score) echo "6" ;; status) echo "x" ;; esac
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo '{"retry":3}' > "$STATE_FILE"
  # Pre-populate MEMORY.md with today's entry
  local PROJ_SLUG
  PROJ_SLUG=$(echo "$CLAUDE_PROJECT_DIR" | sed 's|[/:\]|-|g; s|^-||')
  local MEMORY_DIR="$HOME/.claude/projects/$PROJ_SLUG/memory"
  mkdir -p "$MEMORY_DIR"
  local TS
  TS=$(date +%Y-%m-%d)
  echo "- [Session stress $TS](session_stress_${TS}.md) — prev entry" > "$MEMORY_DIR/MEMORY.md"
  : > "$STATE_FILE"
  echo '{"retry":3}' > "$STATE_FILE"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  # Should not have created a new file (pre-existing entry detected)
  local count
  count=$(grep -cF "session_stress_${TS}" "$MEMORY_DIR/MEMORY.md" || echo 0)
  [[ "$count" -eq 1 ]]
}

# ── MEMORY.md index update ─────────────────────────────

@test "index: MEMORY.md updated when new stress entry persisted" {
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
case "$1" in score) echo "6" ;; status) echo "x" ;; esac
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo '{"retry":3}' > "$STATE_FILE"
  local PROJ_SLUG
  PROJ_SLUG=$(echo "$CLAUDE_PROJECT_DIR" | sed 's|[/:\]|-|g; s|^-||')
  local MEMORY_DIR="$HOME/.claude/projects/$PROJ_SLUG/memory"
  mkdir -p "$MEMORY_DIR"
  echo "# MEMORY Index" > "$MEMORY_DIR/MEMORY.md"
  run bash "$HOOK" <<< ""
  [[ -f "$MEMORY_DIR/MEMORY.md" ]]
  grep -q 'session_stress' "$MEMORY_DIR/MEMORY.md"
}

# ── Negative cases ──────────────────────────────────────

@test "negative: tracker returns non-numeric handled as 0" {
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
echo "error: not a number"
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo '{"retry":1}' > "$STATE_FILE"
  run bash "$HOOK" <<< ""
  # Should not crash
  [ "$status" -eq 0 ]
}

@test "negative: malformed state file JSON does not crash" {
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
case "$1" in score) echo "5" ;; status) echo "x" ;; esac
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo "malformed {not json" > "$STATE_FILE"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "negative: empty stdin handled" {
  run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: score boundary exactly 5 triggers persist" {
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
case "$1" in score) echo "5" ;; status) echo "boundary" ;; esac
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo '{"retry":2}' > "$STATE_FILE"
  run bash "$HOOK" <<< ""
  local count
  count=$(find "$HOME/.claude" -name "session_stress_*.md" 2>/dev/null | wc -l)
  [[ "$count" -eq 1 ]]
}

@test "edge: score boundary exactly 4 does not persist" {
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<'EOF'
#!/bin/bash
case "$1" in score) echo "4" ;; *) echo "low" ;; esac
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo '{"retry":1}' > "$STATE_FILE"
  run bash "$HOOK" <<< ""
  local count
  count=$(find "$HOME/.claude" -name "session_stress_*.md" 2>/dev/null | wc -l)
  [[ "$count" -eq 0 ]]
}

@test "edge: tracker reset always called on low friction" {
  local RESET_FLAG="$TMPDIR/reset-flag-$$"
  cat > "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh" <<EOF
#!/bin/bash
case "\$1" in
  score) echo "2" ;;
  reset) touch "$RESET_FLAG" ;;
  *) echo "low" ;;
esac
EOF
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/emotional-state-tracker.sh"
  echo '{"x":0}' > "$STATE_FILE"
  run bash "$HOOK" <<< ""
  [[ -f "$RESET_FLAG" ]]
  rm -f "$RESET_FLAG"
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: 3 level thresholds (overload, high_stress, significant_friction)" {
  for level in overload high_stress significant_friction; do
    grep -q "$level" "$HOOK" || fail "missing level: $level"
  done
}

@test "coverage: 4 event counters tracked (retry, failure, escalation, rule_skip)" {
  for c in RETRIES FAILURES ESCALATIONS RULE_SKIPS; do
    grep -q "$c" "$HOOK" || fail "missing counter: $c"
  done
}

@test "coverage: Anthropic research reference in doc" {
  run grep -c 'Anthropic' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────────

@test "isolation: hook always exits 0 (never blocks stop)" {
  for input in '' 'garbage' '{"x":"y"}'; do
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook does not modify CLAUDE_PROJECT_DIR content" {
  local before
  before=$(find "$CLAUDE_PROJECT_DIR" -type f 2>/dev/null | wc -l)
  bash "$HOOK" <<< "" >/dev/null 2>&1 || true
  local after
  after=$(find "$CLAUDE_PROJECT_DIR" -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
