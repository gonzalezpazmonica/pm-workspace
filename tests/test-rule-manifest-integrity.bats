#!/usr/bin/env bats
# BATS tests for scripts/rule-manifest-integrity.sh (SE-057 Slice 1).
# Ref: SE-057, Rule #22
SCRIPT="scripts/rule-manifest-integrity.sh"

setup() { export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"; cd "$BATS_TEST_DIRNAME/.."; }
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-057" { run grep -c 'SE-057' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "references Rule #22" { run grep -c 'Rule #22' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"max-lines"* ]]
}

@test "rejects unknown arg" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }
@test "rejects non-integer --max-lines" { run bash "$SCRIPT" --max-lines abc; [ "$status" -eq 2 ]; }
@test "rejects --max-lines 0" { run bash "$SCRIPT" --max-lines 0; [ "$status" -eq 2 ]; }

@test "runs against real repo" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "output reports INDEX.md lines" {
  run bash "$SCRIPT"
  [[ "$output" == *"INDEX.md lines:"* ]]
}

@test "output reports Manifest entries" {
  run bash "$SCRIPT"
  [[ "$output" == *"Manifest entries:"* ]]
}

@test "--json valid" {
  run bash -c 'bash scripts/rule-manifest-integrity.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"index_lines\",\"max_lines\",\"index_ok\",\"manifest_ok\",\"manifest_entries\",\"missing_files\",\"missing_entries\",\"findings\"]:
    assert k in d, f\"missing {k}\"
assert isinstance(d[\"missing_files\"], list)
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--json verdict is PASS or FAIL" {
  run bash "$SCRIPT" --json
  [[ "$output" == *'"verdict":"PASS"'* || "$output" == *'"verdict":"FAIL"'* ]]
}

@test "--max-lines 10000 makes INDEX OK" {
  run bash -c 'bash scripts/rule-manifest-integrity.sh --max-lines 10000 --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"index_ok\"] == True
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Edge cases ────────────────────────────────────────────

@test "edge: nonexistent rules dir exits 2" {
  local root="$BATS_TEST_TMPDIR/no-rules"
  mkdir -p "$root/scripts"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/rule-manifest-integrity.sh
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 2 ]
}

@test "edge: missing INDEX.md reports in findings" {
  local root="$BATS_TEST_TMPDIR/no-index"
  mkdir -p "$root/docs/rules/domain" "$root/scripts"
  echo '{}' > "$root/docs/rules/domain/rule-manifest.json"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/rule-manifest-integrity.sh
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 1 ]
  [[ "$output" == *"INDEX.md"* ]]
}

@test "edge: missing manifest reports in findings" {
  local root="$BATS_TEST_TMPDIR/no-manifest"
  mkdir -p "$root/docs/rules/domain" "$root/scripts"
  echo "# Index" > "$root/docs/rules/domain/INDEX.md"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/rule-manifest-integrity.sh
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 1 ]
  [[ "$output" == *"manifest"* ]]
}

@test "edge: invalid JSON manifest detected" {
  local root="$BATS_TEST_TMPDIR/bad-json"
  mkdir -p "$root/docs/rules/domain" "$root/scripts"
  echo "# Index" > "$root/docs/rules/domain/INDEX.md"
  echo "not json {{" > "$root/docs/rules/domain/rule-manifest.json"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/rule-manifest-integrity.sh
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 1 ]
  [[ "$output" == *"JSON"* ]]
}

@test "edge: empty findings array on clean setup" {
  local root="$BATS_TEST_TMPDIR/clean"
  mkdir -p "$root/docs/rules/domain" "$root/scripts"
  echo "# Index" > "$root/docs/rules/domain/INDEX.md"
  echo '{"rules":[]}' > "$root/docs/rules/domain/rule-manifest.json"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash -c 'bash scripts/rule-manifest-integrity.sh --json'
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}

@test "edge: boundary INDEX at exactly max-lines" {
  local root="$BATS_TEST_TMPDIR/boundary"
  mkdir -p "$root/docs/rules/domain" "$root/scripts"
  for i in $(seq 1 150); do echo "line $i" >> "$root/docs/rules/domain/INDEX.md"; done
  echo '{}' > "$root/docs/rules/domain/rule-manifest.json"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash -c 'bash scripts/rule-manifest-integrity.sh --json'
  cd "$BATS_TEST_DIRNAME/.."
  # 150 lines = at limit = OK
  [[ "$output" == *'"index_ok":true'* ]]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: INDEX_FILE variable" { run grep -c 'INDEX_FILE' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: MANIFEST_FILE variable" { run grep -c 'MANIFEST_FILE' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: MISSING_FILES array" { run grep -c 'MISSING_FILES' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: MISSING_ENTRIES array" { run grep -c 'MISSING_ENTRIES' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

# ── Isolation ────────────────────────────────────────────

@test "isolation: does not modify rules dir" {
  local h_before
  h_before=$(find docs/rules/domain -type f 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local h_after
  h_after=$(find docs/rules/domain -type f 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}
