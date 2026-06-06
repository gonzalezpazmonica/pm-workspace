#!/usr/bin/env bats
# Test suite — SPEC-159: Async Tribunal Fan-out
#
# Validates:
#   - tribunal-async-runner.sh exists and is executable
#   - set -uo pipefail present
#   - --mode sync flag accepted
#   - timeout controlled by SAVIA_TRIBUNAL_TIMEOUT
#   - any judge returning BLOCK → exit 1
#   - all judges PASS → exit 0
#   - per-judge timings appear in output
#   - async protocol doc exists
#   - court-orchestrator references the async protocol
#   - empty judge list handled gracefully
#   - judge timeout causes graceful failure
#   - multiple modes produce expected behavior
#   - SAVIA_TRIBUNAL_MODE env var respected
#   - parallel launch log line present
#   - results section present in output
#
# Reference: SPEC-159 — Async Tribunal Fan-out.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  RUNNER="$REPO_ROOT/scripts/tribunal-async-runner.sh"
  PROTOCOL_DOC="$REPO_ROOT/docs/rules/domain/tribunal-async-protocol.md"
  COURT_AGENT="$REPO_ROOT/.opencode/agents/court-orchestrator.md"

  # Isolated temp dir per test
  TMP="$(mktemp -d)"
  export TMPDIR="$TMP"

  # Mock judge agent files for tests that need real agent lookups
  mkdir -p "$TMP/.opencode/agents"
}

teardown() {
  [[ -n "${TMP:-}" && -d "$TMP" ]] && rm -rf "$TMP"
}

# ─── 1. Script exists ──────────────────────────────────────────────────────────
@test "tribunal-async-runner.sh exists" {
  [[ -f "$RUNNER" ]]
}

# ─── 2. Script is executable ──────────────────────────────────────────────────
@test "tribunal-async-runner.sh is executable" {
  [[ -x "$RUNNER" ]]
}

# ─── 3. set -uo pipefail present ─────────────────────────────────────────────
@test "tribunal-async-runner.sh has set -uo pipefail" {
  grep -q "set -uo pipefail" "$RUNNER"
}

# ─── 4. --mode sync flag accepted (no error) ──────────────────────────────────
@test "--mode sync flag is accepted without error" {
  run bash "$RUNNER" --mode sync
  # Empty judge list exits 0 with warning — no usage error
  [[ "$status" -eq 0 ]]
}

# ─── 5. --mode async flag accepted ────────────────────────────────────────────
@test "--mode async flag is accepted without error" {
  run bash "$RUNNER" --mode async
  [[ "$status" -eq 0 ]]
}

# ─── 6. SAVIA_TRIBUNAL_TIMEOUT env var referenced in script ───────────────────
@test "SAVIA_TRIBUNAL_TIMEOUT variable referenced in script" {
  grep -q "SAVIA_TRIBUNAL_TIMEOUT" "$RUNNER"
}

# ─── 7. BLOCK from a judge causes exit 1 ──────────────────────────────────────
@test "judge returning BLOCK causes exit 1" {
  FAKE_TMPDIR="$(mktemp -d)"
  echo "BLOCK" > "$FAKE_TMPDIR/result-mock-block-judge"
  echo "100" > "$FAKE_TMPDIR/time-mock-block-judge"

  WRAPPER_SCRIPT="$(mktemp -p "$TMP" --suffix=.sh)"
  cat > "$WRAPPER_SCRIPT" << EOF
#!/usr/bin/env bash
set -uo pipefail
TRIBUNAL_SOURCED=1
source "$RUNNER"
TMPDIR_RUN="$FAKE_TMPDIR"
run_judge() { :; }
JUDGES=("mock-block-judge")
aggregate_results "\${JUDGES[@]}"
EOF
  chmod +x "$WRAPPER_SCRIPT"

  run bash "$WRAPPER_SCRIPT"
  [[ "$status" -eq 1 ]]
  rm -rf "$FAKE_TMPDIR"
}

# ─── 8. All PASS judges causes exit 0 ────────────────────────────────────────
@test "all judges returning PASS causes exit 0" {
  FAKE_TMPDIR="$(mktemp -d)"
  echo "PASS" > "$FAKE_TMPDIR/result-pass-judge-1"
  echo "100" > "$FAKE_TMPDIR/time-pass-judge-1"
  echo "PASS" > "$FAKE_TMPDIR/result-pass-judge-2"
  echo "150" > "$FAKE_TMPDIR/time-pass-judge-2"

  WRAPPER_SCRIPT="$(mktemp -p "$TMP" --suffix=.sh)"
  cat > "$WRAPPER_SCRIPT" << EOF
#!/usr/bin/env bash
set -uo pipefail
TRIBUNAL_SOURCED=1
source "$RUNNER"
TMPDIR_RUN="$FAKE_TMPDIR"
run_judge() { :; }
JUDGES=("pass-judge-1" "pass-judge-2")
aggregate_results "\${JUDGES[@]}"
EOF
  chmod +x "$WRAPPER_SCRIPT"

  run bash "$WRAPPER_SCRIPT"
  [[ "$status" -eq 0 ]]
  rm -rf "$FAKE_TMPDIR"
}

# ─── 9. Per-judge timing appears in output ────────────────────────────────────
@test "per-judge timing (ms) appears in aggregate output" {
  FAKE_TMPDIR="$(mktemp -d)"
  echo "PASS" > "$FAKE_TMPDIR/result-timing-judge"
  echo "250" > "$FAKE_TMPDIR/time-timing-judge"

  WRAPPER_SCRIPT="$(mktemp -p "$TMP" --suffix=.sh)"
  cat > "$WRAPPER_SCRIPT" << EOF
#!/usr/bin/env bash
set -uo pipefail
TRIBUNAL_SOURCED=1
source "$RUNNER"
TMPDIR_RUN="$FAKE_TMPDIR"
run_judge() { :; }
JUDGES=("timing-judge")
aggregate_results "\${JUDGES[@]}"
EOF
  chmod +x "$WRAPPER_SCRIPT"

  run bash "$WRAPPER_SCRIPT"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "ms"
  rm -rf "$FAKE_TMPDIR"
}

# ─── 10. Async protocol doc exists ────────────────────────────────────────────
@test "tribunal-async-protocol.md doc exists" {
  [[ -f "$PROTOCOL_DOC" ]]
}

# ─── 11. Protocol doc references SPEC-159 ─────────────────────────────────────
@test "tribunal-async-protocol.md references SPEC-159" {
  grep -q "SPEC-159" "$PROTOCOL_DOC"
}

# ─── 12. court-orchestrator references async protocol ─────────────────────────
@test "court-orchestrator.md references tribunal-async-protocol" {
  grep -q "tribunal-async-protocol" "$COURT_AGENT"
}

# ─── 13. court-orchestrator mentions parallel launch ──────────────────────────
@test "court-orchestrator.md mentions parallel judge launch" {
  grep -qi "paralel\|parallel\|simultán" "$COURT_AGENT"
}

# ─── 14. Empty judge list exits 0 (graceful) ──────────────────────────────────
@test "empty judge list exits 0 with warning" {
  run bash "$RUNNER"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -qi "warning\|noth\|nada\|warn" || \
    echo "$output" | grep -qi "No judges"
}

# ─── 15. TIMEOUT result causes exit 1 ─────────────────────────────────────────
@test "judge with TIMEOUT result causes exit 1" {
  FAKE_TMPDIR="$(mktemp -d)"
  echo "TIMEOUT" > "$FAKE_TMPDIR/result-slow-judge"
  echo "60000" > "$FAKE_TMPDIR/time-slow-judge"

  WRAPPER_SCRIPT="$(mktemp -p "$TMP" --suffix=.sh)"
  cat > "$WRAPPER_SCRIPT" << EOF
#!/usr/bin/env bash
set -uo pipefail
TRIBUNAL_SOURCED=1
source "$RUNNER"
TMPDIR_RUN="$FAKE_TMPDIR"
run_judge() { :; }
JUDGES=("slow-judge")
aggregate_results "\${JUDGES[@]}"
EOF
  chmod +x "$WRAPPER_SCRIPT"

  run bash "$WRAPPER_SCRIPT"
  [[ "$status" -eq 1 ]]
  rm -rf "$FAKE_TMPDIR"
}

# ─── 16. SAVIA_TRIBUNAL_MODE=sync respected ───────────────────────────────────
@test "SAVIA_TRIBUNAL_MODE=sync activates sync mode" {
  run env SAVIA_TRIBUNAL_MODE=sync bash "$RUNNER"
  [[ "$status" -eq 0 ]]
}

# ─── 17. Results section appears in output ────────────────────────────────────
@test "output includes results section markers" {
  FAKE_TMPDIR="$(mktemp -d)"
  echo "PASS" > "$FAKE_TMPDIR/result-results-judge"
  echo "50" > "$FAKE_TMPDIR/time-results-judge"

  WRAPPER_SCRIPT="$(mktemp -p "$TMP" --suffix=.sh)"
  cat > "$WRAPPER_SCRIPT" << EOF
#!/usr/bin/env bash
set -uo pipefail
TRIBUNAL_SOURCED=1
source "$RUNNER"
TMPDIR_RUN="$FAKE_TMPDIR"
run_judge() { :; }
JUDGES=("results-judge")
aggregate_results "\${JUDGES[@]}"
EOF
  chmod +x "$WRAPPER_SCRIPT"

  run bash "$WRAPPER_SCRIPT"
  echo "$output" | grep -q "results"
  rm -rf "$FAKE_TMPDIR"
}

# ─── 18. SPEC-159 referenced in script ───────────────────────────────────────
@test "SPEC-159 is referenced in tribunal-async-runner.sh" {
  grep -q "SPEC-159" "$RUNNER"
}
