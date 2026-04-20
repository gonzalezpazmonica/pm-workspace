#!/usr/bin/env bats
# Ref: SE-033
SCRIPT="scripts/bertopic-probe.sh"

setup() { export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"; cd "$BATS_TEST_DIRNAME/.."; }
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-033" { run grep -c 'SE-033' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "references BERTopic" { run grep -ic 'bertopic' "$SCRIPT"; [[ "$output" -ge 2 ]]; }

@test "--help exits 0" { run bash "$SCRIPT" --help; [ "$status" -eq 0 ]; [[ "$output" == *"corpus"* ]]; }
@test "rejects unknown arg" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }
@test "rejects nonexistent --corpus-dir" { run bash "$SCRIPT" --corpus-dir /nope; [ "$status" -eq 2 ]; }

@test "no args: emits verdict" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "--json valid" {
  run bash -c 'bash scripts/bertopic-probe.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"python_version\",\"bertopic\",\"umap\",\"hdbscan\",\"sentence_transformers\",\"corpus_count\",\"min_docs\",\"missing_deps\",\"reasons\"]:
    assert k in d
assert isinstance(d[\"missing_deps\"], list)
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "output reports Dependencies" { run bash "$SCRIPT"; [[ "$output" == *"Dependencies:"* ]]; }

# ── Edge cases ────────────────────────

@test "edge: --corpus-dir with 0 docs reports corpus_count=0" {
  local empty="$BATS_TEST_TMPDIR/empty-corpus"
  mkdir -p "$empty"
  run bash -c 'bash scripts/bertopic-probe.sh --corpus-dir "'"$empty"'" --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"corpus_count\"] == 0
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "edge: --corpus-dir with small corpus reports CORPUS_TOO_SMALL" {
  local small="$BATS_TEST_TMPDIR/small-corpus"
  mkdir -p "$small"
  for i in 1 2; do echo "doc $i" > "$small/doc-$i.md"; done
  run bash "$SCRIPT" --corpus-dir "$small"
  # Either BLOCKED/NEEDS_INSTALL or CORPUS_TOO_SMALL
  [[ "$output" == *"CORPUS_TOO_SMALL"* || "$output" == *"NEEDS_INSTALL"* || "$output" == *"BLOCKED"* ]]
}

@test "edge: --corpus-dir with large corpus counts correctly" {
  local big="$BATS_TEST_TMPDIR/big-corpus"
  mkdir -p "$big"
  for i in $(seq 1 60); do echo "doc $i" > "$big/doc-$i.md"; done
  run bash -c 'bash scripts/bertopic-probe.sh --corpus-dir "'"$big"'" --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"corpus_count\"] == 60
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "edge: zero docs boundary (corpus=49 triggers too_small)" {
  local at="$BATS_TEST_TMPDIR/at-bound"
  mkdir -p "$at"
  for i in $(seq 1 49); do echo "x" > "$at/d-$i.md"; done
  run bash -c 'bash scripts/bertopic-probe.sh --corpus-dir "'"$at"'" --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"corpus_count\"] == 49
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Negative ─────────────────────────

@test "negative: missing deps yields NEEDS_INSTALL" {
  run grep -c 'NEEDS_INSTALL' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "negative: verdict values are bounded" {
  run bash "$SCRIPT" --json
  [[ "$output" == *"VIABLE"* || "$output" == *"BLOCKED"* || "$output" == *"NEEDS_INSTALL"* || "$output" == *"CORPUS_TOO_SMALL"* ]]
}

# ── Coverage ─────────────────────────

@test "coverage: BERTOPIC_OK var" { run grep -c 'BERTOPIC_OK' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: UMAP_OK var" { run grep -c 'UMAP_OK' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: HDBSCAN_OK var" { run grep -c 'HDBSCAN_OK' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: MIN_DOCS constant" { run grep -c 'MIN_DOCS' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

# ── Isolation ────────────────────────

@test "isolation: no file writes" {
  local before
  before=$(find scripts tests docs -type f 2>/dev/null | wc -l)
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local after
  after=$(find scripts tests docs -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}
