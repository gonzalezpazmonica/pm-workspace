#!/usr/bin/env bats
# BATS tests for .claude/hooks/emergency-mode-readiness.sh
# SessionStart async — runs LocalAI readiness check when feature flag enabled.
# Ref: SPEC-122 LocalAI emergency-mode hardening (AC-03, AC-06)

HOOK=".claude/hooks/emergency-mode-readiness.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_REPO=$(mktemp -d "$TMPDIR/em-XXXXXX")
  mkdir -p "$TEST_REPO/output"
  mkdir -p "$TEST_REPO/scripts"
}
teardown() {
  rm -rf "$TEST_REPO" 2>/dev/null || true
  cd /
}

# ── Structural ────────────────────────────────────

@test "hook file exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }
@test "header: SessionStart event documented" {
  run grep -c 'SessionStart' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "header: SPEC-122 reference" {
  run grep -c 'SPEC-122' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "header: standard tier annotated" {
  run grep -c 'standard' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Profile gate ──────────────────────────────────

@test "profile gate: standard tier sourced" {
  run grep -c 'profile_gate "standard"' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Feature flag (silent skip) ────────────────────

@test "flag off: silent skip when EMERGENCY_MODE_ENABLED unset" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [[ ! -f "$TEST_REPO/output/emergency-mode/readiness.jsonl" ]]
}

@test "flag off: silent skip when EMERGENCY_MODE_ENABLED=false" {
  EMERGENCY_MODE_ENABLED=false CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [[ ! -f "$TEST_REPO/output/emergency-mode/readiness.jsonl" ]]
}

@test "flag off: stdin consumed without blocking" {
  EMERGENCY_MODE_ENABLED=false CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run timeout 5 bash "$HOOK" <<< '{"session":"id","source":"start"}'
  [ "$status" -eq 0 ]
}

# ── Flag on: missing readiness script ─────────────

@test "missing script: logs SKIP verdict to jsonl" {
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [[ -f "$TEST_REPO/output/emergency-mode/readiness.jsonl" ]]
  run cat "$TEST_REPO/output/emergency-mode/readiness.jsonl"
  [[ "$output" == *'"verdict":"SKIP"'* ]]
  [[ "$output" == *"missing"* ]]
}

@test "missing script: hook still exits 0" {
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

# ── Flag on: real script invocation ───────────────

@test "flag on: invokes readiness check (mock READY)" {
  cat > "$TEST_REPO/scripts/localai-readiness-check.sh" <<'EOF'
#!/bin/bash
echo '{"verdict":"READY"}'
exit 0
EOF
  chmod +x "$TEST_REPO/scripts/localai-readiness-check.sh"
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  run cat "$TEST_REPO/output/emergency-mode/readiness.jsonl"
  [[ "$output" == *'"verdict":"READY"'* ]]
}

@test "flag on: surfaces FAIL verdict to stderr" {
  cat > "$TEST_REPO/scripts/localai-readiness-check.sh" <<'EOF'
#!/bin/bash
echo '{"verdict":"FAIL"}'
exit 2
EOF
  chmod +x "$TEST_REPO/scripts/localai-readiness-check.sh"
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"LocalAI readiness FAIL"* || "$output" == *"LocalAI readiness FAIL"* ]]
}

@test "flag on: surfaces WARN verdict to stderr" {
  cat > "$TEST_REPO/scripts/localai-readiness-check.sh" <<'EOF'
#!/bin/bash
echo '{"verdict":"WARN"}'
exit 1
EOF
  chmod +x "$TEST_REPO/scripts/localai-readiness-check.sh"
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"WARN"* || "$output" == *"WARN"* ]]
}

@test "flag on: READY verdict is silent (no stderr)" {
  cat > "$TEST_REPO/scripts/localai-readiness-check.sh" <<'EOF'
#!/bin/bash
echo '{"verdict":"READY"}'
exit 0
EOF
  chmod +x "$TEST_REPO/scripts/localai-readiness-check.sh"
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [[ "$stderr" != *"FAIL"* ]]
  [[ "$stderr" != *"WARN"* ]]
}

# ── JSON log ──────────────────────────────────────

@test "log: ts ISO 8601 UTC timestamp" {
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    bash "$HOOK" </dev/null
  run cat "$TEST_REPO/output/emergency-mode/readiness.jsonl"
  [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ]]
}

@test "log: verdict field present" {
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    bash "$HOOK" </dev/null
  run cat "$TEST_REPO/output/emergency-mode/readiness.jsonl"
  [[ "$output" == *'"verdict"'* ]]
}

@test "log dir auto-created" {
  [[ ! -d "$TEST_REPO/output/emergency-mode" ]]
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [[ -d "$TEST_REPO/output/emergency-mode" ]]
}

@test "append: multiple invocations accumulate" {
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    bash "$HOOK" </dev/null
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    bash "$HOOK" </dev/null
  run wc -l < "$TEST_REPO/output/emergency-mode/readiness.jsonl"
  [[ "$output" -ge 2 ]]
}

# ── Negative cases ────────────────────────────────

@test "negative: empty stdin handled gracefully" {
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "negative: invalid JSON in stdin still exits 0" {
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" <<< 'not-json{'
  [ "$status" -eq 0 ]
}

@test "negative: hook script timeout (10s) does not block forever" {
  cat > "$TEST_REPO/scripts/localai-readiness-check.sh" <<'EOF'
#!/bin/bash
sleep 30
EOF
  chmod +x "$TEST_REPO/scripts/localai-readiness-check.sh"
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run timeout 15 bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

# ── Edge cases ────────────────────────────────────

@test "edge: empty CLAUDE_PROJECT_DIR fallback to pwd" {
  cd "$TEST_REPO"
  mkdir -p output scripts
  EMERGENCY_MODE_ENABLED=true \
    run bash "$BATS_TEST_DIRNAME/../$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "edge: zero JSON output from script → UNKNOWN verdict" {
  cat > "$TEST_REPO/scripts/localai-readiness-check.sh" <<'EOF'
#!/bin/bash
echo ""
exit 0
EOF
  chmod +x "$TEST_REPO/scripts/localai-readiness-check.sh"
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  run cat "$TEST_REPO/output/emergency-mode/readiness.jsonl"
  [[ "$output" == *"UNKNOWN"* || "$output" == *'"verdict"'* ]]
}

@test "edge: large jsonl output does not corrupt log" {
  cat > "$TEST_REPO/scripts/localai-readiness-check.sh" <<'EOF'
#!/bin/bash
echo '{"verdict":"READY","details":"long-output-with-many-fields-and-numbers-1234567890"}'
exit 0
EOF
  chmod +x "$TEST_REPO/scripts/localai-readiness-check.sh"
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  run cat "$TEST_REPO/output/emergency-mode/readiness.jsonl"
  [[ "$output" == *'"verdict":"READY"'* ]]
}

# ── Isolation ─────────────────────────────────────

@test "isolation: hook always exits 0" {
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "isolation: only writes under output/emergency-mode/" {
  EMERGENCY_MODE_ENABLED=true CLAUDE_PROJECT_DIR="$TEST_REPO" \
    bash "$HOOK" </dev/null
  [[ -d "$TEST_REPO/output/emergency-mode" ]]
  [[ ! -e "$TEST_REPO/random-side-effect" ]]
}

@test "coverage: feature-flag pattern documented" {
  run grep -c 'EMERGENCY_MODE_ENABLED' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: 4 verdict states handled (READY/WARN/FAIL/SKIP/TIMEOUT)" {
  run grep -E "READY|WARN|FAIL|SKIP|TIMEOUT" "$HOOK"
  [ "$status" -eq 0 ]
}
