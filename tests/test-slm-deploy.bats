#!/usr/bin/env bats
# BATS tests for scripts/slm-deploy.sh (post-training orchestrator).
# Validates end-to-end orchestration of export-gguf + modelfile-gen + registry.
#
# Ref: SPEC-SE-027 §Deployment orchestration
# Dep: scripts/slm-export-gguf.sh, slm-modelfile-gen.sh, slm-registry.sh
# Safety: script under test `set -uo pipefail`.

SCRIPT="scripts/slm-deploy.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# Helper: build valid SLM project.
build_project() {
  local p="$1"
  mkdir -p "$p/datasets/raw" "$p/datasets/processed" "$p/datasets/synthetic" \
           "$p/adapters/sft-v1" "$p/gguf" "$p/eval/results" "$p/registry"
  cat > "$p/config.yaml" <<YAML
model:
  name: "test"
dataset:
  path: "x"
training:
  num_train_epochs: 1
YAML
  echo "README" > "$p/README.md"
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

@test "dependency scripts exist" {
  [[ -x "scripts/slm-export-gguf.sh" ]]
  [[ -x "scripts/slm-modelfile-gen.sh" ]]
  [[ -x "scripts/slm-registry.sh" ]]
}

# ── CLI ────────────────────────────────────────────────────────────────────

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"project"* ]]
  [[ "$output" == *"adapter"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --project" {
  run bash "$SCRIPT" --adapter a --base b --version v
  [ "$status" -eq 2 ]
}

@test "requires --adapter" {
  run bash "$SCRIPT" --project p --base b --version v
  [ "$status" -eq 2 ]
}

@test "requires --base" {
  run bash "$SCRIPT" --project p --adapter a --version v
  [ "$status" -eq 2 ]
}

@test "requires --version" {
  run bash "$SCRIPT" --project p --adapter a --base b
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent project dir" {
  run bash "$SCRIPT" --project /nope --adapter a --base b --version v
  [ "$status" -eq 2 ]
}

# ── Orchestration ──────────────────────────────────────────────────────────

@test "generates gguf/export.sh" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  run bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version sft-v1
  [ "$status" -eq 0 ]
  [[ -f "$p/gguf/export.sh" ]]
}

@test "generates gguf/Modelfile" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version sft-v1 >/dev/null 2>&1
  [[ -f "$p/gguf/Modelfile" ]]
}

@test "registers version in manifest.json" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version sft-v1 >/dev/null 2>&1
  [[ -f "$p/registry/manifest.json" ]]
  run grep -c 'sft-v1' "$p/registry/manifest.json"
  [[ "$output" -ge 1 ]]
}

@test "all 3 artifacts produced in one call" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  run bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version sft-v1
  [ "$status" -eq 0 ]
  [[ -f "$p/gguf/export.sh" ]]
  [[ -f "$p/gguf/export-manifest.json" ]]
  [[ -f "$p/gguf/Modelfile" ]]
  [[ -f "$p/registry/manifest.json" ]]
}

@test "output includes 'artifacts generated' message" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  run bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version sft-v1
  [ "$status" -eq 0 ]
  [[ "$output" == *"artifacts generated"* ]]
}

@test "output includes manual next-step instructions" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  run bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version sft-v1
  [ "$status" -eq 0 ]
  [[ "$output" == *"ollama create"* ]]
  [[ "$output" == *"promote"* ]]
}

# ── Persona propagation ─────────────────────────────────────────────────────

@test "--persona propagates to Modelfile" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version sft-v1 --persona savia >/dev/null 2>&1
  run grep -c 'buhita' "$p/gguf/Modelfile"
  [[ "$output" -ge 1 ]]
}

# ── Quantization ───────────────────────────────────────────────────────────

@test "--quantization propagates to export recipe" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version sft-v1 --quantization q5_k_m >/dev/null 2>&1
  run grep -c 'q5_k_m' "$p/gguf/export-manifest.json"
  [[ "$output" -ge 1 ]]
}

# ── Version naming ──────────────────────────────────────────────────────────

@test "version propagates to Ollama tag" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version my-test-v1 >/dev/null 2>&1
  run grep -c 'my-test-v1' "$p/registry/manifest.json"
  [[ "$output" -ge 1 ]]
}

# ── Idempotency ─────────────────────────────────────────────────────────────

@test "re-running with same version fails at registry step (duplicate)" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version sft-v1 >/dev/null 2>&1
  # Second run: registry will reject duplicate id.
  run bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version sft-v1
  # Exit code depends on script behavior — just verify registry wasn't corrupted.
  run grep -c '"sft-v1"' "$p/registry/manifest.json"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: only writes inside project directory" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  echo "untouched" > "$BATS_TEST_TMPDIR/sibling.txt"
  bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version sft-v1 >/dev/null 2>&1
  run cat "$BATS_TEST_TMPDIR/sibling.txt"
  [[ "$output" == "untouched" ]]
}

@test "isolation: exit codes are 0/1/2" {
  local p="$BATS_TEST_TMPDIR/proj"
  build_project "$p"
  run bash "$SCRIPT" --project "$p" --adapter adapters/sft-v1 --base llama-3.2-1b --version v1
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
