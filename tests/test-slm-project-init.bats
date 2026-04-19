#!/usr/bin/env bats
# BATS tests for scripts/slm-project-init.sh (SLM project bootstrapper).
# Validates directory scaffolding, config.yaml generation, .gitignore privacy,
# README generation, CLI surface, overwrite protection, isolation.
#
# Ref: SPEC-SE-027, docs/rules/domain/slm-training-pipeline.md §3
# Safety: script under test `set -uo pipefail`, creates files only under --root/--name.

SCRIPT="scripts/slm-project-init.sh"

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

# ── CLI ────────────────────────────────────────────────────────────────────

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"name"* ]]
  [[ "$output" == *"model"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --name" {
  run bash "$SCRIPT" --model x --root "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ]
}

@test "requires --model" {
  run bash "$SCRIPT" --name x --root "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ]
}

@test "requires --root" {
  run bash "$SCRIPT" --name x --model y
  [ "$status" -eq 2 ]
}

@test "rejects invalid name (uppercase)" {
  run bash "$SCRIPT" --name BADNAME --model x --root "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ]
}

@test "rejects invalid name (spaces)" {
  run bash "$SCRIPT" --name "bad name" --model x --root "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent root" {
  run bash "$SCRIPT" --name test --model x --root /does/not/exist
  [ "$status" -eq 2 ]
}

# ── Scaffolding ─────────────────────────────────────────────────────────────

@test "creates project directory tree" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  run bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root"
  [ "$status" -eq 0 ]
  [[ -d "$root/proj/datasets/raw" ]]
  [[ -d "$root/proj/datasets/processed" ]]
  [[ -d "$root/proj/datasets/synthetic" ]]
  [[ -d "$root/proj/adapters" ]]
  [[ -d "$root/proj/gguf" ]]
  [[ -d "$root/proj/eval/results" ]]
}

@test "creates config.yaml with model section" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  run bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root"
  [ "$status" -eq 0 ]
  [[ -f "$root/proj/config.yaml" ]]
  run grep -c '^model:' "$root/proj/config.yaml"
  [[ "$output" -ge 1 ]]
}

@test "config.yaml references the model name" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  bash "$SCRIPT" --name proj --model qwen2.5-0.5b --root "$root" >/dev/null 2>&1
  run grep -c 'qwen2.5-0.5b' "$root/proj/config.yaml"
  [[ "$output" -ge 1 ]]
}

@test "creates README.md with project name" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  bash "$SCRIPT" --name my-slm --model llama-3.2-1b --root "$root" >/dev/null 2>&1
  [[ -f "$root/my-slm/README.md" ]]
  run grep -c 'my-slm' "$root/my-slm/README.md"
  [[ "$output" -ge 1 ]]
}

@test "README documents the 5-phase pipeline" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root" >/dev/null 2>&1
  run grep -cE '### [1-5]\.' "$root/proj/README.md"
  [[ "$output" -ge 5 ]]
}

@test "creates eval/harness.yaml stub" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root" >/dev/null 2>&1
  [[ -f "$root/proj/eval/harness.yaml" ]]
  run grep -c 'benchmarks:' "$root/proj/eval/harness.yaml"
  [[ "$output" -ge 1 ]]
}

# ── .gitignore privacy ──────────────────────────────────────────────────────

@test "creates .gitignore excluding adapters/" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root" >/dev/null 2>&1
  [[ -f "$root/proj/.gitignore" ]]
  run grep -cE '^adapters/' "$root/proj/.gitignore"
  [[ "$output" -ge 1 ]]
}

@test ".gitignore excludes gguf/" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root" >/dev/null 2>&1
  run grep -cE '^gguf/' "$root/proj/.gitignore"
  [[ "$output" -ge 1 ]]
}

@test ".gitignore excludes checkpoints/" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root" >/dev/null 2>&1
  run grep -cE '^checkpoints/' "$root/proj/.gitignore"
  [[ "$output" -ge 1 ]]
}

# ── .gitkeep tracking ───────────────────────────────────────────────────────

@test "datasets subdirs have .gitkeep for git tracking" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root" >/dev/null 2>&1
  [[ -f "$root/proj/datasets/raw/.gitkeep" ]]
  [[ -f "$root/proj/datasets/processed/.gitkeep" ]]
  [[ -f "$root/proj/datasets/synthetic/.gitkeep" ]]
}

@test "eval/results has .gitkeep" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root" >/dev/null 2>&1
  [[ -f "$root/proj/eval/results/.gitkeep" ]]
}

# ── Overwrite protection ────────────────────────────────────────────────────

@test "refuses to overwrite existing project without --force" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root/proj"
  run bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "--force allows overwrite" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root/proj"
  echo "old" > "$root/proj/README.md"
  run bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root" --force
  [ "$status" -eq 0 ]
  run grep -c 'old' "$root/proj/README.md"
  [[ "$output" -eq 0 ]]
}

# ── Fallback config when train-config unavailable ──────────────────────────

@test "falls back to minimal config when model unknown to train-config" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  run bash "$SCRIPT" --name proj --model custom-model --root "$root"
  [ "$status" -eq 0 ]
  [[ -f "$root/proj/config.yaml" ]]
  run grep -c 'custom-model' "$root/proj/config.yaml"
  [[ "$output" -ge 1 ]]
}

# ── Sovereignty in config ───────────────────────────────────────────────────

@test "generated config declares zero_egress" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root" >/dev/null 2>&1
  run grep -c 'zero_egress' "$root/proj/config.yaml"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: only writes under root/name" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  # Pre-existing sibling file must be untouched.
  echo "untouched" > "$root/sibling.txt"
  bash "$SCRIPT" --name proj --model llama-3.2-1b --root "$root" >/dev/null 2>&1
  run cat "$root/sibling.txt"
  [[ "$output" == "untouched" ]]
}

@test "isolation: exit codes are 0/1/2" {
  local root="$BATS_TEST_TMPDIR/root"
  mkdir -p "$root"
  run bash "$SCRIPT" --name ok --model llama-3.2-1b --root "$root"
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --name ok --model llama-3.2-1b --root "$root"
  [[ "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
