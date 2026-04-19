#!/usr/bin/env bats
# BATS tests for scripts/slm-synth-recipe.sh (SE-028 Slice 1).
# Validates oumi synth recipe YAML emission, strategy allow-list,
# sovereignty declaration, CLI surface, negatives, isolation.
#
# Ref: SE-028, docs/rules/domain/slm-training-pipeline.md §Fase 2
# Safety: script under test `set -uo pipefail`, read-only.

SCRIPT="scripts/slm-synth-recipe.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

make_input() {
  echo "placeholder corpus text" > "$1"
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

@test "script references SE-028" {
  run grep -c 'SE-028' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script clarifies it does NOT execute oumi" {
  run grep -ciE 'NOT execute|NO ejecut|does not execute|scaffolding' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI ────────────────────────────────────────────────────────────────────

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"strategy"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --strategy" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  run bash "$SCRIPT" --input "$in" --output /tmp/x.yaml
  [ "$status" -eq 2 ]
}

@test "requires --input" {
  run bash "$SCRIPT" --strategy qa-pairs --output /tmp/x.yaml
  [ "$status" -eq 2 ]
}

@test "requires --output" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  run bash "$SCRIPT" --strategy qa-pairs --input "$in"
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent input file" {
  run bash "$SCRIPT" --strategy qa-pairs --input /nope.md --output /tmp/x.yaml
  [ "$status" -eq 2 ]
}

@test "rejects invalid strategy" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  run bash "$SCRIPT" --strategy invalid-strat --input "$in" --output "$BATS_TEST_TMPDIR/r.yaml"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid --strategy"* ]]
}

@test "rejects non-integer target-samples" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  run bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$BATS_TEST_TMPDIR/r.yaml" --target-samples abc
  [ "$status" -eq 2 ]
}

@test "rejects invalid judge-model" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  run bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$BATS_TEST_TMPDIR/r.yaml" --judge-model gpt-nonsense
  [ "$status" -eq 2 ]
}

# ── Strategy emission ───────────────────────────────────────────────────────

@test "qa-pairs strategy emits recipe with corpus format" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  run bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$out"
  [ "$status" -eq 0 ]
  run grep -c 'strategy: "qa-pairs"' "$out"
  [[ "$output" -ge 1 ]]
  run grep -c 'chunk_size_tokens' "$out"
  [[ "$output" -ge 1 ]]
}

@test "paraphrase strategy emits recipe with jsonl format" {
  local in="$BATS_TEST_TMPDIR/in.jsonl"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  run bash "$SCRIPT" --strategy paraphrase --input "$in" --output "$out"
  [ "$status" -eq 0 ]
  run grep -c 'strategy: "paraphrase"' "$out"
  [[ "$output" -ge 1 ]]
  run grep -c 'paraphrase_variants' "$out"
  [[ "$output" -ge 1 ]]
}

@test "code-explain strategy emits recipe with extensions" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  run bash "$SCRIPT" --strategy code-explain --input "$in" --output "$out"
  [ "$status" -eq 0 ]
  run grep -c 'extensions:' "$out"
  [[ "$output" -ge 1 ]]
}

@test "distillation strategy includes teacher_model" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  run bash "$SCRIPT" --strategy distillation --input "$in" --output "$out" --judge-model claude-sonnet-4-6
  [ "$status" -eq 0 ]
  run grep -c 'teacher_model' "$out"
  [[ "$output" -ge 1 ]]
}

@test "self-instruct strategy includes seed_tasks_count" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  run bash "$SCRIPT" --strategy self-instruct --input "$in" --output "$out"
  [ "$status" -eq 0 ]
  run grep -c 'seed_tasks_count' "$out"
  [[ "$output" -ge 1 ]]
}

# ── Sovereignty ─────────────────────────────────────────────────────────────

@test "judge=local declares zero_egress true" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  run bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$out" --judge-model local
  [ "$status" -eq 0 ]
  run grep -c 'zero_egress: true' "$out"
  [[ "$output" -ge 1 ]]
  run grep -c 'judge_location: "local"' "$out"
  [[ "$output" -ge 1 ]]
}

@test "judge=claude declares zero_egress false (cloud-api)" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  run bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$out" --judge-model claude-haiku-4-5
  [ "$status" -eq 0 ]
  run grep -c 'zero_egress: false' "$out"
  [[ "$output" -ge 1 ]]
  run grep -c 'cloud-api' "$out"
  [[ "$output" -ge 1 ]]
}

@test "ollama judge maps to zero_egress true" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  run bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$out" --judge-model ollama-qwen-2.5
  [ "$status" -eq 0 ]
  run grep -c 'zero_egress: true' "$out"
  [[ "$output" -ge 1 ]]
}

# ── Safety / quality ───────────────────────────────────────────────────────

@test "recipe includes pii_filter true" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$out" >/dev/null 2>&1
  run grep -c 'pii_filter: true' "$out"
  [[ "$output" -ge 1 ]]
}

@test "recipe includes dedup configuration" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$out" >/dev/null 2>&1
  run grep -c 'dedup: true' "$out"
  [[ "$output" -ge 1 ]]
  run grep -c 'dedup_similarity_threshold' "$out"
  [[ "$output" -ge 1 ]]
}

@test "recipe includes rubric with no_pii check" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$out" >/dev/null 2>&1
  run grep -c 'no_pii' "$out"
  [[ "$output" -ge 1 ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: custom target-samples reflected in YAML" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$out" --target-samples 2500 >/dev/null 2>&1
  run grep -c 'target_samples: 2500' "$out"
  [[ "$output" -ge 1 ]]
}

@test "edge: all 5 strategies are supported" {
  for s in qa-pairs paraphrase code-explain distillation self-instruct; do
    local in="$BATS_TEST_TMPDIR/in-$s.md"
    make_input "$in"
    local out="$BATS_TEST_TMPDIR/r-$s.yaml"
    run bash "$SCRIPT" --strategy "$s" --input "$in" --output "$out"
    [ "$status" -eq 0 ]
  done
}

@test "edge: output path is derived for synthesized jsonl" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/r.yaml"
  bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$out" >/dev/null 2>&1
  run grep -c 'synthesized.jsonl' "$out"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify input file" {
  local in="$BATS_TEST_TMPDIR/ro.md"
  make_input "$in"
  local hash_before
  hash_before=$(md5sum "$in" | awk '{print $1}')
  bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$BATS_TEST_TMPDIR/r.yaml" >/dev/null 2>&1
  local hash_after
  hash_after=$(md5sum "$in" | awk '{print $1}')
  [[ "$hash_before" == "$hash_after" ]]
}

@test "isolation: script only creates --output file" {
  local in="$BATS_TEST_TMPDIR/in.md"
  make_input "$in"
  local out="$BATS_TEST_TMPDIR/scoped-out.yaml"
  [[ ! -f "$out" ]]
  run bash "$SCRIPT" --strategy qa-pairs --input "$in" --output "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out" ]]
}
