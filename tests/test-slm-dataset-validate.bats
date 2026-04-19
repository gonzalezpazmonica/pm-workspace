#!/usr/bin/env bats
# BATS tests for scripts/slm-dataset-validate.sh (pre-training validator).
# Validates Alpaca schema check, PII scan, dedup detection, length stats,
# min-samples threshold, JSON output, isolation.
#
# Ref: SPEC-SE-027 §Data prep, docs/rules/domain/slm-training-pipeline.md §Fase 1
# Safety: script under test `set -uo pipefail`, read-only.

SCRIPT="scripts/slm-dataset-validate.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# Helper: generate a clean dataset with N unique records.
make_clean_dataset() {
  local path="$1" n="$2"
  python3 -c "
import json
with open('$path','w') as f:
    for i in range($n):
        rec = {'instruction': f'Explain concept {i}', 'output': f'Concept {i} is important because it enables feature X and Y and Z.'}
        f.write(json.dumps(rec)+'\n')
"
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

@test "script references SPEC-SE-027 or SPEC-023" {
  run grep -cE 'SPEC-SE-027|SPEC-023' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI ────────────────────────────────────────────────────────────────────

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"input"* ]]
  [[ "$output" == *"min-samples"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --input" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent input file" {
  run bash "$SCRIPT" --input /does/not/exist.jsonl
  [ "$status" -eq 2 ]
}

@test "rejects non-integer min-samples" {
  local d="$BATS_TEST_TMPDIR/d.jsonl"
  echo '{"instruction":"x","output":"y"}' > "$d"
  run bash "$SCRIPT" --input "$d" --min-samples abc
  [ "$status" -eq 2 ]
}

# ── Positive ───────────────────────────────────────────────────────────────

@test "clean dataset with 150 records validates" {
  local d="$BATS_TEST_TMPDIR/clean.jsonl"
  make_clean_dataset "$d" 150
  run bash "$SCRIPT" --input "$d"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VALID"* ]]
}

@test "valid output shows length stats" {
  local d="$BATS_TEST_TMPDIR/clean.jsonl"
  make_clean_dataset "$d" 150
  run bash "$SCRIPT" --input "$d"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Length:"* ]]
  [[ "$output" == *"median/max"* ]]
}

@test "valid output shows unique count" {
  local d="$BATS_TEST_TMPDIR/clean.jsonl"
  make_clean_dataset "$d" 150
  run bash "$SCRIPT" --input "$d"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Unique: 150/150"* ]]
}

# ── Size threshold ─────────────────────────────────────────────────────────

@test "below min-samples returns 1 with error" {
  local d="$BATS_TEST_TMPDIR/small.jsonl"
  make_clean_dataset "$d" 10
  run bash "$SCRIPT" --input "$d"
  [ "$status" -eq 1 ]
  [[ "$output" == *"below"* ]]
  [[ "$output" == *"10"* ]]
}

@test "custom --min-samples threshold is honored" {
  local d="$BATS_TEST_TMPDIR/d.jsonl"
  make_clean_dataset "$d" 50
  run bash "$SCRIPT" --input "$d" --min-samples 30
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" --input "$d" --min-samples 100
  [ "$status" -eq 1 ]
}

# ── PII detection ──────────────────────────────────────────────────────────

@test "email in dataset fails validation" {
  local d="$BATS_TEST_TMPDIR/pii.jsonl"
  cat > "$d" <<EOF
{"instruction":"Contact user@example.com","output":"OK"}
EOF
  run bash "$SCRIPT" --input "$d" --min-samples 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"PII"* ]]
  [[ "$output" == *"email"* ]]
}

@test "DNI in dataset fails validation" {
  local d="$BATS_TEST_TMPDIR/pii.jsonl"
  cat > "$d" <<EOF
{"instruction":"Mi DNI es 12345678X","output":"OK"}
EOF
  run bash "$SCRIPT" --input "$d" --min-samples 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"DNI"* ]]
}

@test "--allow-pii downgrades PII errors to warnings" {
  local d="$BATS_TEST_TMPDIR/pii.jsonl"
  cat > "$d" <<EOF
{"instruction":"Contact user@example.com","output":"OK"}
EOF
  make_clean_dataset "$BATS_TEST_TMPDIR/more.jsonl" 100
  cat "$BATS_TEST_TMPDIR/more.jsonl" >> "$d"
  run bash "$SCRIPT" --input "$d" --min-samples 1 --allow-pii
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warnings"* || "$output" == *"allowed"* ]]
}

# ── Schema ──────────────────────────────────────────────────────────────────

@test "records missing 'instruction' field are counted" {
  local d="$BATS_TEST_TMPDIR/bad.jsonl"
  cat > "$d" <<EOF
{"output":"only output, no instruction"}
EOF
  run bash "$SCRIPT" --input "$d" --min-samples 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing"* || "$output" == *"records"* ]]
}

@test "malformed JSON lines are counted" {
  local d="$BATS_TEST_TMPDIR/malformed.jsonl"
  printf 'not json\n{broken\n' > "$d"
  run bash "$SCRIPT" --input "$d" --min-samples 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed"* ]]
}

# ── Dedup ──────────────────────────────────────────────────────────────────

@test "high duplicate rate triggers error" {
  local d="$BATS_TEST_TMPDIR/dup.jsonl"
  python3 -c "
import json
with open('$d','w') as f:
    # 80% duplicates
    for i in range(80):
        f.write(json.dumps({'instruction':'same question','output':'same answer'})+'\n')
    for i in range(20):
        f.write(json.dumps({'instruction':f'q{i}','output':f'a{i}'})+'\n')
"
  run bash "$SCRIPT" --input "$d" --min-samples 50
  [ "$status" -eq 1 ]
  [[ "$output" == *"duplicate"* ]]
}

@test "low duplicate rate (<5%) passes without warning" {
  local d="$BATS_TEST_TMPDIR/d.jsonl"
  make_clean_dataset "$d" 150
  run bash "$SCRIPT" --input "$d"
  [ "$status" -eq 0 ]
  [[ "$output" != *"duplicate"* ]]
}

# ── JSON output ────────────────────────────────────────────────────────────

@test "json output is valid JSON with expected keys" {
  local d="$BATS_TEST_TMPDIR/d.jsonl"
  make_clean_dataset "$d" 150
  run bash -c 'bash '"$SCRIPT"' --input '"$d"' --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"valid\" in d; assert \"valid_records\" in d; assert \"pii\" in d; assert \"stats\" in d; print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json output shows valid:true for clean dataset" {
  local d="$BATS_TEST_TMPDIR/d.jsonl"
  make_clean_dataset "$d" 150
  run bash "$SCRIPT" --input "$d" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"valid": true'* ]]
}

@test "json output lists PII counts" {
  local d="$BATS_TEST_TMPDIR/d.jsonl"
  echo '{"instruction":"email me at a@b.co","output":"ok"}' > "$d"
  run bash "$SCRIPT" --input "$d" --min-samples 1 --json
  [ "$status" -eq 1 ]
  [[ "$output" == *'"emails": 1'* ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: empty file fails min-samples" {
  local d="$BATS_TEST_TMPDIR/empty.jsonl"
  : > "$d"
  run bash "$SCRIPT" --input "$d"
  [ "$status" -eq 1 ]
}

@test "edge: records with optional 'input' field validate" {
  local d="$BATS_TEST_TMPDIR/d.jsonl"
  python3 -c "
import json
with open('$d','w') as f:
    for i in range(150):
        rec = {'instruction':f'q{i}', 'input':f'context{i}', 'output':f'answer{i}'}
        f.write(json.dumps(rec)+'\n')
"
  run bash "$SCRIPT" --input "$d"
  [ "$status" -eq 0 ]
}

@test "edge: mixed valid+malformed counts both" {
  local d="$BATS_TEST_TMPDIR/d.jsonl"
  echo '{"instruction":"x","output":"y"}' > "$d"
  echo 'malformed' >> "$d"
  run bash "$SCRIPT" --input "$d" --min-samples 1 --json
  [ "$status" -eq 1 ]
  [[ "$output" == *'"malformed":'* ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify input file" {
  local d="$BATS_TEST_TMPDIR/ro.jsonl"
  make_clean_dataset "$d" 150
  local h_before
  h_before=$(md5sum "$d" | awk '{print $1}')
  bash "$SCRIPT" --input "$d" >/dev/null 2>&1
  bash "$SCRIPT" --input "$d" --json >/dev/null 2>&1
  local h_after
  h_after=$(md5sum "$d" | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes are 0/1/2" {
  local d="$BATS_TEST_TMPDIR/d.jsonl"
  make_clean_dataset "$d" 150
  run bash "$SCRIPT" --input "$d"
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --input "$d" --min-samples 1000
  [[ "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
