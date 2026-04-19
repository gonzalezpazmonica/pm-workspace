#!/usr/bin/env bats
# BATS tests for scripts/slm-export-gguf.sh (llama.cpp conversion recipe).
# Validates export.sh generation, manifest.json, quant allow-list, CLI surface.
#
# Ref: SPEC-SE-027 §Export, docs/rules/domain/slm-training-pipeline.md §Fase 5
# Safety: script under test `set -uo pipefail`.

SCRIPT="scripts/slm-export-gguf.sh"

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

@test "script references SPEC-SE-027 Fase 5" {
  run grep -c 'SPEC-SE-027' "$SCRIPT"
  [[ "$output" -ge 1 ]]
  run grep -cE 'Fase 5|Phase 5|Export' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script clarifies it does NOT execute llama.cpp" {
  run grep -ciE 'NOT execute|NO ejecut|does not execute|recipe only' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI ────────────────────────────────────────────────────────────────────

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"base"* ]]
  [[ "$output" == *"adapter"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --base" {
  run bash "$SCRIPT" --adapter ./a --output-dir "$BATS_TEST_TMPDIR/o"
  [ "$status" -eq 2 ]
}

@test "requires --adapter" {
  run bash "$SCRIPT" --base x --output-dir "$BATS_TEST_TMPDIR/o"
  [ "$status" -eq 2 ]
}

@test "requires --output-dir" {
  run bash "$SCRIPT" --base x --adapter ./a
  [ "$status" -eq 2 ]
}

@test "rejects invalid quantization" {
  run bash "$SCRIPT" --base x --adapter ./a --output-dir "$BATS_TEST_TMPDIR/o" --quantization bad
  [ "$status" -eq 2 ]
}

@test "rejects invalid name" {
  run bash "$SCRIPT" --base x --adapter ./a --output-dir "$BATS_TEST_TMPDIR/o" --name "bad name with spaces"
  [ "$status" -eq 2 ]
}

# ── Emission ───────────────────────────────────────────────────────────────

@test "generates export.sh in output-dir" {
  local out="$BATS_TEST_TMPDIR/out"
  run bash "$SCRIPT" --base llama-3.2-1b --adapter ./adapters/a --output-dir "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out/export.sh" ]]
  [[ -x "$out/export.sh" ]]
}

@test "generates export-manifest.json" {
  local out="$BATS_TEST_TMPDIR/out"
  run bash "$SCRIPT" --base llama-3.2-1b --adapter ./adapters/a --output-dir "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out/export-manifest.json" ]]
}

@test "export.sh passes bash -n syntax check" {
  local out="$BATS_TEST_TMPDIR/out"
  bash "$SCRIPT" --base llama-3.2-1b --adapter ./adapters/a --output-dir "$out" >/dev/null 2>&1
  run bash -n "$out/export.sh"
  [ "$status" -eq 0 ]
}

@test "export.sh includes 3 steps (merge, quantize, checksum)" {
  local out="$BATS_TEST_TMPDIR/out"
  bash "$SCRIPT" --base llama-3.2-1b --adapter ./adapters/a --output-dir "$out" >/dev/null 2>&1
  run grep -cE 'Step|\[1/3\]|\[2/3\]|\[3/3\]' "$out/export.sh"
  [[ "$output" -ge 3 ]]
}

@test "export.sh references convert_lora_to_gguf.py" {
  local out="$BATS_TEST_TMPDIR/out"
  bash "$SCRIPT" --base llama-3.2-1b --adapter ./adapters/a --output-dir "$out" >/dev/null 2>&1
  run grep -c 'convert_lora_to_gguf' "$out/export.sh"
  [[ "$output" -ge 1 ]]
}

@test "export.sh references llama-quantize" {
  local out="$BATS_TEST_TMPDIR/out"
  bash "$SCRIPT" --base llama-3.2-1b --adapter ./adapters/a --output-dir "$out" >/dev/null 2>&1
  run grep -c 'llama-quantize' "$out/export.sh"
  [[ "$output" -ge 1 ]]
}

# ── Manifest content ────────────────────────────────────────────────────────

@test "manifest is valid JSON" {
  local out="$BATS_TEST_TMPDIR/out"
  bash "$SCRIPT" --base llama-3.2-1b --adapter ./a --output-dir "$out" >/dev/null 2>&1
  run bash -c 'python3 -c "import json; json.load(open(\"'"$out"'/export-manifest.json\"))" && echo ok'
  [[ "$output" == *"ok"* ]]
}

@test "manifest includes base, adapter, quantization" {
  local out="$BATS_TEST_TMPDIR/out"
  bash "$SCRIPT" --base llama-3.2-1b --adapter ./adapters/foo --output-dir "$out" --quantization q5_k_m >/dev/null 2>&1
  run grep -c 'llama-3.2-1b' "$out/export-manifest.json"
  [[ "$output" -ge 1 ]]
  run grep -c 'adapters/foo' "$out/export-manifest.json"
  [[ "$output" -ge 1 ]]
  run grep -c 'q5_k_m' "$out/export-manifest.json"
  [[ "$output" -ge 1 ]]
}

@test "manifest declares prerequisites list" {
  local out="$BATS_TEST_TMPDIR/out"
  bash "$SCRIPT" --base x --adapter ./a --output-dir "$out" >/dev/null 2>&1
  run grep -c 'prerequisites' "$out/export-manifest.json"
  [[ "$output" -ge 1 ]]
  run grep -c 'llama.cpp' "$out/export-manifest.json"
  [[ "$output" -ge 1 ]]
}

# ── Quantization ───────────────────────────────────────────────────────────

@test "all canonical quantizations accepted" {
  for q in q4_k_m q5_k_m q8_0 f16; do
    local out="$BATS_TEST_TMPDIR/out-$q"
    run bash "$SCRIPT" --base x --adapter ./a --output-dir "$out" --quantization "$q"
    [ "$status" -eq 0 ]
  done
}

@test "default quantization is q4_k_m" {
  local out="$BATS_TEST_TMPDIR/out"
  bash "$SCRIPT" --base x --adapter ./a --output-dir "$out" >/dev/null 2>&1
  run grep -c 'q4_k_m' "$out/export-manifest.json"
  [[ "$output" -ge 1 ]]
}

# ── Name derivation ────────────────────────────────────────────────────────

@test "default name derives from base" {
  local out="$BATS_TEST_TMPDIR/out"
  bash "$SCRIPT" --base llama-3.2-1b --adapter ./a --output-dir "$out" >/dev/null 2>&1
  run grep -c 'llama-3.2-1b-finetuned' "$out/export-manifest.json"
  [[ "$output" -ge 1 ]]
}

@test "custom --name overrides default" {
  local out="$BATS_TEST_TMPDIR/out"
  bash "$SCRIPT" --base x --adapter ./a --output-dir "$out" --name my-custom-slm >/dev/null 2>&1
  run grep -c 'my-custom-slm' "$out/export-manifest.json"
  [[ "$output" -ge 1 ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: output-dir is created if missing" {
  local out="$BATS_TEST_TMPDIR/new/nested/dir"
  [[ ! -d "$out" ]]
  run bash "$SCRIPT" --base x --adapter ./a --output-dir "$out"
  [ "$status" -eq 0 ]
  [[ -d "$out" ]]
}

@test "edge: export.sh has set -euo pipefail" {
  local out="$BATS_TEST_TMPDIR/out"
  bash "$SCRIPT" --base x --adapter ./a --output-dir "$out" >/dev/null 2>&1
  run grep -c 'set -euo pipefail' "$out/export.sh"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: only writes inside output-dir" {
  local out="$BATS_TEST_TMPDIR/scoped"
  echo "untouched" > "$BATS_TEST_TMPDIR/sibling.txt"
  run bash "$SCRIPT" --base x --adapter ./a --output-dir "$out"
  [ "$status" -eq 0 ]
  run cat "$BATS_TEST_TMPDIR/sibling.txt"
  [[ "$output" == "untouched" ]]
}

@test "isolation: exit codes are 0 or 2" {
  local out="$BATS_TEST_TMPDIR/out"
  run bash "$SCRIPT" --base x --adapter ./a --output-dir "$out"
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
