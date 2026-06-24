#!/usr/bin/env bats
# tests/test-rule-manifest-regenerate.bats — SE-097 Slice 2
# Tests for scripts/rule-manifest-regenerate.sh
#
# Coverage:
#   1. Script exists and is executable
#   2. Script uses set -uo pipefail
#   3. --dry-run does NOT modify INDEX.md
#   4. --write generates INDEX.md ≤150 lines
#   5. Generated INDEX.md has category sections
#   6. No entries in manifest pointing to non-existent files
#   7. All .md in docs/rules/domain/ are referenced in manifest
#   8. --write is idempotent (re-run produces same output)
#   9. --dry-run exits 0 when INDEX ≤150 lines
#  10. Missing argument exits non-zero

SCRIPT="scripts/rule-manifest-regenerate.sh"
INTEGRITY="scripts/rule-manifest-integrity.sh"
INDEX="docs/rules/domain/INDEX.md"
MANIFEST="docs/rules/domain/rule-manifest.json"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  # Capture original files to restore on teardown
  ORIG_INDEX="$(mktemp /tmp/orig-index-XXXXXX.md)"
  ORIG_MANIFEST="$(mktemp /tmp/orig-manifest-XXXXXX.json)"
  cp "$INDEX"    "$ORIG_INDEX"    2>/dev/null || true
  cp "$MANIFEST" "$ORIG_MANIFEST" 2>/dev/null || true
}

teardown() {
  # Restore originals if they existed
  [[ -f "$ORIG_INDEX"    ]] && cp "$ORIG_INDEX"    "$INDEX"    2>/dev/null || true
  [[ -f "$ORIG_MANIFEST" ]] && cp "$ORIG_MANIFEST" "$MANIFEST" 2>/dev/null || true
  rm -f "$ORIG_INDEX" "$ORIG_MANIFEST" 2>/dev/null || true
  cd /
}

# ── 1. Script exists and is executable ───────────────────────────────────────
@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

# ── 2. Script uses set -uo pipefail ──────────────────────────────────────────
@test "script uses set -uo pipefail" {
  run grep -E '^set -[uo]+ pipefail|^set -euo pipefail' "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── 3. --dry-run does NOT modify INDEX.md ────────────────────────────────────
@test "--dry-run does not modify INDEX.md" {
  local before
  before="$(md5sum "$INDEX" 2>/dev/null | awk '{print $1}')"
  run bash "$SCRIPT" --dry-run
  local after
  after="$(md5sum "$INDEX" 2>/dev/null | awk '{print $1}')"
  [ "$before" = "$after" ]
}

# ── 4. --write generates INDEX.md ≤150 lines ─────────────────────────────────
@test "--write generates INDEX.md with at most 150 lines" {
  run bash "$SCRIPT" --write
  [ "$status" -eq 0 ]
  local lines
  lines=$(wc -l < "$INDEX")
  [ "$lines" -le 150 ]
}

# ── 5. Generated INDEX.md has category sections ───────────────────────────────
@test "INDEX.md contains category sections after --write" {
  run bash "$SCRIPT" --write
  [ "$status" -eq 0 ]
  # Should contain at least one category header or table entry
  run grep -c 'agent-ops\|ai-governance\|autonomous-safety\|savia-core\|security\|skills' "$INDEX"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── 6. No entries in manifest point to non-existent files ─────────────────────
@test "manifest has 0 entries pointing to missing files after --write" {
  run bash "$SCRIPT" --write
  [ "$status" -eq 0 ]
  local missing
  missing=$(python3 -c "
import json, os, sys
manifest = json.load(open('$MANIFEST'))
rules = manifest.get('rules', {})
root = os.path.abspath('docs/rules/domain')
missing = []
for k in rules:
    path = os.path.join(root, k)
    if not os.path.isfile(path):
        missing.append(k)
print(len(missing))
" 2>/dev/null)
  [ "$missing" -eq 0 ]
}

# ── 7. All .md in docs/rules/domain/ are in manifest ─────────────────────────
@test "all .md files in docs/rules/domain/ are listed in manifest after --write" {
  run bash "$SCRIPT" --write
  [ "$status" -eq 0 ]
  local unlisted
  unlisted=$(python3 -c "
import json, os, glob
manifest = json.load(open('$MANIFEST'))
rules = set(manifest.get('rules', {}).keys())
root = 'docs/rules/domain'
missing = []
for f in glob.glob(os.path.join(root, '*.md')):
    bn = os.path.basename(f)
    if bn == 'INDEX.md':
        continue
    if bn not in rules:
        missing.append(bn)
# Also savia-enterprise subdir
for f in glob.glob(os.path.join(root, 'savia-enterprise', '*.md')):
    rel = 'savia-enterprise/' + os.path.basename(f)
    if rel not in rules:
        missing.append(rel)
print(len(missing))
" 2>/dev/null)
  [ "$unlisted" -eq 0 ]
}

# ── 8. --write is idempotent ──────────────────────────────────────────────────
@test "--write is idempotent (re-run produces same INDEX.md)" {
  run bash "$SCRIPT" --write
  [ "$status" -eq 0 ]
  local first
  first="$(md5sum "$INDEX" | awk '{print $1}')"
  run bash "$SCRIPT" --write
  [ "$status" -eq 0 ]
  local second
  second="$(md5sum "$INDEX" | awk '{print $1}')"
  [ "$first" = "$second" ]
}

# ── 9. rule-manifest-integrity.sh passes after --write ───────────────────────
@test "rule-manifest-integrity.sh returns PASS after --write" {
  run bash "$SCRIPT" --write
  [ "$status" -eq 0 ]
  run bash "$INTEGRITY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VERDICT: PASS"* ]]
}

# ── 10. Missing argument exits non-zero ──────────────────────────────────────
@test "running without arguments exits with error" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}
