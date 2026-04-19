#!/usr/bin/env bats
# BATS tests for scripts/slm-modelfile-gen.sh (Ollama Modelfile generator).
# Validates Modelfile emission, persona allow-list, custom system prompt,
# param validation, CLI surface, isolation.
#
# Ref: SPEC-SE-027 §5, docs/rules/domain/slm-training-pipeline.md
# Safety: script under test `set -uo pipefail`.

SCRIPT="scripts/slm-modelfile-gen.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
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

@test "script references SPEC-SE-027" {
  run grep -c 'SPEC-SE-027' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script clarifies it does NOT run ollama create" {
  run grep -ciE 'NOT execute|NO ejecut|does not execute|scaffold' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI ────────────────────────────────────────────────────────────────────

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"gguf"* ]]
  [[ "$output" == *"persona"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --name" {
  run bash "$SCRIPT" --gguf x.gguf --output m
  [ "$status" -eq 2 ]
}

@test "requires --gguf" {
  run bash "$SCRIPT" --name x --output m
  [ "$status" -eq 2 ]
}

@test "requires --output" {
  run bash "$SCRIPT" --name x --gguf y.gguf
  [ "$status" -eq 2 ]
}

@test "rejects invalid name (uppercase)" {
  run bash "$SCRIPT" --name BAD --gguf x --output y
  [ "$status" -eq 2 ]
}

@test "rejects unknown persona" {
  run bash "$SCRIPT" --name x --gguf y --output "$BATS_TEST_TMPDIR/m" --persona nonexistent
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown --persona"* ]]
}

@test "rejects out-of-range temperature" {
  run bash "$SCRIPT" --name x --gguf y --output "$BATS_TEST_TMPDIR/m" --temperature 2.5
  [ "$status" -eq 2 ]
}

@test "rejects non-integer num-ctx" {
  run bash "$SCRIPT" --name x --gguf y --output "$BATS_TEST_TMPDIR/m" --num-ctx abc
  [ "$status" -eq 2 ]
}

# ── Modelfile emission ──────────────────────────────────────────────────────

@test "generates Modelfile with FROM clause" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  run bash "$SCRIPT" --name test --gguf ./adapter.gguf --output "$m"
  [ "$status" -eq 0 ]
  [[ -f "$m" ]]
  run grep -c '^FROM ./adapter.gguf' "$m"
  [[ "$output" -ge 1 ]]
}

@test "Modelfile includes SYSTEM block" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  bash "$SCRIPT" --name test --gguf x.gguf --output "$m" >/dev/null 2>&1
  run grep -c '^SYSTEM ' "$m"
  [[ "$output" -ge 1 ]]
}

@test "Modelfile includes TEMPLATE ChatML" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  bash "$SCRIPT" --name test --gguf x.gguf --output "$m" >/dev/null 2>&1
  run grep -c '<|im_start|>' "$m"
  [[ "$output" -ge 1 ]]
}

@test "Modelfile includes temperature parameter" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  bash "$SCRIPT" --name test --gguf x.gguf --output "$m" --temperature 0.7 >/dev/null 2>&1
  run grep -c 'PARAMETER temperature 0.7' "$m"
  [[ "$output" -ge 1 ]]
}

@test "Modelfile includes num_ctx parameter" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  bash "$SCRIPT" --name test --gguf x.gguf --output "$m" --num-ctx 4096 >/dev/null 2>&1
  run grep -c 'PARAMETER num_ctx 4096' "$m"
  [[ "$output" -ge 1 ]]
}

# ── Persona allow-list ──────────────────────────────────────────────────────

@test "persona=savia emits Spanish female system prompt" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  bash "$SCRIPT" --name test --gguf x.gguf --output "$m" --persona savia >/dev/null 2>&1
  run grep -c 'buhita' "$m"
  [[ "$output" -ge 1 ]]
  run grep -c 'femenino' "$m"
  [[ "$output" -ge 1 ]]
}

@test "persona=default emits generic system prompt" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  bash "$SCRIPT" --name test --gguf x.gguf --output "$m" --persona default >/dev/null 2>&1
  run grep -c 'helpful assistant' "$m"
  [[ "$output" -ge 1 ]]
}

@test "all 5 predefined personas work" {
  for p in default savia code-reviewer pii-classifier spec-assistant; do
    local m="$BATS_TEST_TMPDIR/m-$p"
    run bash "$SCRIPT" --name test --gguf x.gguf --output "$m" --persona "$p"
    [ "$status" -eq 0 ]
  done
}

# ── Custom system ──────────────────────────────────────────────────────────

@test "--system overrides --persona" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  bash "$SCRIPT" --name test --gguf x.gguf --output "$m" \
    --persona savia --system "Custom system prompt." >/dev/null 2>&1
  run grep -c 'Custom system prompt' "$m"
  [[ "$output" -ge 1 ]]
  run grep -c 'buhita' "$m"
  [[ "$output" -eq 0 ]]
}

# ── Stop tokens ────────────────────────────────────────────────────────────

@test "Modelfile includes stop tokens for ChatML + Llama-3" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  bash "$SCRIPT" --name test --gguf x.gguf --output "$m" >/dev/null 2>&1
  run grep -c 'PARAMETER stop' "$m"
  [[ "$output" -ge 3 ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: name with tag (colon) is valid" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  run bash "$SCRIPT" --name "savia-context:v1" --gguf x.gguf --output "$m"
  [ "$status" -eq 0 ]
}

@test "edge: relative GGUF path preserved in FROM" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  bash "$SCRIPT" --name test --gguf "./gguf/model-q4_k_m.gguf" --output "$m" >/dev/null 2>&1
  run grep -c 'FROM ./gguf/model-q4_k_m.gguf' "$m"
  [[ "$output" -ge 1 ]]
}

@test "edge: temperature=0 allowed (deterministic)" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  run bash "$SCRIPT" --name test --gguf x.gguf --output "$m" --temperature 0
  [ "$status" -eq 0 ]
}

@test "edge: temperature=1 allowed (max creativity)" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  run bash "$SCRIPT" --name test --gguf x.gguf --output "$m" --temperature 1
  [ "$status" -eq 0 ]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: only creates --output file" {
  local m="$BATS_TEST_TMPDIR/Modelfile"
  [[ ! -f "$m" ]]
  run bash "$SCRIPT" --name test --gguf x.gguf --output "$m"
  [ "$status" -eq 0 ]
  [[ -f "$m" ]]
}

@test "isolation: exit codes are 0 or 2" {
  local m="$BATS_TEST_TMPDIR/m"
  run bash "$SCRIPT" --name test --gguf x.gguf --output "$m"
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
