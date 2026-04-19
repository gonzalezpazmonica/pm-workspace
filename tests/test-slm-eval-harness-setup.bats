#!/usr/bin/env bats
# BATS tests for scripts/slm-eval-harness-setup.sh (SLM Fase 5 scaffolding).
# Validates config YAML emission, prompts sampling, benchmark allowlist,
# CLI surface, negatives, isolation.
#
# Ref: docs/rules/domain/slm-training-pipeline.md §Fase 5
# Safety: script under test `set -uo pipefail`, read-only del seed.

SCRIPT="scripts/slm-eval-harness-setup.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# Helper: create a seed JSONL.
make_seed() {
  local path="$1"
  cat > "$path" <<'EOF'
{"instruction":"Summarize SPEC-023","output":"Savia LLM Trainer."}
{"instruction":"What is Unsloth?","output":"QLoRA training framework."}
{"instruction":"Explain SE-029","output":"Rate-distortion compression."}
EOF
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script references SE-027 Fase 5" {
  run grep -c 'SE-027' "$SCRIPT"
  [[ "$output" -ge 1 ]]
  run grep -c 'Fase 5\|Phase 5' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script clarifies it does NOT execute eval" {
  run grep -ciE 'NOT execute|no ejecut|does not execute|scaffold' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI surface ─────────────────────────────────────────────────────────────

@test "script accepts --help and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"model"* ]]
  [[ "$output" == *"benchmarks"* ]]
}

@test "script rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "script requires --model" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  make_seed "$seed"
  run bash "$SCRIPT" --seed "$seed" --output-dir "$BATS_TEST_TMPDIR/e"
  [ "$status" -eq 2 ]
}

@test "script requires --seed" {
  run bash "$SCRIPT" --model x --output-dir "$BATS_TEST_TMPDIR/e"
  [ "$status" -eq 2 ]
}

@test "script requires --output-dir" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  make_seed "$seed"
  run bash "$SCRIPT" --model x --seed "$seed"
  [ "$status" -eq 2 ]
}

@test "script rejects nonexistent seed file" {
  run bash "$SCRIPT" --model x --seed /nope.jsonl --output-dir /tmp/e
  [ "$status" -eq 2 ]
}

@test "script rejects non-integer sample size" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  make_seed "$seed"
  run bash "$SCRIPT" --model x --seed "$seed" --output-dir "$BATS_TEST_TMPDIR/e" --sample-size abc
  [ "$status" -eq 2 ]
}

@test "script rejects unknown benchmark" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  make_seed "$seed"
  run bash "$SCRIPT" --model x --seed "$seed" --output-dir "$BATS_TEST_TMPDIR/e" --benchmarks nonsense-bench
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown benchmark"* ]]
}

# ── Config emission ─────────────────────────────────────────────────────────

@test "generates eval-config.yaml in output-dir" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local outdir="$BATS_TEST_TMPDIR/eval"
  make_seed "$seed"
  run bash "$SCRIPT" --model test:v1 --seed "$seed" --output-dir "$outdir"
  [ "$status" -eq 0 ]
  [[ -f "$outdir/eval-config.yaml" ]]
}

@test "generates prompts.jsonl in output-dir" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local outdir="$BATS_TEST_TMPDIR/eval"
  make_seed "$seed"
  run bash "$SCRIPT" --model test:v1 --seed "$seed" --output-dir "$outdir"
  [ "$status" -eq 0 ]
  [[ -f "$outdir/prompts.jsonl" ]]
}

@test "eval-config.yaml contains model name" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local outdir="$BATS_TEST_TMPDIR/eval"
  make_seed "$seed"
  bash "$SCRIPT" --model savia-context:v1 --seed "$seed" --output-dir "$outdir" >/dev/null 2>&1
  run grep -c 'savia-context:v1' "$outdir/eval-config.yaml"
  [[ "$output" -ge 1 ]]
}

@test "eval-config.yaml declares sovereignty zero_egress" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local outdir="$BATS_TEST_TMPDIR/eval"
  make_seed "$seed"
  bash "$SCRIPT" --model test --seed "$seed" --output-dir "$outdir" >/dev/null 2>&1
  run grep -c 'zero_egress: true' "$outdir/eval-config.yaml"
  [[ "$output" -ge 1 ]]
}

@test "default benchmarks include persona-match and pii-leak" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local outdir="$BATS_TEST_TMPDIR/eval"
  make_seed "$seed"
  bash "$SCRIPT" --model test --seed "$seed" --output-dir "$outdir" >/dev/null 2>&1
  run grep -c 'persona-match' "$outdir/eval-config.yaml"
  [[ "$output" -ge 1 ]]
  run grep -c 'pii-leak' "$outdir/eval-config.yaml"
  [[ "$output" -ge 1 ]]
}

@test "custom benchmark list emits only selected" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local outdir="$BATS_TEST_TMPDIR/eval"
  make_seed "$seed"
  bash "$SCRIPT" --model test --seed "$seed" --output-dir "$outdir" --benchmarks latency >/dev/null 2>&1
  run grep -c 'name: "latency"' "$outdir/eval-config.yaml"
  [[ "$output" -ge 1 ]]
  run grep -c 'name: "persona-match"' "$outdir/eval-config.yaml"
  [[ "$output" -eq 0 ]]
}

# ── Prompts sampling ────────────────────────────────────────────────────────

@test "prompts.jsonl contains expected number of lines" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local outdir="$BATS_TEST_TMPDIR/eval"
  make_seed "$seed"
  bash "$SCRIPT" --model test --seed "$seed" --output-dir "$outdir" --sample-size 2 >/dev/null 2>&1
  local lines
  lines=$(wc -l < "$outdir/prompts.jsonl")
  [[ "$lines" -eq 2 ]]
}

@test "prompts.jsonl normalizes to prompt/expected keys" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local outdir="$BATS_TEST_TMPDIR/eval"
  make_seed "$seed"
  bash "$SCRIPT" --model test --seed "$seed" --output-dir "$outdir" >/dev/null 2>&1
  run grep -c '"prompt":' "$outdir/prompts.jsonl"
  [[ "$output" -ge 1 ]]
  run grep -c '"expected":' "$outdir/prompts.jsonl"
  [[ "$output" -ge 1 ]]
}

@test "prompts sampling is deterministic with seed=42" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local out1="$BATS_TEST_TMPDIR/e1" out2="$BATS_TEST_TMPDIR/e2"
  # Larger seed so sampling actually selects.
  cat > "$seed" <<'EOF'
{"instruction":"A","output":"a"}
{"instruction":"B","output":"b"}
{"instruction":"C","output":"c"}
{"instruction":"D","output":"d"}
{"instruction":"E","output":"e"}
{"instruction":"F","output":"f"}
EOF
  bash "$SCRIPT" --model test --seed "$seed" --output-dir "$out1" --sample-size 3 >/dev/null 2>&1
  bash "$SCRIPT" --model test --seed "$seed" --output-dir "$out2" --sample-size 3 >/dev/null 2>&1
  local h1 h2
  h1=$(md5sum "$out1/prompts.jsonl" | awk '{print $1}')
  h2=$(md5sum "$out2/prompts.jsonl" | awk '{print $1}')
  [[ "$h1" == "$h2" ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: allowlist includes 7 canonical benchmarks" {
  run grep -c 'coherence\|persona-match\|pii-leak\|radical-honesty\|factual-recall\|latency\|deterministic-first' "$SCRIPT"
  [[ "$output" -ge 7 ]]
}

@test "edge: all 7 benchmarks can be specified together" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local outdir="$BATS_TEST_TMPDIR/eval"
  make_seed "$seed"
  run bash "$SCRIPT" --model test --seed "$seed" --output-dir "$outdir" \
    --benchmarks coherence,persona-match,pii-leak,radical-honesty,factual-recall,latency,deterministic-first
  [ "$status" -eq 0 ]
}

@test "edge: output-dir is created if missing" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local outdir="$BATS_TEST_TMPDIR/new-subdir/eval"
  make_seed "$seed"
  [[ ! -d "$outdir" ]]
  run bash "$SCRIPT" --model test --seed "$seed" --output-dir "$outdir"
  [ "$status" -eq 0 ]
  [[ -d "$outdir" ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify seed file" {
  local seed="$BATS_TEST_TMPDIR/ro-seed.jsonl"
  make_seed "$seed"
  local hash_before
  hash_before=$(md5sum "$seed" | awk '{print $1}')
  bash "$SCRIPT" --model test --seed "$seed" --output-dir "$BATS_TEST_TMPDIR/e" >/dev/null 2>&1
  local hash_after
  hash_after=$(md5sum "$seed" | awk '{print $1}')
  [[ "$hash_before" == "$hash_after" ]]
}

@test "isolation: only writes to --output-dir" {
  local seed="$BATS_TEST_TMPDIR/s.jsonl"
  local outdir="$BATS_TEST_TMPDIR/scoped"
  make_seed "$seed"
  run bash "$SCRIPT" --model test --seed "$seed" --output-dir "$outdir"
  [ "$status" -eq 0 ]
  # Only the 2 expected files exist.
  local n_files
  n_files=$(ls -1 "$outdir" | wc -l)
  [[ "$n_files" -eq 2 ]]
}
