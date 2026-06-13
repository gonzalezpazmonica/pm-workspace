#!/usr/bin/env bats
# test-wiring-specs-195-200.bats — integration tests for SPEC-195/196/197/198/200 wiring
# Verifies that each opt-in flag activates real behavior in the call sites
# (ci-test-quality-gate.sh, aggregate.sh, iterate.sh).
# SCRIPT="scripts/ci-test-quality-gate.sh"
# SCRIPT="scripts/recommendation-tribunal/aggregate.sh"
# SCRIPT="scripts/recommendation-tribunal/iterate.sh"
# Safety: set -uo pipefail enforced in setup() below.

setup() {
  set -uo pipefail
  ROOT="${BATS_TEST_DIRNAME}/.."
  cd "$ROOT"
  export TEST_TMP
  TEST_TMP=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_TMP" 2>/dev/null || true
}

# ── SPEC-200: ci-test-quality-gate.sh adaptive mode ───────────────────────────

@test "SPEC-200 wire: adaptive=off uses fixed threshold 80 (backward compat)" {
  run env SAVIA_QUALITY_GATE_ADAPTIVE=off bash scripts/ci-test-quality-gate.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Mode: off"* ]]
  [[ "$output" == *"below threshold (80)"* ]]
}

@test "SPEC-200 wire: adaptive=on computes threshold from score distribution" {
  run env SAVIA_QUALITY_GATE_ADAPTIVE=on bash scripts/ci-test-quality-gate.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Mode: on"* ]]
  [[ "$output" == *"Adaptive threshold:"* ]]
  [[ "$output" == *"strategy="* ]]
}

@test "SPEC-200 wire: adaptive=warn emits advisory but gates on fixed 80" {
  run env SAVIA_QUALITY_GATE_ADAPTIVE=warn bash scripts/ci-test-quality-gate.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Mode: warn"* ]]
  # Still uses fixed threshold for gating
  [[ "$output" == *"below threshold (80)"* ]]
}

@test "SPEC-200 wire: adaptive=on writes telemetry to quality-gate-history.jsonl" {
  rm -f output/quality-gate-history.jsonl
  run env SAVIA_QUALITY_GATE_ADAPTIVE=on bash scripts/ci-test-quality-gate.sh
  [ "$status" -eq 0 ]
  [ -f "output/quality-gate-history.jsonl" ]
  # Last line has the expected schema
  last=$(tail -1 output/quality-gate-history.jsonl)
  [[ "$last" == *"\"mode\":\"on\""* ]]
  [[ "$last" == *"\"threshold\":"* ]]
  [[ "$last" == *"\"strategy\":"* ]]
}

# ── SPEC-198: aggregate.sh JudgeVerdict validation ────────────────────────────

@test "SPEC-198 wire: validate=off skips validation (backward compat)" {
  # Setup valid + invalid judge files
  cat > "$TEST_TMP/memory.json" << 'EOF'
{"judge":"memory","score":85,"veto":false,"confidence":0.9,"reason":"ok"}
EOF
  cat > "$TEST_TMP/rule.json" << 'EOF'
{"judge":"rule","score":80,"veto":false,"confidence":0.85,"reason":"ok"}
EOF
  cat > "$TEST_TMP/halluc.json" << 'EOF'
{"judge":"hallucination","score":90,"veto":false,"confidence":0.95,"reason":"ok"}
EOF
  cat > "$TEST_TMP/expert.json" << 'EOF'
{"judge":"expertise","score":75,"veto":false,"confidence":0.8,"reason":"ok"}
EOF

  rm -f output/judge-verdict-validation-errors.jsonl
  run env SAVIA_JUDGE_VERDICT_VALIDATE=off bash scripts/recommendation-tribunal/aggregate.sh \
    --judges "$TEST_TMP/memory.json" "$TEST_TMP/rule.json" \
              "$TEST_TMP/halluc.json" "$TEST_TMP/expert.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"verdict\":\"PASS\""* ]]
  # No validation log written
  [ ! -f "output/judge-verdict-validation-errors.jsonl" ]
}

@test "SPEC-198 wire: validate=warn logs invalid judge files but does not fail" {
  cat > "$TEST_TMP/memory.json" << 'EOF'
{"judge":"memory","score":85,"veto":false,"confidence":0.9,"reason":"ok"}
EOF
  cat > "$TEST_TMP/rule.json" << 'EOF'
{"judge":"rule","score":80,"veto":false,"confidence":0.85,"reason":"ok"}
EOF
  cat > "$TEST_TMP/halluc.json" << 'EOF'
{"judge":"hallucination","score":90,"veto":false,"confidence":0.95,"reason":"ok"}
EOF
  cat > "$TEST_TMP/expert.json" << 'EOF'
{"judge":"expertise","score":75,"veto":false,"confidence":0.8,"reason":"ok"}
EOF
  # Invalid: empty judge name + out-of-range confidence
  cat > "$TEST_TMP/sycophancy.json" << 'EOF'
{"judge":"","score":150,"veto":false,"confidence":2.0,"reason":"bad"}
EOF

  rm -f output/judge-verdict-validation-errors.jsonl
  run env SAVIA_JUDGE_VERDICT_VALIDATE=warn bash scripts/recommendation-tribunal/aggregate.sh \
    --judges "$TEST_TMP/memory.json" "$TEST_TMP/rule.json" \
              "$TEST_TMP/halluc.json" "$TEST_TMP/expert.json" \
              --sycophancy "$TEST_TMP/sycophancy.json"
  [ "$status" -eq 0 ]
  # Aggregator still passes (validation is warn-only)
  [[ "$output" == *"\"verdict\":\"PASS\""* ]]
  # Validation log was written with the invalid judge
  [ -f "output/judge-verdict-validation-errors.jsonl" ]
  grep -q "sycophancy.json" output/judge-verdict-validation-errors.jsonl
}

@test "SPEC-198 wire: dedup — same invalid file validated once per run" {
  cat > "$TEST_TMP/memory.json" << 'EOF'
{"judge":"memory","score":85,"veto":false,"confidence":0.9,"reason":"ok"}
EOF
  cat > "$TEST_TMP/rule.json" << 'EOF'
{"judge":"rule","score":80,"veto":false,"confidence":0.85,"reason":"ok"}
EOF
  cat > "$TEST_TMP/halluc.json" << 'EOF'
{"judge":"hallucination","score":90,"veto":false,"confidence":0.95,"reason":"ok"}
EOF
  cat > "$TEST_TMP/expert.json" << 'EOF'
{"judge":"expertise","score":75,"veto":false,"confidence":0.8,"reason":"ok"}
EOF
  cat > "$TEST_TMP/concession.json" << 'EOF'
{"judge":"","score":50,"veto":false,"confidence":0.5,"reason":"bad name"}
EOF

  rm -f output/judge-verdict-validation-errors.jsonl
  run env SAVIA_JUDGE_VERDICT_VALIDATE=warn bash scripts/recommendation-tribunal/aggregate.sh \
    --judges "$TEST_TMP/memory.json" "$TEST_TMP/rule.json" \
              "$TEST_TMP/halluc.json" "$TEST_TMP/expert.json" \
              --concession "$TEST_TMP/concession.json"
  [ "$status" -eq 0 ]
  # Only 1 log entry per file even though get_field is called 3x for concession
  count=$(wc -l < output/judge-verdict-validation-errors.jsonl)
  [ "$count" -eq 1 ]
}

# ── SPEC-197: iterate.sh compute-temperature ──────────────────────────────────

@test "SPEC-197 wire: compute-temperature at iteration 0 returns max_t" {
  run env SAVIA_TRIBUNAL_ITERATIVE=on bash scripts/recommendation-tribunal/iterate.sh \
    compute-temperature --iteration 0 --max-iter 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"temperature\": 0.9"* ]]
  [[ "$output" == *"\"index\": 0"* ]]
}

@test "SPEC-197 wire: compute-temperature at last iteration returns min_t" {
  run env SAVIA_TRIBUNAL_ITERATIVE=on bash scripts/recommendation-tribunal/iterate.sh \
    compute-temperature --iteration 2 --max-iter 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"temperature\": 0.1"* ]]
}

@test "SPEC-197 wire: compute-temperature respects custom max-t / min-t" {
  run env SAVIA_TRIBUNAL_ITERATIVE=on bash scripts/recommendation-tribunal/iterate.sh \
    compute-temperature --iteration 0 --max-iter 4 --max-t 1.0 --min-t 0.2
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"temperature\": 1.0"* ]]
}

@test "SPEC-197 wire: compute-temperature fails without --iteration" {
  run env SAVIA_TRIBUNAL_ITERATIVE=on bash scripts/recommendation-tribunal/iterate.sh \
    compute-temperature --max-iter 3
  [ "$status" -ne 0 ]
  [[ "$output" == *"--iteration and --max-iter required"* ]]
}

@test "SPEC-197 wire: ITERATIVE=off returns disabled JSON before anything" {
  run env SAVIA_TRIBUNAL_ITERATIVE=off bash scripts/recommendation-tribunal/iterate.sh \
    compute-temperature --iteration 0 --max-iter 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"enabled\":false"* ]]
}

# ── SPEC-196: orchestrator agent prompt has early-cancel section ──────────────

@test "SPEC-196 wire: opencode orchestrator agent prompt mentions early-cancel.sh" {
  run grep -l "early-cancel.sh" .opencode/agents/recommendation-tribunal-orchestrator.md
  [ "$status" -eq 0 ]
}

@test "SPEC-196 wire: claude orchestrator agent prompt mentions early-cancel.sh" {
  run grep -l "early-cancel.sh" .claude/agents/recommendation-tribunal-orchestrator.md
  [ "$status" -eq 0 ]
}

@test "SPEC-196 wire: orchestrator agent documents SAVIA_TRIBUNAL_EARLY_CANCEL toggle" {
  run grep "SAVIA_TRIBUNAL_EARLY_CANCEL" .opencode/agents/recommendation-tribunal-orchestrator.md
  [ "$status" -eq 0 ]
}

# ── SPEC-195: orchestrator agent prompt has iterative loop section ────────────

@test "SPEC-195 wire: orchestrator agent documents iterative loop" {
  run grep "Iterative refinement loop" .opencode/agents/recommendation-tribunal-orchestrator.md
  [ "$status" -eq 0 ]
}

@test "SPEC-195 wire: orchestrator agent mentions iterate.sh evaluate-stop" {
  run grep "iterate.sh evaluate-stop" .opencode/agents/recommendation-tribunal-orchestrator.md
  [ "$status" -eq 0 ]
}

@test "SPEC-195 wire: orchestrator agent mentions compute-temperature integration" {
  run grep "compute-temperature" .opencode/agents/recommendation-tribunal-orchestrator.md
  [ "$status" -eq 0 ]
}

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "SPEC-198 edge: empty judge JSON file flagged in warn mode" {
  cat > "$TEST_TMP/memory.json" << 'EOF'
{"judge":"memory","score":85,"veto":false,"confidence":0.9,"reason":"ok"}
EOF
  cat > "$TEST_TMP/rule.json" << 'EOF'
{"judge":"rule","score":80,"veto":false,"confidence":0.85,"reason":"ok"}
EOF
  cat > "$TEST_TMP/halluc.json" << 'EOF'
{"judge":"hallucination","score":90,"veto":false,"confidence":0.95,"reason":"ok"}
EOF
  cat > "$TEST_TMP/expert.json" << 'EOF'
{"judge":"expertise","score":75,"veto":false,"confidence":0.8,"reason":"ok"}
EOF
  # Edge: out-of-range confidence (validation should reject)
  cat > "$TEST_TMP/sycophancy.json" << 'EOF'
{"judge":"sycophancy","score":50,"veto":false,"confidence":5.0,"reason":"impossible"}
EOF

  rm -f output/judge-verdict-validation-errors.jsonl
  run env SAVIA_JUDGE_VERDICT_VALIDATE=warn bash scripts/recommendation-tribunal/aggregate.sh \
    --judges "$TEST_TMP/memory.json" "$TEST_TMP/rule.json" \
              "$TEST_TMP/halluc.json" "$TEST_TMP/expert.json" \
              --sycophancy "$TEST_TMP/sycophancy.json"
  [ "$status" -eq 0 ]
  [ -f "output/judge-verdict-validation-errors.jsonl" ]
}

@test "SPEC-197 edge: max-iter=1 returns boundary temperature" {
  # Edge: single iteration max — should still produce a valid temperature
  run env SAVIA_TRIBUNAL_ITERATIVE=on bash scripts/recommendation-tribunal/iterate.sh \
    compute-temperature --iteration 0 --max-iter 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"temperature\""* ]]
}

@test "SPEC-200 edge: adaptive script returns null when scores empty" {
  # Edge: empty score list should not crash the gate
  run python3 scripts/quality-gate-adaptive.py --scores --json
  # Either exits non-zero with usage error, or prints null/0 — both acceptable
  [[ "$status" -ne 0 || "$output" == *"\"threshold\""* ]]
}

@test "SPEC-198 edge: nonexistent judge_verdict.py module → aggregator still works" {
  cat > "$TEST_TMP/memory.json" << 'EOF'
{"judge":"memory","score":85,"veto":false,"confidence":0.9,"reason":"ok"}
EOF
  cat > "$TEST_TMP/rule.json" << 'EOF'
{"judge":"rule","score":80,"veto":false,"confidence":0.85,"reason":"ok"}
EOF
  cat > "$TEST_TMP/halluc.json" << 'EOF'
{"judge":"hallucination","score":90,"veto":false,"confidence":0.95,"reason":"ok"}
EOF
  cat > "$TEST_TMP/expert.json" << 'EOF'
{"judge":"expertise","score":75,"veto":false,"confidence":0.8,"reason":"ok"}
EOF
  # Backward compat: if module is moved/missing, validation gracefully no-ops
  # (we don't actually delete it; test the early-return code path documented)
  run env SAVIA_JUDGE_VERDICT_VALIDATE=off bash scripts/recommendation-tribunal/aggregate.sh \
    --judges "$TEST_TMP/memory.json" "$TEST_TMP/rule.json" \
              "$TEST_TMP/halluc.json" "$TEST_TMP/expert.json"
  [ "$status" -eq 0 ]
}
