#!/usr/bin/env bats
# BATS tests for scripts/pdf-extract-probe.sh (SPEC-102 Slice 1).
#
# Ref: SPEC-102, ROADMAP §Tier 4.4
# Safety: script under test `set -uo pipefail`, read-only.

SCRIPT="scripts/pdf-extract-probe.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }

@test "uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }

@test "references SPEC-102" {
  run grep -c 'SPEC-102' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "clarifies it does NOT download/install" {
  run grep -ciE 'NO (instala|descarga)|NOT install|NOT download|NO download' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"probe"* || "$output" == *"preconditions"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent sample PDF" {
  run bash "$SCRIPT" --sample /nope.pdf
  [ "$status" -eq 2 ]
}

@test "no args: emits VIABLE or BLOCKED report" {
  run bash "$SCRIPT"
  # 0 if Java present, 1 if not
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "report includes Java section" {
  run bash "$SCRIPT"
  [[ "$output" == *"Java:"* ]]
}

@test "report includes 'Build tools' section" {
  run bash "$SCRIPT"
  [[ "$output" == *"Build tools"* ]]
}

@test "json output has expected keys" {
  run bash -c 'bash '"$SCRIPT"' --json | python3 -c "
import json,sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"java_version\",\"java_major\",\"reasons\"]:
    assert k in d
print(\"ok\")
"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json reasons is a list" {
  run bash -c 'bash '"$SCRIPT"' --json | python3 -c "
import json,sys
d = json.load(sys.stdin)
assert isinstance(d[\"reasons\"], list)
print(\"ok\")
"'
  [ "$status" -eq 0 ]
}

@test "sample PDF valid magic bytes recognized" {
  local sample="$BATS_TEST_TMPDIR/test.pdf"
  printf '%%PDF-1.4\n%%fake pdf content\n' > "$sample"
  run bash "$SCRIPT" --sample "$sample"
  [[ "$output" == *"✅"* || "$output" == *"PDF magic"* ]]
}

@test "sample with bad magic bytes rejected" {
  local sample="$BATS_TEST_TMPDIR/fake.pdf"
  echo "not a pdf" > "$sample"
  run bash "$SCRIPT" --sample "$sample"
  [[ "$output" == *"bad magic"* ]]
}

@test "json includes sample size when provided" {
  local sample="$BATS_TEST_TMPDIR/test.pdf"
  printf '%%PDF-1.4\n%%content\n' > "$sample"
  run bash "$SCRIPT" --sample "$sample" --json
  [[ "$output" == *'"sample_provided":true'* ]]
  [[ "$output" == *'"sample_size_bytes":'* ]]
}

@test "verdict field is one of VIABLE/BLOCKED/NEEDS_JAVA" {
  run bash "$SCRIPT" --json
  [[ "$output" == *"VIABLE"* || "$output" == *"BLOCKED"* || "$output" == *"NEEDS_JAVA"* ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
