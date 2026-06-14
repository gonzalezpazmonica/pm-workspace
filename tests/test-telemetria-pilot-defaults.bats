#!/usr/bin/env bats
# test-telemetria-pilot-defaults.bats — verify SPEC-198/200 telemetry pilot defaults
# When savia-env.sh is sourced without explicit env vars, SPEC-198/200 should
# default to 'warn' mode so telemetry logs are produced without blocking.
# SCRIPT="scripts/savia-env.sh"
# SCRIPT="scripts/ci-test-quality-gate.sh"
# SCRIPT="scripts/recommendation-tribunal/aggregate.sh"
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

# ── savia-env.sh exports defaults ───────────────────────────────────────────

@test "savia-env.sh defaults SPEC-200 ADAPTIVE to warn when unset" {
  run bash -c 'unset SAVIA_QUALITY_GATE_ADAPTIVE; source scripts/savia-env.sh; echo "$SAVIA_QUALITY_GATE_ADAPTIVE"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"warn"* ]]
}

@test "savia-env.sh defaults SPEC-198 VALIDATE to warn when unset" {
  run bash -c 'unset SAVIA_JUDGE_VERDICT_VALIDATE; source scripts/savia-env.sh; echo "$SAVIA_JUDGE_VERDICT_VALIDATE"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"warn"* ]]
}

@test "savia-env.sh respects explicit ADAPTIVE override (off)" {
  run bash -c 'export SAVIA_QUALITY_GATE_ADAPTIVE=off; source scripts/savia-env.sh; echo "$SAVIA_QUALITY_GATE_ADAPTIVE"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"off"* ]]
  [[ "$output" != *"warn"* ]]
}

@test "savia-env.sh respects explicit VALIDATE override (on)" {
  run bash -c 'export SAVIA_JUDGE_VERDICT_VALIDATE=on; source scripts/savia-env.sh; echo "$SAVIA_JUDGE_VERDICT_VALIDATE"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"on"* ]]
}

# ── End-to-end telemetry generation ─────────────────────────────────────────

@test "SPEC-200 e2e: ci-test-quality-gate writes JSONL when ADAPTIVE=warn" {
  rm -f output/quality-gate-history.jsonl
  run bash -c '
    unset SAVIA_QUALITY_GATE_ADAPTIVE
    source scripts/savia-env.sh
    bash scripts/ci-test-quality-gate.sh
  '
  [ "$status" -eq 0 ]
  [ -f "output/quality-gate-history.jsonl" ]
  # Last line has the warn-mode schema
  last=$(tail -1 output/quality-gate-history.jsonl)
  [[ "$last" == *"\"mode\":\"warn\""* ]]
  [[ "$last" == *"\"strategy\":"* ]]
}

@test "SPEC-198 e2e: aggregator writes JSONL when VALIDATE=warn and bad json present" {
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
  # Edge: out-of-range confidence and empty judge name
  cat > "$TEST_TMP/sycophancy.json" << 'EOF'
{"judge":"","score":0,"veto":false,"confidence":2.0,"reason":""}
EOF

  rm -f output/judge-verdict-validation-errors.jsonl
  run bash -c "
    unset SAVIA_JUDGE_VERDICT_VALIDATE
    source scripts/savia-env.sh
    bash scripts/recommendation-tribunal/aggregate.sh \
      --judges $TEST_TMP/memory.json $TEST_TMP/rule.json \
                $TEST_TMP/halluc.json $TEST_TMP/expert.json \
                --sycophancy $TEST_TMP/sycophancy.json
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"verdict\":\"PASS\""* ]]
  [ -f "output/judge-verdict-validation-errors.jsonl" ]
  grep -q "sycophancy.json" output/judge-verdict-validation-errors.jsonl
}

# ── CI workflow integration ────────────────────────────────────────────────

@test "ci.yml exports SAVIA_QUALITY_GATE_ADAPTIVE=warn for the quality gate step" {
  run grep -A8 'Gate: Test Quality' .github/workflows/ci.yml
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAVIA_QUALITY_GATE_ADAPTIVE"* ]]
  [[ "$output" == *"warn"* ]]
}

@test "ci.yml uploads SPEC-200 telemetry as artifact" {
  run grep -B2 -A6 "spec-200-telemetry" .github/workflows/ci.yml
  [ "$status" -eq 0 ]
  [[ "$output" == *"upload-artifact"* ]]
  [[ "$output" == *"quality-gate-history.jsonl"* ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: empty SAVIA_QUALITY_GATE_ADAPTIVE falls back to warn default" {
  # Empty string treated as unset by ${VAR:-default} expansion
  run bash -c 'export SAVIA_QUALITY_GATE_ADAPTIVE=""; source scripts/savia-env.sh; echo "$SAVIA_QUALITY_GATE_ADAPTIVE"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"warn"* ]]
}

@test "edge: nonexistent .env file does not break savia-env defaults" {
  # _savia_load_dotenv is a no-op when .env is absent; defaults still apply
  run bash -c '
    unset SAVIA_QUALITY_GATE_ADAPTIVE SAVIA_JUDGE_VERDICT_VALIDATE
    source scripts/savia-env.sh
    [[ "$SAVIA_QUALITY_GATE_ADAPTIVE" == "warn" ]] || exit 1
    [[ "$SAVIA_JUDGE_VERDICT_VALIDATE" == "warn" ]] || exit 1
    echo "ok"
  '
  [ "$status" -eq 0 ]
}

@test "edge: large telemetry history file does not block append" {
  # Boundary test: existing log with many entries should still accept a new one
  rm -f output/quality-gate-history.jsonl
  mkdir -p output
  for i in $(seq 1 500); do
    echo "{\"ts\":\"2026-01-01\",\"mode\":\"warn\",\"threshold\":80,\"strategy\":\"high_mean_strict\",\"mean\":85.0,\"stddev\":2.0,\"total_tests\":100}"
  done > output/quality-gate-history.jsonl
  initial_lines=$(wc -l < output/quality-gate-history.jsonl)
  [ "$initial_lines" -eq 500 ]

  run bash -c '
    source scripts/savia-env.sh
    bash scripts/ci-test-quality-gate.sh > /dev/null 2>&1
  '
  [ "$status" -eq 0 ]
  final_lines=$(wc -l < output/quality-gate-history.jsonl)
  [ "$final_lines" -gt "$initial_lines" ]
}
