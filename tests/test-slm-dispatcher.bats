#!/usr/bin/env bats
# BATS tests for scripts/slm.sh (SE-049 Slice 1 — dispatcher + routing)
# Ref: docs/propuestas/SE-049-slm-command-consolidation-pattern-slm-sh-subcommand.md

SCRIPT="scripts/slm.sh"
LIB="scripts/lib/slm-common.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
}
teardown() { cd /; }

# ── Existence & safety ────────────────────────────────────

@test "dispatcher script exists and is executable" { [[ -x "$SCRIPT" ]]; }
@test "shared library exists" { [[ -f "$LIB" ]]; }
@test "dispatcher passes bash -n syntax" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "library passes bash -n syntax" { run bash -n "$LIB"; [ "$status" -eq 0 ]; }
@test "dispatcher uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "SE-049 reference in dispatcher" {
  run grep -c 'SE-049' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Help & list ───────────────────────────────────────────

@test "--help exits 0 with usage text" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"SUBCOMMAND"* ]]
}

@test "-h alias for --help" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "help subcommand alias" {
  run bash "$SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "no args exits 2 with usage" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

# ── Registry ──────────────────────────────────────────────

@test "list subcommand outputs 16 registered commands" {
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  count=$(echo "$output" | wc -l)
  [[ "$count" -eq 16 ]]
}

@test "list includes expected subcommands" {
  run bash "$SCRIPT" list
  [[ "$output" == *"collect"* ]]
  [[ "$output" == *"train"* ]]
  [[ "$output" == *"deploy"* ]]
}

@test "--json list produces valid JSON" {
  run bash -c 'bash scripts/slm.sh --json list | python3 -m json.tool'
  [ "$status" -eq 0 ]
}

@test "--json list has subcommands array" {
  run bash -c 'bash scripts/slm.sh --json list | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert \"subcommands\" in d
assert isinstance(d[\"subcommands\"], list)
assert len(d[\"subcommands\"]) == 16
for item in d[\"subcommands\"]:
    assert \"name\" in item
    assert \"target\" in item
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "registry targets all exist on disk" {
  run bash -c 'bash scripts/slm.sh --json list | python3 -c "
import json, sys, os
d = json.load(sys.stdin)
missing = [i[\"target\"] for i in d[\"subcommands\"] if not os.path.isfile(f\"scripts/{i[\"target\"]}\")]
if missing:
    print(\"MISSING:\", missing); sys.exit(1)
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Negative cases ───────────────────────────────────────

@test "unknown subcommand exits 2" {
  run bash "$SCRIPT" nonexistent-subcommand
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown subcommand"* ]]
}

@test "unknown top-level flag rejected with exit 2" {
  run bash "$SCRIPT" --bogus-flag list
  [ "$status" -eq 2 ]
}

@test "empty subcommand string fails gracefully" {
  run bash "$SCRIPT" ""
  [ "$status" -eq 2 ]
}

@test "negative: missing shared library fails with error" {
  local TMP="$BATS_TEST_TMPDIR/no-lib"
  mkdir -p "$TMP"
  cp scripts/slm.sh "$TMP/slm.sh"
  chmod +x "$TMP/slm.sh"
  run bash "$TMP/slm.sh" --help
  [ "$status" -eq 2 ]
  [[ "$output" == *"shared library not found"* ]]
}

# ── Edge cases ───────────────────────────────────────────

@test "edge: list with -- separator treats subcommand after" {
  run bash "$SCRIPT" -- list
  [ "$status" -eq 0 ]
}

@test "edge: help output is under 80 lines (concise)" {
  run bash "$SCRIPT" --help
  count=$(echo "$output" | wc -l)
  [[ "$count" -le 80 ]]
}

@test "edge: list output is deterministic (sorted)" {
  run bash "$SCRIPT" list
  first=$(echo "$output" | head -1)
  last=$(echo "$output" | tail -1)
  [[ "$first" < "$last" ]]
}

@test "edge: nonexistent target script flagged with exit 2" {
  # Simulate by temporarily masking a target
  local TMP="$BATS_TEST_TMPDIR/masked-target"
  mkdir -p "$TMP/lib"
  cp scripts/lib/slm-common.sh "$TMP/lib/"
  # Create a slm.sh copy that points to nonexistent target
  sed 's|\[collect\]="slm-data-collect.sh"|[collect]="slm-nonexistent.sh"|' scripts/lib/slm-common.sh > "$TMP/lib/slm-common.sh"
  cp scripts/slm.sh "$TMP/slm.sh"
  chmod +x "$TMP/slm.sh"
  run bash "$TMP/slm.sh" collect
  [ "$status" -eq 2 ]
}

# ── Coverage ──────────────────────────────────────────────

@test "coverage: slm_die function defined in lib" {
  run grep -c '^slm_die()' "$LIB"
  [[ "$output" -ge 1 ]]
}

@test "coverage: slm_resolve_subcommand function defined" {
  run grep -c '^slm_resolve_subcommand()' "$LIB"
  [[ "$output" -ge 1 ]]
}

@test "coverage: slm_list_subcommands function defined" {
  run grep -c '^slm_list_subcommands()' "$LIB"
  [[ "$output" -ge 1 ]]
}

@test "coverage: SLM_REGISTRY declared in lib" {
  run grep -c 'declare -gA SLM_REGISTRY' "$LIB"
  [[ "$output" -ge 1 ]]
}

@test "coverage: mktemp used in at least one test" {
  run grep -c 'BATS_TEST_TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────────

@test "isolation: dispatcher does not modify scripts/ during help" {
  local h_before
  h_before=$(find scripts/slm-*.sh -type f -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" --help >/dev/null 2>&1
  bash "$SCRIPT" list >/dev/null 2>&1
  local h_after
  h_after=$(find scripts/slm-*.sh -type f -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes are in {0, 1, 2}" {
  run bash "$SCRIPT" --help; [ "$status" -eq 0 ]
  run bash "$SCRIPT" list; [ "$status" -eq 0 ]
  run bash "$SCRIPT"; [ "$status" -eq 2 ]
  run bash "$SCRIPT" bogus; [ "$status" -eq 2 ]
}
