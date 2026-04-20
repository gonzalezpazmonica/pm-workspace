#!/usr/bin/env bats
# Ref: SE-028/041/056 + unified runner
SCRIPT="scripts/memvid-probe.sh"

setup() { export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"; cd "$BATS_TEST_DIRNAME/.."; }
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "--help exits 0" { run bash "$SCRIPT" --help; [ "$status" -eq 0 ]; }
@test "rejects unknown arg" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }
@test "runs without crash" { run bash "$SCRIPT"; [[ "$status" -eq 0 || "$status" -eq 1 ]]; }
@test "--json produces output" { run bash "$SCRIPT" --json; [[ "$output" == *"{"* ]]; }
@test "--json parses as JSON" {
  run bash -c 'bash '"$SCRIPT"' --json | python3 -c "import json,sys; json.load(sys.stdin); print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}

@test "references SE-041" { run grep -c 'SE-041' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "references memvid" { run grep -ic 'memvid' "$SCRIPT"; [[ "$output" -ge 3 ]]; }
@test "rejects nonexistent --corpus-dir" { run bash "$SCRIPT" --corpus-dir /nonexistent; [ "$status" -eq 2 ]; }
@test "verdict is bounded" {
  run bash "$SCRIPT" --json
  [[ "$output" == *"VIABLE"* || "$output" == *"BLOCKED"* || "$output" == *"NEEDS_INSTALL"* ]]
}
@test "--json has memvid field" {
  run bash -c 'bash scripts/memvid-probe.sh --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"memvid\" in d; print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "--json has ffmpeg field" {
  run bash -c 'bash scripts/memvid-probe.sh --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"ffmpeg\" in d; print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "--json has corpus_docs field" {
  run bash -c 'bash scripts/memvid-probe.sh --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"corpus_docs\" in d; print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "edge: --corpus-dir with docs counts correctly" {
  local d="$BATS_TEST_TMPDIR/corpus"
  mkdir -p "$d"
  for i in 1 2 3; do echo "doc $i" > "$d/doc-$i.md"; done
  run bash -c 'bash scripts/memvid-probe.sh --corpus-dir "'"$d"'" --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert d[\"corpus_docs\"] == 3; print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "output reports VERDICT" {
  run bash "$SCRIPT"
  [[ "$output" == *"VERDICT"* ]]
}
@test "edge: empty corpus dir = 0 docs" {
  local d="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$d"
  run bash -c 'bash scripts/memvid-probe.sh --corpus-dir "'"$d"'" --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert d[\"corpus_docs\"] == 0; print(\"ok\")"'
  [[ "$output" == *"ok"* ]]
}
@test "NEEDS_INSTALL path present" { run grep -c 'NEEDS_INSTALL' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "isolation: no file writes" {
  local before
  before=$(find scripts tests docs -type f 2>/dev/null | wc -l)
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local after
  after=$(find scripts tests docs -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"; [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]
}
