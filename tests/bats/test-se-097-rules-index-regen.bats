#!/usr/bin/env bats
# test-se-097-rules-index-regen.bats — SE-097: Rules INDEX.md regeneration
# Verifies the rules-index-generate.sh script and generated INDEX.md.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/rules-index-generate.sh"
INDEX="$REPO_ROOT/docs/rules/INDEX.md"

@test "SE-097: rules-index-generate.sh script exists and is executable" {
  [ -f "$SCRIPT" ] || fail "Script missing: $SCRIPT"
  [ -x "$SCRIPT" ] || fail "Script not executable: $SCRIPT"
}

@test "SE-097: INDEX.md has correct auto-generated header with date and rule count" {
  [ -f "$INDEX" ] || fail "INDEX.md missing: $INDEX"
  # Header format: # Rules Index — auto-generated YYYY-MM-DD · N rules
  head -1 "$INDEX" | grep -qE '^# Rules Index — auto-generated [0-9]{4}-[0-9]{2}-[0-9]{2} · [0-9]+ rules$' \
    || fail "Header format wrong: $(head -1 "$INDEX")"
}

@test "SE-097: INDEX.md table has required columns (context_tier, file, title, spec)" {
  [ -f "$INDEX" ] || fail "INDEX.md missing: $INDEX"
  # Table header row must contain all four columns
  grep -qE '^\| context_tier \| file \| title \| spec \|' "$INDEX" \
    || fail "Table header missing required columns. Found: $(grep '^\| context_tier' "$INDEX" || echo 'no header row')"
  # Must have at least some data rows (pipe-delimited)
  row_count=$(grep -cE '^\| (L[0-9]|—) \| ' "$INDEX" || true)
  [ "$row_count" -ge 50 ] || fail "Too few data rows: $row_count (expected >= 50)"
}

@test "SE-097: --check mode exits 0 when INDEX.md is up-to-date" {
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "up-to-date"
}
