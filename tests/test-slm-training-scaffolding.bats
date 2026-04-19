#!/usr/bin/env bats
# BATS tests for SLM training scaffolding (SPEC-SE-027 / SPEC-080 / SPEC-023).
# Covers slm-dataset-prep.sh (Fase 1) + slm-train-config.sh (Fase 3) +
# rule doc integrity + spec approval frontmatter.
#
# Ref: docs/rules/domain/slm-training-pipeline.md, ROADMAP §Tier 5.25
# Safety: scripts under test `set -uo pipefail`, read-only on filesystem
# except for --output files they write.

PREP="scripts/slm-dataset-prep.sh"
CFG="scripts/slm-train-config.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure / safety (both scripts) ───────────────────────────────────────

@test "slm-dataset-prep exists and is executable" {
  [[ -x "$PREP" ]]
}

@test "slm-train-config exists and is executable" {
  [[ -x "$CFG" ]]
}

@test "slm-dataset-prep uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$PREP"
  [[ "$output" -ge 1 ]]
}

@test "slm-train-config uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$CFG"
  [[ "$output" -ge 1 ]]
}

@test "both scripts pass bash -n syntax check" {
  run bash -n "$PREP"
  [ "$status" -eq 0 ]
  run bash -n "$CFG"
  [ "$status" -eq 0 ]
}

@test "scripts reference SLM pipeline spec docs" {
  run grep -cE 'SPEC-SE-027|SPEC-023|SPEC-080' "$PREP"
  [[ "$output" -ge 1 ]]
  run grep -cE 'SPEC-SE-027|SPEC-080' "$CFG"
  [[ "$output" -ge 1 ]]
}

# ── Rule doc (entry point) ──────────────────────────────────────────────────

@test "slm-training-pipeline.md rule doc exists" {
  [[ -f "docs/rules/domain/slm-training-pipeline.md" ]]
}

@test "rule doc references all 5 core SLM specs" {
  for spec in SPEC-SE-027 SPEC-023 SPEC-080 SE-028 SE-042; do
    run grep -c "$spec" docs/rules/domain/slm-training-pipeline.md
    [[ "$output" -ge 1 ]]
  done
}

@test "rule doc documents the 5-phase pipeline" {
  run grep -cE 'Fase [1-5]|Phase [1-5]' docs/rules/domain/slm-training-pipeline.md
  [[ "$output" -ge 5 ]]
}

# ── Spec approval frontmatter ───────────────────────────────────────────────

@test "SPEC-SE-027 status is APPROVED" {
  run grep -E '^status:' docs/propuestas/savia-enterprise/SPEC-SE-027-slm-training.md
  [[ "$output" == *"APPROVED"* ]]
}

@test "SPEC-023 status is APPROVED" {
  run grep -E '^status:' docs/propuestas/SPEC-023-savia-llm-trainer.md
  [[ "$output" == *"APPROVED"* ]]
}

@test "SPEC-080 status is APPROVED" {
  run grep -E '^status:' docs/propuestas/SPEC-080-custom-llm-training-unsloth.md
  [[ "$output" == *"APPROVED"* ]]
}

@test "SE-028 status is APPROVED" {
  run grep -E '^status:' docs/propuestas/SE-028-oumi-integration.md
  [[ "$output" == *"APPROVED"* ]]
}

@test "SE-042 status is APPROVED" {
  run grep -E '^status:' docs/propuestas/SE-042-savia-voice-training-pipeline.md
  [[ "$output" == *"APPROVED"* ]]
}

# ── slm-dataset-prep CLI ────────────────────────────────────────────────────

@test "slm-dataset-prep --help exits 0" {
  run bash "$PREP" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Alpaca"* || "$output" == *"Unsloth"* ]]
}

@test "slm-dataset-prep rejects unknown arg" {
  run bash "$PREP" --bogus
  [ "$status" -eq 2 ]
}

@test "slm-dataset-prep requires --input" {
  run bash "$PREP"
  [ "$status" -eq 2 ]
}

@test "slm-dataset-prep rejects nonexistent input file" {
  run bash "$PREP" --input /does/not/exist.jsonl --output /tmp/x.jsonl
  [ "$status" -eq 2 ]
}

# ── slm-dataset-prep conversion ─────────────────────────────────────────────

@test "slm-dataset-prep converts chat-format to Alpaca" {
  local in="$BATS_TEST_TMPDIR/chat.jsonl"
  local out="$BATS_TEST_TMPDIR/out.jsonl"
  cat > "$in" <<'EOF'
{"role":"user","content":"What is SPEC-023?"}
{"role":"assistant","content":"Savia LLM Trainer for context brain."}
EOF
  run bash "$PREP" --input "$in" --output "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out" ]]
  run grep -c '"instruction"' "$out"
  [[ "$output" -ge 1 ]]
}

@test "slm-dataset-prep converts Q&A prompt/response format" {
  local in="$BATS_TEST_TMPDIR/qa.jsonl"
  local out="$BATS_TEST_TMPDIR/out.jsonl"
  cat > "$in" <<'EOF'
{"prompt":"Explain SLM","response":"Small Language Model."}
EOF
  run bash "$PREP" --input "$in" --output "$out"
  [ "$status" -eq 0 ]
  run grep -c 'Explain SLM' "$out"
  [[ "$output" -ge 1 ]]
}

@test "slm-dataset-prep passes through Alpaca format unchanged structure" {
  local in="$BATS_TEST_TMPDIR/alp.jsonl"
  local out="$BATS_TEST_TMPDIR/out.jsonl"
  cat > "$in" <<'EOF'
{"instruction":"Name a model","input":"","output":"Qwen2.5-0.5B"}
EOF
  run bash "$PREP" --input "$in" --output "$out"
  [ "$status" -eq 0 ]
  run grep -c 'Qwen2.5-0.5B' "$out"
  [[ "$output" -ge 1 ]]
}

@test "slm-dataset-prep --pii-scrub redacts emails" {
  local in="$BATS_TEST_TMPDIR/pii.jsonl"
  local out="$BATS_TEST_TMPDIR/out.jsonl"
  cat > "$in" <<'EOF'
{"prompt":"Email me at user@example.com","response":"OK."}
EOF
  run bash "$PREP" --input "$in" --output "$out" --pii-scrub
  [ "$status" -eq 0 ]
  run grep -c '\[EMAIL\]' "$out"
  [[ "$output" -ge 1 ]]
  run grep -c 'user@example.com' "$out"
  [[ "$output" -eq 0 ]]
}

@test "slm-dataset-prep --dry-run does not write output" {
  local in="$BATS_TEST_TMPDIR/d.jsonl"
  cat > "$in" <<'EOF'
{"prompt":"x","response":"y"}
EOF
  run bash "$PREP" --input "$in" --dry-run
  [ "$status" -eq 0 ]
}

# ── slm-train-config CLI ────────────────────────────────────────────────────

@test "slm-train-config --help exits 0" {
  run bash "$CFG" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"model"* ]]
  [[ "$output" == *"dataset"* ]]
}

@test "slm-train-config rejects unknown arg" {
  run bash "$CFG" --bogus
  [ "$status" -eq 2 ]
}

@test "slm-train-config requires --model, --dataset, --output" {
  run bash "$CFG"
  [ "$status" -eq 2 ]
}

@test "slm-train-config rejects invalid model" {
  run bash "$CFG" --model not-a-model --dataset /tmp/d --output "$BATS_TEST_TMPDIR/c.yaml"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid"* ]]
}

@test "slm-train-config rejects non-integer epochs" {
  run bash "$CFG" --model llama-3.2-1b --dataset /tmp/d --output "$BATS_TEST_TMPDIR/c.yaml" --epochs not-a-number
  [ "$status" -eq 2 ]
}

# ── slm-train-config YAML emission ──────────────────────────────────────────

@test "slm-train-config emits valid YAML with expected sections" {
  local out="$BATS_TEST_TMPDIR/c.yaml"
  run bash "$CFG" --model llama-3.2-1b --dataset /data.jsonl --output "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out" ]]
  run grep -c '^model:' "$out"
  [[ "$output" -ge 1 ]]
  run grep -c '^lora:' "$out"
  [[ "$output" -ge 1 ]]
  run grep -c '^training:' "$out"
  [[ "$output" -ge 1 ]]
  run grep -c '^sovereignty:' "$out"
  [[ "$output" -ge 1 ]]
}

@test "slm-train-config embeds model name and path in YAML" {
  local out="$BATS_TEST_TMPDIR/c.yaml"
  run bash "$CFG" --model qwen2.5-0.5b --dataset /data.jsonl --output "$out"
  [ "$status" -eq 0 ]
  run grep -c 'qwen2.5-0.5b' "$out"
  [[ "$output" -ge 1 ]]
  run grep -c 'unsloth/Qwen2.5-0.5B' "$out"
  [[ "$output" -ge 1 ]]
}

@test "slm-train-config respects custom LoRA params" {
  local out="$BATS_TEST_TMPDIR/c.yaml"
  run bash "$CFG" --model llama-3.2-1b --dataset /d --output "$out" --lora-r 32 --lora-alpha 64
  [ "$status" -eq 0 ]
  run grep -c '^  r: 32' "$out"
  [[ "$output" -ge 1 ]]
  run grep -c '^  alpha: 64' "$out"
  [[ "$output" -ge 1 ]]
}

@test "slm-train-config sovereignty block declares zero_egress" {
  local out="$BATS_TEST_TMPDIR/c.yaml"
  run bash "$CFG" --model llama-3.2-1b --dataset /d --output "$out"
  [ "$status" -eq 0 ]
  run grep -c 'zero_egress: true' "$out"
  [[ "$output" -ge 1 ]]
}

@test "slm-train-config supports all 5 allowed models" {
  for m in llama-3.2-1b llama-3.2-3b qwen2.5-0.5b qwen2.5-3b phi-3.5-mini; do
    local out="$BATS_TEST_TMPDIR/c-$m.yaml"
    run bash "$CFG" --model "$m" --dataset /d --output "$out"
    [ "$status" -eq 0 ]
  done
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: slm-dataset-prep does not modify input file" {
  local in="$BATS_TEST_TMPDIR/ro.jsonl"
  cat > "$in" <<'EOF'
{"prompt":"hi","response":"hello"}
EOF
  local out="$BATS_TEST_TMPDIR/out.jsonl"
  local hash_before
  hash_before=$(md5sum "$in" | awk '{print $1}')
  bash "$PREP" --input "$in" --output "$out" >/dev/null 2>&1
  local hash_after
  hash_after=$(md5sum "$in" | awk '{print $1}')
  [[ "$hash_before" == "$hash_after" ]]
}

@test "isolation: slm-train-config only writes to --output path" {
  local out="$BATS_TEST_TMPDIR/c.yaml"
  # Precondition: output doesn't exist.
  [[ ! -f "$out" ]]
  run bash "$CFG" --model llama-3.2-1b --dataset /d --output "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out" ]]
}
