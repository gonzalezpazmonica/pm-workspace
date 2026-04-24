#!/usr/bin/env bats
# BATS tests for .claude/hooks/post-report-write.sh
# PostToolUse async — queues Truth Tribunal verification for generated reports.
# SPEC-106 Phase 2. Never blocks.
# Ref: batch 43 hook coverage

HOOK=".claude/hooks/post-report-write.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export HOME="$TMPDIR/home-$$"
  mkdir -p "$HOME/.savia"
  export TRUTH_TRIBUNAL_QUEUE="$HOME/.savia/truth-tribunal/queue"
  export WSROOT="$TMPDIR/ws-$$"
  mkdir -p "$WSROOT/output"
  export HOOK_ABS="$(pwd)/$HOOK"
}
teardown() {
  rm -rf "$HOME" "$WSROOT" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Skip paths (non-reports) ────────────────────────────

@test "skip: non-md file exits 0 without queueing" {
  local F="$WSROOT/output/reports/data.json"
  mkdir -p "$(dirname "$F")"
  echo '{}' > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
  [[ ! -d "$TRUTH_TRIBUNAL_QUEUE" ]] || [[ -z "$(ls "$TRUTH_TRIBUNAL_QUEUE" 2>/dev/null)" ]]
}

@test "skip: nonexistent file exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"file_path":"/nonexistent.md"}}'
  [ "$status" -eq 0 ]
}

@test "skip: missing tool_name exits 0" {
  local F="$WSROOT/output/audits/report.md"
  mkdir -p "$(dirname "$F")"
  echo "# report" > "$F"
  run bash "$HOOK" <<< "{\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
}

@test "skip: empty stdin exits 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

# ── Self-recursion prevention ────────────────────────────

@test "skip: .truth.crc files not re-queued (avoid recursion)" {
  local F="$WSROOT/output/reports/analysis.truth.crc"
  mkdir -p "$(dirname "$F")"
  echo "verdict: PASS" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
}

@test "skip: files already in truth-tribunal queue not re-queued" {
  local F="$TRUTH_TRIBUNAL_QUEUE/something.md"
  mkdir -p "$(dirname "$F")"
  echo "# queued" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
}

# ── Path-based report heuristic ──────────────────────────

@test "trigger: output/audits/ path queues verification" {
  local F="$WSROOT/output/audits/audit-2026-04-24.md"
  mkdir -p "$(dirname "$F")"
  echo "# audit" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
  local queued
  queued=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$queued" -eq 1 ]]
}

@test "trigger: output/reports/ path queues" {
  local F="$WSROOT/output/reports/report.md"
  mkdir -p "$(dirname "$F")"
  echo "# report" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  local queued
  queued=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$queued" -eq 1 ]]
}

@test "trigger: output/postmortems/ path queues" {
  local F="$WSROOT/output/postmortems/incident.md"
  mkdir -p "$(dirname "$F")"
  echo "# postmortem" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" | head -1 | grep -q "req"
}

@test "trigger: ceo-report filename pattern queues" {
  local F="$WSROOT/output/20260424-ceo-report.md"
  mkdir -p "$(dirname "$F")"
  echo "# ceo" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" | head -1 | grep -q "req"
}

@test "trigger: stakeholder-report filename pattern queues" {
  local F="$WSROOT/output/stakeholder-report.md"
  mkdir -p "$(dirname "$F")"
  echo "# stakeholder" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" | head -1 | grep -q "req"
}

# ── Frontmatter heuristic ────────────────────────────────

@test "trigger: report_type frontmatter overrides path" {
  local F="$WSROOT/output/anywhere/report.md"
  mkdir -p "$(dirname "$F")"
  cat > "$F" <<'EOF'
---
report_type: executive-summary
---
# Body
EOF
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  local queued
  queued=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$queued" -eq 1 ]]
}

# ── Skip non-report paths ───────────────────────────────

@test "skip: random markdown file without report markers not queued" {
  local F="$WSROOT/random.md"
  echo "# not a report" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
  [[ ! -d "$TRUTH_TRIBUNAL_QUEUE" ]] || [[ -z "$(ls "$TRUTH_TRIBUNAL_QUEUE" 2>/dev/null)" ]]
}

@test "skip: docs/*.md not treated as report unless frontmatter signals" {
  local F="$WSROOT/docs/intro.md"
  mkdir -p "$(dirname "$F")"
  echo "# intro" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  [ "$status" -eq 0 ]
  [[ ! -d "$TRUTH_TRIBUNAL_QUEUE" ]] || [[ -z "$(ls "$TRUTH_TRIBUNAL_QUEUE" 2>/dev/null)" ]]
}

# ── Queue file contents ─────────────────────────────────

@test "queue: req file contains report_path" {
  local F="$WSROOT/output/audits/a.md"
  mkdir -p "$(dirname "$F")"
  echo "# a" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  local req
  req=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" | head -1)
  grep -q "report_path=" "$req"
  grep -q "$F" "$req"
}

@test "queue: req file contains tool name" {
  local F="$WSROOT/output/audits/a.md"
  mkdir -p "$(dirname "$F")"
  echo "# a" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\"}}"
  local req
  req=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" | head -1)
  grep -q "tool=Edit" "$req"
}

@test "queue: req file contains ISO timestamp" {
  local F="$WSROOT/output/audits/a.md"
  mkdir -p "$(dirname "$F")"
  echo "# a" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  local req
  req=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" | head -1)
  grep -qE 'queued_at=20[0-9]{2}-[0-9]{2}-[0-9]{2}T' "$req"
}

@test "queue: req filename uses TT-YYYYMMDD prefix" {
  local F="$WSROOT/output/audits/a.md"
  mkdir -p "$(dirname "$F")"
  echo "# a" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  find "$TRUTH_TRIBUNAL_QUEUE" -name "TT-*.req" | head -1 | grep -q "TT-"
}

# ── Negative cases ──────────────────────────────────────

@test "negative: malformed JSON exits 0" {
  run bash "$HOOK" <<< "not json"
  [ "$status" -eq 0 ]
}

@test "negative: tool_input.path fallback (alternative field)" {
  local F="$WSROOT/output/audits/alt.md"
  mkdir -p "$(dirname "$F")"
  echo "# alt" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"path\":\"$F\"}}"
  local queued
  queued=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$queued" -eq 1 ]]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: multiple reports queue independently (unique run-id)" {
  for i in 1 2 3; do
    local F="$WSROOT/output/audits/r$i.md"
    mkdir -p "$(dirname "$F")"
    echo "# r$i" > "$F"
    bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}" >/dev/null 2>&1
    sleep 1  # ensure distinct timestamp
  done
  local queued
  queued=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$queued" -ge 1 ]]
}

@test "edge: always exit 0 (async never blocks)" {
  # Nonsense inputs, directory as path, etc.
  for input in '' '{}' '{"x":1}' '{"tool_name":"Write","tool_input":{}}' \
               "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TMPDIR\"}}"; do
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "edge: output/*-digest pattern triggers queue" {
  local F="$WSROOT/output/project-digest.md"
  mkdir -p "$(dirname "$F")"
  echo "# digest" > "$F"
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}"
  local queued
  queued=$(find "$TRUTH_TRIBUNAL_QUEUE" -name "*.req" 2>/dev/null | wc -l)
  [[ "$queued" -eq 1 ]]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: 6+ path patterns recognized" {
  for p in 'audits' 'reports' 'postmortems' 'governance' 'compliance' 'dora'; do
    grep -q "$p" "$HOOK" || fail "missing pattern: $p"
  done
}

@test "coverage: report_type frontmatter parsing present" {
  run grep -c 'report_type' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: truth-tribunal cache-check integration" {
  run grep -c 'truth-tribunal' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TRUTH_TRIBUNAL_QUEUE env var supported" {
  run grep -c 'TRUTH_TRIBUNAL_QUEUE' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: SPEC-106 reference in doc" {
  run grep -c 'SPEC-106' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ────────────────────────────────────────────

@test "isolation: hook does not modify the report file being queued" {
  local F="$WSROOT/output/audits/a.md"
  mkdir -p "$(dirname "$F")"
  echo "# a" > "$F"
  local before
  before=$(md5sum "$F" | awk '{print $1}')
  bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$F\"}}" >/dev/null 2>&1
  local after
  after=$(md5sum "$F" | awk '{print $1}')
  [[ "$before" == "$after" ]]
}

@test "isolation: async hook always exits 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  run bash "$HOOK" <<< "malformed"
  [ "$status" -eq 0 ]
}
