#!/usr/bin/env bats
# BATS tests for scripts/slm-pipeline-validate.sh (SLM meta-validator).
# Validates directory layout checks, config.yaml presence + sections,
# eval/harness.yaml validity, README non-empty, .gitignore privacy guard,
# strict mode, JSON output, isolation.
#
# Ref: docs/rules/domain/slm-training-pipeline.md §3
# Safety: script under test `set -uo pipefail`, read-only.

SCRIPT="scripts/slm-pipeline-validate.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# Helper: build a complete valid SLM project under $1.
build_valid_project() {
  local p="$1"
  mkdir -p "$p/datasets/raw" "$p/datasets/processed" "$p/datasets/synthetic" \
           "$p/adapters" "$p/gguf" "$p/eval/results"
  cat > "$p/config.yaml" <<EOF
model:
  name: "test"
  path: "unsloth/test"
dataset:
  path: "data.jsonl"
training:
  num_train_epochs: 3
sovereignty:
  zero_egress: true
EOF
  cat > "$p/eval/harness.yaml" <<EOF
model:
  name: "test:v1"
benchmarks:
  - name: coherence
EOF
  echo "SLM project README" > "$p/README.md"
  cat > "$p/.gitignore" <<EOF
adapters/
gguf/
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

@test "script references slm-training-pipeline rule" {
  run grep -c 'slm-training-pipeline' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI ────────────────────────────────────────────────────────────────────

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"project"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --project" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent project directory" {
  run bash "$SCRIPT" --project /does/not/exist
  [ "$status" -eq 2 ]
}

# ── Positive ───────────────────────────────────────────────────────────────

@test "valid complete project returns VALID" {
  local p="$BATS_TEST_TMPDIR/good"
  build_valid_project "$p"
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VALID"* ]]
}

@test "valid project JSON has valid:true" {
  local p="$BATS_TEST_TMPDIR/good"
  build_valid_project "$p"
  run bash "$SCRIPT" --project "$p" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"valid":true'* ]]
}

# ── Negative: missing directories ──────────────────────────────────────────

@test "missing datasets/ dir fails" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  rm -rf "$p/datasets"
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 1 ]
  [[ "$output" == *"datasets"* ]]
}

@test "missing eval/ dir fails" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  rm -rf "$p/eval"
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 1 ]
  [[ "$output" == *"eval"* ]]
}

@test "missing adapters/ dir fails" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  rm -rf "$p/adapters"
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 1 ]
}

@test "missing gguf/ dir fails" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  rm -rf "$p/gguf"
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 1 ]
}

# ── Negative: config.yaml ──────────────────────────────────────────────────

@test "missing config.yaml fails" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  rm "$p/config.yaml"
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 1 ]
  [[ "$output" == *"config.yaml"* ]]
}

@test "config.yaml missing 'model:' section fails" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  cat > "$p/config.yaml" <<EOF
dataset:
  path: "x"
training:
  epochs: 1
EOF
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 1 ]
  [[ "$output" == *"model:"* ]]
}

@test "config.yaml missing 'dataset:' section fails" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  cat > "$p/config.yaml" <<EOF
model:
  name: "t"
training:
  epochs: 1
EOF
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 1 ]
  [[ "$output" == *"dataset:"* ]]
}

@test "config.yaml missing 'training:' section fails" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  cat > "$p/config.yaml" <<EOF
model:
  name: "t"
dataset:
  path: "x"
EOF
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 1 ]
  [[ "$output" == *"training:"* ]]
}

# ── Negative: README ────────────────────────────────────────────────────────

@test "missing README.md fails" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  rm "$p/README.md"
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 1 ]
  [[ "$output" == *"README.md"* ]]
}

@test "empty README.md fails" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  : > "$p/README.md"
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 1 ]
  [[ "$output" == *"empty"* ]]
}

# ── Negative: eval/harness.yaml ─────────────────────────────────────────────

@test "eval/harness.yaml missing sections fails" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  echo "foo: bar" > "$p/eval/harness.yaml"
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 1 ]
  [[ "$output" == *"benchmarks:"* || "$output" == *"harness.yaml"* ]]
}

# ── Warnings ────────────────────────────────────────────────────────────────

@test ".gitignore missing adapters/ triggers warning" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  echo "node_modules/" > "$p/.gitignore"
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"adapters"* ]]
  [[ "$output" == *"WARN"* || "$output" == *"leak"* ]]
}

@test "strict mode upgrades gitignore warning to error" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  echo "node_modules/" > "$p/.gitignore"
  run bash "$SCRIPT" --project "$p" --strict
  [ "$status" -eq 1 ]
}

@test "no zero_egress in config triggers sovereignty warning" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  cat > "$p/config.yaml" <<EOF
model:
  name: "t"
dataset:
  path: "x"
training:
  epochs: 1
EOF
  run bash "$SCRIPT" --project "$p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sovereignty"* || "$output" == *"zero_egress"* ]]
}

# ── JSON output ────────────────────────────────────────────────────────────

@test "JSON output parseable with expected keys" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  run bash -c 'bash '"$SCRIPT"' --project '"$p"' --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"valid\" in d; assert \"errors\" in d; assert \"warnings\" in d; print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "JSON output lists errors for invalid project" {
  local p="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$p"
  run bash "$SCRIPT" --project "$p" --json
  [ "$status" -eq 1 ]
  [[ "$output" == *'"valid":false'* ]]
  [[ "$output" == *"missing"* ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify project files" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  local hash_before
  hash_before=$(find "$p" -type f -exec md5sum {} \; | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" --project "$p" >/dev/null 2>&1
  bash "$SCRIPT" --project "$p" --json >/dev/null 2>&1
  bash "$SCRIPT" --project "$p" --strict >/dev/null 2>&1
  local hash_after
  hash_after=$(find "$p" -type f -exec md5sum {} \; | sort | md5sum | awk '{print $1}')
  [[ "$hash_before" == "$hash_after" ]]
}

@test "isolation: exit codes are 0/1/2" {
  local p="$BATS_TEST_TMPDIR/p"
  build_valid_project "$p"
  run bash "$SCRIPT" --project "$p"
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --project "$BATS_TEST_TMPDIR/empty"
  [[ "$status" -eq 1 || "$status" -eq 2 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
