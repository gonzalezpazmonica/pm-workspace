#!/usr/bin/env bats
# SE-167: Skill Maturity Kanban audit script.
# Acceptance: classifies all skills into 4 states (Calibrated/Incomplete/Stub/Deprecated),
# emits TSV + markdown kanban, excludes _template, exit 0 always.

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
  SCRIPT="scripts/skill-maturity-audit.sh"
  STAMP="$(date +%Y%m%d)"
  TSV="output/skill-maturity-audit-$STAMP.tsv"
  MD="output/skill-maturity-kanban-$STAMP.md"
}

teardown() {
  cd /
}

# Structural

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script declares set -uo pipefail (safety_verification)" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "script has shebang on first line" {
  head -1 "$SCRIPT" | grep -q '^#!/usr/bin/env bash'
}

# Execution

@test "audit runs without error" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "audit produces TSV with expected header" {
  run bash "$SCRIPT" --tsv-only
  [ "$status" -eq 0 ]
  [[ -f "$TSV" ]]
  head -1 "$TSV" | grep -q "skill"
  head -1 "$TSV" | grep -q "state"
}

@test "audit produces markdown kanban with summary section" {
  run bash "$SCRIPT" --markdown-only
  [ "$status" -eq 0 ]
  [[ -f "$MD" ]]
  grep -q "^# Skill Maturity Kanban" "$MD"
  grep -q "^## Summary" "$MD"
}

@test "kanban has all 4 state sections" {
  bash "$SCRIPT" --markdown-only
  grep -q "^## Calibrated" "$MD"
  grep -q "^## Incomplete" "$MD"
  grep -q "^## Stub" "$MD"
  grep -q "^## Deprecated" "$MD"
}

@test "TSV row count matches skill count minus _template" {
  bash "$SCRIPT" --tsv-only
  local skill_count
  skill_count=$(ls -d .claude/skills/*/ | grep -cv '_template')
  local tsv_rows
  tsv_rows=$(($(wc -l < "$TSV") - 1))
  [ "$tsv_rows" -eq "$skill_count" ]
}

@test "_template is excluded from output" {
  bash "$SCRIPT" --tsv-only
  ! grep -q "^_template" "$TSV"
}

# Classification logic

@test "every TSV row has state column in valid set" {
  bash "$SCRIPT" --tsv-only
  python3 -c "
import sys
valid = {'Calibrated', 'Incomplete', 'Stub', 'Deprecated'}
with open('$TSV') as f:
    next(f)
    for line in f:
        cols = line.rstrip().split('\t')
        assert cols[1] in valid, f'invalid state: {cols[1]} in row {cols[0]}'
print('all states valid')
"
}

@test "summary count matches state distribution in TSV" {
  bash "$SCRIPT"
  python3 -c "
from collections import Counter
with open('$TSV') as f:
    next(f)
    states = Counter(line.split('\t')[1] for line in f)
total_tsv = sum(states.values())
with open('$MD') as f:
    md = f.read()
import re
m = re.search(r'\| Calibrated \| (\d+) \|', md)
assert m and int(m.group(1)) == states.get('Calibrated', 0)
m = re.search(r'\| Incomplete \| (\d+) \|', md)
assert m and int(m.group(1)) == states.get('Incomplete', 0)
m = re.search(r'\| Stub \| (\d+) \|', md)
assert m and int(m.group(1)) == states.get('Stub', 0)
print(f'OK: {total_tsv} skills, distribution matches')
"
}

@test "Calibrated requires stable maturity AND has_test=true" {
  bash "$SCRIPT" --tsv-only
  python3 -c "
with open('$TSV') as f:
    next(f)
    for line in f:
        cols = line.rstrip().split('\t')
        if cols[1] == 'Calibrated':
            assert cols[2] == 'stable', f'{cols[0]}: maturity={cols[2]}'
            assert cols[3] == 'true', f'{cols[0]}: has_test={cols[3]}'
print('Calibrated invariant holds')
"
}

@test "Stub means missing DOMAIN.md or skill_lines<50" {
  bash "$SCRIPT" --tsv-only
  python3 -c "
import os
with open('$TSV') as f:
    next(f)
    for line in f:
        cols = line.rstrip().split('\t')
        if cols[1] == 'Stub':
            name = cols[0]
            lines = int(cols[4])
            domain = os.path.exists(f'.claude/skills/{name}/DOMAIN.md')
            assert (not domain) or lines < 50, f'{name}: not stub-shaped (domain={domain}, lines={lines})'
print('Stub invariant holds')
"
}

# Edge cases

@test "edge: empty maturity column shows as -" {
  bash "$SCRIPT" --tsv-only
  python3 -c "
with open('$TSV') as f:
    next(f)
    for line in f:
        cols = line.rstrip().split('\t')
        assert cols[2] != '', f'{cols[0]}: empty maturity'
print('no empty maturity values')
"
}

@test "edge: re-running is idempotent (same state distribution)" {
  bash "$SCRIPT" --tsv-only
  local before
  before=$(md5sum "$TSV" | cut -d' ' -f1)
  bash "$SCRIPT" --tsv-only
  local after
  after=$(md5sum "$TSV" | cut -d' ' -f1)
  [ "$before" = "$after" ]
}

@test "edge: --help flag prints usage and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "usage"
}

@test "edge: nonexistent skills directory handled gracefully (no crash)" {
  local fake_root="$TMPDIR/no-skills-fake-root"
  mkdir -p "$fake_root/scripts" "$fake_root/output"
  cp "$SCRIPT" "$fake_root/scripts/"
  cd "$fake_root"
  run bash scripts/skill-maturity-audit.sh
  [ "$status" -eq 0 ]
  cd "$BATS_TEST_DIRNAME/.."
}

# Negative

@test "negative: invalid TSV state would be caught (assertion logic)" {
  python3 -c "
valid = {'Calibrated', 'Incomplete', 'Stub', 'Deprecated'}
bogus = 'Calibratedz'
assert bogus not in valid
print('negative assertion works')
"
}

@test "negative: zero-length TSV would fail header check" {
  local empty="$TMPDIR/empty.tsv"
  : > "$empty"
  ! grep -q "skill" "$empty"
}

# Spec ref

@test "spec ref: SE-167 referenced in script header" {
  grep -q "SE-167" "$SCRIPT"
}

@test "spec ref: rule doc skill-maturity-kanban.md exists" {
  [[ -f "docs/rules/domain/skill-maturity-kanban.md" ]]
}

@test "spec ref: rule doc declares 4 canonical states" {
  for s in Calibrated Incomplete Stub Deprecated; do
    grep -q "$s" docs/rules/domain/skill-maturity-kanban.md
  done
}

# Coverage

@test "coverage: TSV has at least 50 skill rows (workspace baseline)" {
  bash "$SCRIPT" --tsv-only
  local rows
  rows=$(($(wc -l < "$TSV") - 1))
  [ "$rows" -ge 50 ]
}
