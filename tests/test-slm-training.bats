#!/usr/bin/env bats
# BATS tests for SE-027 SLM Training Pipeline
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-027-slm-training.md
# SCRIPT: scripts/slm-data-prep.sh, scripts/slm-train.sh
# Quality gate: SPEC-055 (audit score >=80)
# Safety: tests use BATS run/status guards; target scripts have set -uo pipefail
# Status: active
# Date: 2026-04-12
# Era: 231
# Problem: SLMs trained on generic data lack project domain knowledge
# Solution: local fine-tuning pipeline with zero data egress
# Acceptance: data prep works, PII sanitized, train check runs, forget cleans up
# Dependencies: slm-data-prep.sh, slm-train.sh

## Problem: generic local models lack project domain knowledge for sovereign inference
## Solution: pipeline to prepare project data, fine-tune SLMs locally, deploy to Ollama
## Acceptance: collect, format, validate, split work; PII sanitized; check runs; forget cleans

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PREP_SCRIPT="$REPO_ROOT/scripts/slm-data-prep.sh"
  export TRAIN_SCRIPT="$REPO_ROOT/scripts/slm-train.sh"
  export SPEC="$REPO_ROOT/docs/propuestas/savia-enterprise/SPEC-SE-027-slm-training.md"
  TMPDIR_SLM=$(mktemp -d)
  export CLAUDE_PROJECT_DIR="$TMPDIR_SLM"
  export HOME_ORIG="$HOME"
  export HOME="$TMPDIR_SLM/fakehome"
  mkdir -p "$HOME/.savia"
  # Create a fake project
  mkdir -p "$TMPDIR_SLM/projects/test-project"
  echo "# Test Project Rules" > "$TMPDIR_SLM/projects/test-project/reglas-negocio.md"
  echo "RN-001: Users must authenticate before accessing data." >> "$TMPDIR_SLM/projects/test-project/reglas-negocio.md"
  echo "RN-002: Orders over 1000 EUR require manager approval." >> "$TMPDIR_SLM/projects/test-project/reglas-negocio.md"
  # Add a glossary
  printf '# Glossary\n\n- PBI: Product Backlog Item\n- SDD: Spec Driven Development\n- DORA: DevOps Research and Assessment\n' \
    > "$TMPDIR_SLM/projects/test-project/GLOSSARY.md"
  # Add a file with PII for sanitization testing
  printf 'Contact: john.doe@acme.com\nDNI: 12345678A\nCall: +34 612 345 678\nKey: AKIAIOSFODNN7EXAMPLE\n' \
    > "$TMPDIR_SLM/projects/test-project/contact-info.md"
}
teardown() {
  export HOME="$HOME_ORIG"
  rm -rf "$TMPDIR_SLM"
}

## Structural tests

@test "slm-data-prep.sh exists, executable, valid syntax" {
  [[ -x "$PREP_SCRIPT" ]]
  bash -n "$PREP_SCRIPT"
}
@test "slm-train.sh exists, executable, valid syntax" {
  [[ -x "$TRAIN_SCRIPT" ]]
  bash -n "$TRAIN_SCRIPT"
}
@test "uses set -uo pipefail in data-prep" {
  head -3 "$PREP_SCRIPT" | grep -q "set -uo pipefail"
}
@test "uses set -uo pipefail in train" {
  head -3 "$TRAIN_SCRIPT" | grep -q "set -uo pipefail"
}
@test "SE-027 spec exists" {
  [[ -f "$SPEC" ]]
}

## Data prep: collect

@test "collect gathers project documents" {
  run bash "$PREP_SCRIPT" collect --project test-project
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Collected"* ]]
  [[ -d "$HOME/.savia/slm-data/test-project/raw" ]]
  local count; count=$(ls "$HOME/.savia/slm-data/test-project/raw/" | wc -l)
  [[ "$count" -ge 2 ]]
}
@test "collect generates manifest with file hashes" {
  bash "$PREP_SCRIPT" collect --project test-project >/dev/null
  [[ -f "$HOME/.savia/slm-data/test-project/collection-manifest.json" ]]
  python3 -c "
import json
m = json.load(open('$HOME/.savia/slm-data/test-project/collection-manifest.json'))
assert m['project'] == 'test-project'
assert m['document_count'] >= 2
assert all('sha256' in f for f in m['files'])
"
}
@test "collect sanitizes PII from documents" {
  bash "$PREP_SCRIPT" collect --project test-project >/dev/null
  local raw_dir="$HOME/.savia/slm-data/test-project/raw"
  # Find the contact-info file (path separators replaced with _)
  local contact_file; contact_file=$(ls "$raw_dir" | grep "contact" | head -1)
  [[ -n "$contact_file" ]]
  # Verify PII was redacted
  ! grep -q "john.doe@acme.com" "$raw_dir/$contact_file"
  grep -q "\[EMAIL\]" "$raw_dir/$contact_file"
  ! grep -q "12345678A" "$raw_dir/$contact_file"
  ! grep -q "AKIAIOSFODNN7EXAMPLE" "$raw_dir/$contact_file"
}
@test "collect fails on nonexistent project" {
  run bash "$PREP_SCRIPT" collect --project nonexistent
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}

## Data prep: format

@test "format creates SFT dataset in JSONL" {
  bash "$PREP_SCRIPT" collect --project test-project >/dev/null
  run bash "$PREP_SCRIPT" format --project test-project --method sft
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Generated"* ]]
  [[ -f "$HOME/.savia/slm-data/test-project/dataset-sft.jsonl" ]]
  # Verify JSONL is valid
  python3 -c "
import json
with open('$HOME/.savia/slm-data/test-project/dataset-sft.jsonl') as f:
    for line in f:
        entry = json.loads(line)
        assert 'messages' in entry
        assert len(entry['messages']) >= 2
"
}
@test "format creates DPO dataset" {
  bash "$PREP_SCRIPT" collect --project test-project >/dev/null
  run bash "$PREP_SCRIPT" format --project test-project --method dpo
  [[ "$status" -eq 0 ]]
  [[ -f "$HOME/.savia/slm-data/test-project/dataset-dpo.jsonl" ]]
}
@test "format fails without prior collect" {
  run bash "$PREP_SCRIPT" format --project test-project
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}

## Data prep: validate

@test "validate passes on well-formed SFT data" {
  bash "$PREP_SCRIPT" collect --project test-project >/dev/null
  bash "$PREP_SCRIPT" format --project test-project --method sft >/dev/null
  run bash "$PREP_SCRIPT" validate --project test-project
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"PASS"* ]]
}

## Data prep: split

@test "split creates train and eval sets" {
  bash "$PREP_SCRIPT" collect --project test-project >/dev/null
  bash "$PREP_SCRIPT" format --project test-project --method sft >/dev/null
  run bash "$PREP_SCRIPT" split --project test-project --ratio 0.8
  [[ "$status" -eq 0 ]]
  [[ -f "$HOME/.savia/slm-data/test-project/train-sft.jsonl" ]]
  [[ -f "$HOME/.savia/slm-data/test-project/eval-sft.jsonl" ]]
}

## Data prep: stats

@test "stats reports dataset information" {
  bash "$PREP_SCRIPT" collect --project test-project >/dev/null
  bash "$PREP_SCRIPT" format --project test-project --method sft >/dev/null
  run bash "$PREP_SCRIPT" stats --project test-project
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Documents"* ]]
  [[ "$output" == *"Examples"* ]]
}

## Train: check

@test "train check reports dependencies" {
  run bash "$TRAIN_SCRIPT" check
  # Should not crash, regardless of whether deps are installed
  [[ "$output" == *"Python"* ]]
  [[ "$output" == *"GPU"* ]]
  [[ "$output" == *"RAM"* ]]
}

## Train: forget

@test "forget cleans all data for a project" {
  bash "$PREP_SCRIPT" collect --project test-project >/dev/null
  bash "$PREP_SCRIPT" format --project test-project --method sft >/dev/null
  bash "$PREP_SCRIPT" split --project test-project >/dev/null
  # Verify data exists
  [[ -d "$HOME/.savia/slm-data/test-project" ]]
  # Forget
  run bash "$TRAIN_SCRIPT" forget --project test-project --confirm
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Removed"* ]]
  # Verify data is gone
  [[ ! -d "$HOME/.savia/slm-data/test-project" ]]
}
@test "forget refuses without --confirm" {
  run bash "$TRAIN_SCRIPT" forget --project test-project
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"--confirm"* ]]
}

## Edge cases

@test "data-prep shows usage with no args" {
  run bash "$PREP_SCRIPT"
  [[ "$output" == *"Usage"* ]]
}
@test "train shows usage with no args" {
  run bash "$TRAIN_SCRIPT"
  [[ "$output" == *"Usage"* ]]
}
@test "collect without --project fails" {
  run bash "$PREP_SCRIPT" collect
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}
@test "empty project directory still collects zero docs gracefully" {
  mkdir -p "$TMPDIR_SLM/projects/empty-project"
  run bash "$PREP_SCRIPT" collect --project empty-project
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Collected: 0"* ]]
}
