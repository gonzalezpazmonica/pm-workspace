#!/usr/bin/env bats
# BATS tests for scripts/rule-orphan-detector.sh (SE-048 Slice 1).
# Ref: SE-048
SCRIPT="scripts/rule-orphan-detector.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-048" { run grep -c 'SE-048' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"min-refs"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "rejects non-integer --min-refs" {
  run bash "$SCRIPT" --min-refs abc
  [ "$status" -eq 2 ]
}

# ── Execution ─────────────────────────────────────────

@test "runs against real rules dir" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "output reports Total rules" {
  run bash "$SCRIPT"
  [[ "$output" == *"Total rules:"* ]]
}

@test "output reports Orphans count" {
  run bash "$SCRIPT"
  [[ "$output" == *"Orphans:"* ]]
}

@test "--json produces valid JSON" {
  run bash -c 'bash scripts/rule-orphan-detector.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"total_rules\",\"orphans\",\"min_refs\",\"orphan_list\"]:
    assert k in d
assert isinstance(d[\"orphan_list\"], list)
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--json orphan entries have refs and rule" {
  run bash -c 'bash scripts/rule-orphan-detector.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for o in d[\"orphan_list\"]:
    assert \"refs\" in o
    assert \"rule\" in o
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "total_rules > 0" {
  run bash -c 'bash scripts/rule-orphan-detector.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"total_rules\"] > 0
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "verdict is PASS or FAIL" {
  run bash "$SCRIPT" --json
  [[ "$output" == *'"verdict":"PASS"'* || "$output" == *'"verdict":"FAIL"'* ]]
}

@test "--min-refs 0 never reports orphans" {
  run bash "$SCRIPT" --min-refs 0 --json
  [ "$status" -eq 0 ]
}

@test "--min-refs 100 reports many orphans" {
  run bash -c 'bash scripts/rule-orphan-detector.sh --min-refs 100 --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
# With min-refs=100, most rules become orphans
assert d[\"orphans\"] > 0
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--include-index scans INDEX.md" {
  run bash "$SCRIPT" --include-index --json
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "default excludes INDEX.md" {
  run bash -c 'bash scripts/rule-orphan-detector.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for o in d[\"orphan_list\"]:
    assert not o[\"rule\"].endswith(\"INDEX.md\")
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Isolation ────────────────────────────────────

@test "isolation: does not modify rules dir" {
  local h_before
  h_before=$(find docs/rules/domain -name "*.md" -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local h_after
  h_after=$(find docs/rules/domain -name "*.md" -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}
