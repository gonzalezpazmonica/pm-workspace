#!/usr/bin/env bats
# BATS tests for scripts/slm-registry.sh (SPEC-SE-027 Model Registry).
# Validates 5 subcommands (register/list/show/promote/deprecate), manifest.json
# persistence, single-deployed invariant, enum methods, slug validation.
#
# Ref: SPEC-SE-027 §Model Registry, docs/rules/domain/slm-training-pipeline.md
# Safety: script under test `set -uo pipefail`.

SCRIPT="scripts/slm-registry.sh"

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
  [[ "$output" == *"register"* ]]
  [[ "$output" == *"list"* ]]
}

@test "rejects no subcommand" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "rejects unknown subcommand" {
  run bash "$SCRIPT" bogus --project "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ]
}

@test "rejects unknown flag" {
  run bash "$SCRIPT" list --bogus
  [ "$status" -eq 2 ]
}

@test "all subcommands require --project" {
  for cmd in register list show promote deprecate; do
    run bash "$SCRIPT" "$cmd"
    [ "$status" -eq 2 ]
  done
}

@test "rejects nonexistent project dir" {
  run bash "$SCRIPT" list --project /does/not/exist
  [ "$status" -eq 2 ]
}

# ── register ────────────────────────────────────────────────────────────────

@test "register creates manifest.json" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  run bash "$SCRIPT" register --project "$p" --id v1 --base-model llama-3.2-1b --method sft
  [ "$status" -eq 0 ]
  [[ -f "$p/registry/manifest.json" ]]
}

@test "register requires --id, --base-model, --method" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  run bash "$SCRIPT" register --project "$p" --base-model x --method sft
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" register --project "$p" --id v1 --method sft
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" register --project "$p" --id v1 --base-model x
  [ "$status" -eq 2 ]
}

@test "register rejects invalid method" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  run bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method notreal
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid --method"* ]]
}

@test "register accepts sft, dpo, grpo methods" {
  for m in sft dpo grpo; do
    local p="$BATS_TEST_TMPDIR/p-$m"
    mkdir -p "$p"
    run bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method "$m"
    [ "$status" -eq 0 ]
  done
}

@test "register rejects invalid id format" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  run bash "$SCRIPT" register --project "$p" --id "BADID" --base-model x --method sft
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" register --project "$p" --id "id with space" --base-model x --method sft
  [ "$status" -eq 2 ]
}

@test "register rejects duplicate id" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  run bash "$SCRIPT" register --project "$p" --id v1 --base-model y --method dpo
  [ "$status" -eq 1 ]
  [[ "$output" == *"already registered"* ]]
}

@test "register default ollama-name is project:id" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  run grep -c '"ollama_name": "p:v1"' "$p/registry/manifest.json"
  [[ "$output" -ge 1 ]]
}

@test "register captures training_tokens, epochs, final_loss" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft \
    --training-tokens 1250000 --epochs 3 --final-loss 0.82 >/dev/null 2>&1
  run grep -c '"training_tokens": 1250000' "$p/registry/manifest.json"
  [[ "$output" -ge 1 ]]
  run grep -c '"final_loss": 0.82' "$p/registry/manifest.json"
  [[ "$output" -ge 1 ]]
}

# ── list ────────────────────────────────────────────────────────────────────

@test "list on empty registry prints message" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  run bash "$SCRIPT" list --project "$p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no registry"* || "$output" == *"no versions"* ]]
}

@test "list shows registered versions in table format" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  bash "$SCRIPT" register --project "$p" --id v2 --base-model y --method dpo >/dev/null 2>&1
  run bash "$SCRIPT" list --project "$p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"v1"* ]]
  [[ "$output" == *"v2"* ]]
  [[ "$output" == *"2 versions"* ]]
}

# ── show ────────────────────────────────────────────────────────────────────

@test "show returns JSON detail for existing version" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model llama --method sft >/dev/null 2>&1
  run bash "$SCRIPT" show --project "$p" --id v1
  [ "$status" -eq 0 ]
  [[ "$output" == *'"id": "v1"'* ]]
  [[ "$output" == *'"base_model": "llama"'* ]]
}

@test "show returns error for nonexistent version" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  run bash "$SCRIPT" show --project "$p" --id notfound
  [ "$status" -eq 1 ]
}

@test "show without --id fails" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  run bash "$SCRIPT" show --project "$p"
  [ "$status" -eq 2 ]
}

# ── promote ─────────────────────────────────────────────────────────────────

@test "promote sets status to deployed" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  run bash "$SCRIPT" promote --project "$p" --id v1
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" show --project "$p" --id v1
  [[ "$output" == *'"status": "deployed"'* ]]
  [[ "$output" == *'"promoted_at":'* ]]
}

@test "promote archives previously deployed version (single-deployed invariant)" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  bash "$SCRIPT" register --project "$p" --id v2 --base-model x --method dpo >/dev/null 2>&1
  bash "$SCRIPT" promote --project "$p" --id v1 >/dev/null 2>&1
  run bash "$SCRIPT" promote --project "$p" --id v2
  [ "$status" -eq 0 ]
  # v1 should be archived now.
  run bash "$SCRIPT" show --project "$p" --id v1
  [[ "$output" == *'"status": "archived"'* ]]
  # v2 should be deployed.
  run bash "$SCRIPT" show --project "$p" --id v2
  [[ "$output" == *'"status": "deployed"'* ]]
}

@test "promote nonexistent version fails" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  run bash "$SCRIPT" promote --project "$p" --id notfound
  [ "$status" -eq 1 ]
}

# ── deprecate ───────────────────────────────────────────────────────────────

@test "deprecate sets status to deprecated" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  run bash "$SCRIPT" deprecate --project "$p" --id v1
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" show --project "$p" --id v1
  [[ "$output" == *'"status": "deprecated"'* ]]
  [[ "$output" == *'"deprecated_at":'* ]]
}

@test "deprecate nonexistent version fails" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  run bash "$SCRIPT" deprecate --project "$p" --id notfound
  [ "$status" -eq 1 ]
}

# ── Manifest structure ──────────────────────────────────────────────────────

@test "manifest.json is valid JSON with expected keys" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  run bash -c 'python3 -c "import json; d=json.load(open(\"'"$p"'/registry/manifest.json\")); assert \"project\" in d; assert \"versions\" in d; assert isinstance(d[\"versions\"], list); print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

@test "manifest captures project name from directory" {
  local p="$BATS_TEST_TMPDIR/my-slm"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  run grep -c '"project": "my-slm"' "$p/registry/manifest.json"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: list does not modify manifest" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  local h_before
  h_before=$(md5sum "$p/registry/manifest.json" | awk '{print $1}')
  bash "$SCRIPT" list --project "$p" >/dev/null 2>&1
  bash "$SCRIPT" show --project "$p" --id v1 >/dev/null 2>&1
  local h_after
  h_after=$(md5sum "$p/registry/manifest.json" | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: writes only inside project/registry/" {
  local p="$BATS_TEST_TMPDIR/p"
  mkdir -p "$p"
  # Pre-existing sibling file untouched.
  echo "x" > "$BATS_TEST_TMPDIR/sibling.txt"
  bash "$SCRIPT" register --project "$p" --id v1 --base-model x --method sft >/dev/null 2>&1
  run cat "$BATS_TEST_TMPDIR/sibling.txt"
  [[ "$output" == "x" ]]
}
