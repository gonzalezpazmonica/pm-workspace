#!/usr/bin/env bats
# BATS tests for scripts/slm-data-collect.sh (workspace data harvester).
# Validates source allow-list, JSONL output, Alpaca format, isolation.
#
# Ref: SPEC-023 §Fuentes de datos, SPEC-SE-027 §Pipeline de preparación
# Safety: script under test `set -uo pipefail`, read-only on workspace.

SCRIPT="scripts/slm-data-collect.sh"

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

@test "script references SPEC-023 or SPEC-SE-027" {
  run grep -cE 'SPEC-023|SPEC-SE-027' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI ────────────────────────────────────────────────────────────────────

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"source"* ]]
  [[ "$output" == *"specs"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --source" {
  run bash "$SCRIPT" --output "$BATS_TEST_TMPDIR/o.jsonl"
  [ "$status" -eq 2 ]
}

@test "requires --output" {
  run bash "$SCRIPT" --source specs
  [ "$status" -eq 2 ]
}

@test "rejects invalid source" {
  run bash "$SCRIPT" --source bogus --output "$BATS_TEST_TMPDIR/o.jsonl"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid --source"* ]]
}

# ── Collection ─────────────────────────────────────────────────────────────

@test "collects specs source successfully" {
  local out="$BATS_TEST_TMPDIR/specs.jsonl"
  run bash "$SCRIPT" --source specs --output "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out" ]]
}

@test "collects agents source successfully" {
  local out="$BATS_TEST_TMPDIR/agents.jsonl"
  run bash "$SCRIPT" --source agents --output "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out" ]]
}

@test "collects skills source successfully" {
  local out="$BATS_TEST_TMPDIR/skills.jsonl"
  run bash "$SCRIPT" --source skills --output "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out" ]]
}

@test "all source combines all sources" {
  local out_all="$BATS_TEST_TMPDIR/all.jsonl"
  local out_specs="$BATS_TEST_TMPDIR/specs.jsonl"
  bash "$SCRIPT" --source specs --output "$out_specs" >/dev/null 2>&1
  bash "$SCRIPT" --source all --output "$out_all" >/dev/null 2>&1
  local n_all n_specs
  n_all=$(wc -l < "$out_all")
  n_specs=$(wc -l < "$out_specs")
  # all >= specs
  [[ "$n_all" -ge "$n_specs" ]]
}

@test "output has non-zero entries for all sources" {
  local out="$BATS_TEST_TMPDIR/all.jsonl"
  bash "$SCRIPT" --source all --output "$out" >/dev/null 2>&1
  local n
  n=$(wc -l < "$out")
  [[ "$n" -gt 10 ]]
}

# ── Alpaca format ──────────────────────────────────────────────────────────

@test "output is valid JSONL with Alpaca schema" {
  local out="$BATS_TEST_TMPDIR/out.jsonl"
  bash "$SCRIPT" --source specs --output "$out" >/dev/null 2>&1
  run bash -c 'python3 -c "
import json
with open(\"'"$out"'\") as f:
    for ln, line in enumerate(f, 1):
        d = json.loads(line)
        assert \"instruction\" in d, f\"line {ln}: missing instruction\"
        assert \"output\" in d, f\"line {ln}: missing output\"
        assert \"input\" in d, f\"line {ln}: missing input\"
print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "spec entries have instruction starting with 'Explica'" {
  local out="$BATS_TEST_TMPDIR/specs.jsonl"
  bash "$SCRIPT" --source specs --output "$out" >/dev/null 2>&1
  run head -1 "$out"
  [[ "$output" == *"Explica"* ]]
}

@test "agent entries have instruction about agents" {
  local out="$BATS_TEST_TMPDIR/agents.jsonl"
  bash "$SCRIPT" --source agents --output "$out" >/dev/null 2>&1
  # First line should mention "agente"
  run head -1 "$out"
  [[ "$output" == *"agente"* ]]
}

@test "skill entries have instruction about skills" {
  local out="$BATS_TEST_TMPDIR/skills.jsonl"
  bash "$SCRIPT" --source skills --output "$out" >/dev/null 2>&1
  run head -1 "$out"
  [[ "$output" == *"skill"* ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: output directory is created if missing" {
  local out="$BATS_TEST_TMPDIR/new/nested/path.jsonl"
  [[ ! -d "$(dirname "$out")" ]]
  run bash "$SCRIPT" --source specs --output "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out" ]]
}

@test "edge: --min-lines parameter is honored" {
  local out1="$BATS_TEST_TMPDIR/min1.jsonl"
  local out10="$BATS_TEST_TMPDIR/min10.jsonl"
  bash "$SCRIPT" --source specs --output "$out1" --min-lines 1 >/dev/null 2>&1
  bash "$SCRIPT" --source specs --output "$out10" --min-lines 10 >/dev/null 2>&1
  local n1 n10
  n1=$(wc -l < "$out1")
  n10=$(wc -l < "$out10")
  # higher min-lines should yield fewer or equal entries
  [[ "$n10" -le "$n1" ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify workspace files" {
  local before_hash
  before_hash=$(find docs/propuestas -name '*.md' -newer /tmp/_slm_collect_test_marker 2>/dev/null | wc -l)
  touch /tmp/_slm_collect_test_marker
  bash "$SCRIPT" --source all --output "$BATS_TEST_TMPDIR/o.jsonl" >/dev/null 2>&1
  local after_hash
  after_hash=$(find docs/propuestas -name '*.md' -newer /tmp/_slm_collect_test_marker 2>/dev/null | wc -l)
  rm -f /tmp/_slm_collect_test_marker
  [[ "$after_hash" -eq 0 ]]
}

@test "isolation: exit codes are 0 or 2" {
  run bash "$SCRIPT" --source specs --output "$BATS_TEST_TMPDIR/o.jsonl"
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
