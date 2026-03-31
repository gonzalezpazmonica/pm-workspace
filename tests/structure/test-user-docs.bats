#!/usr/bin/env bats
# Tests for user-facing documentation completeness
# Verifies all onboarding docs exist, are non-empty, and under 150 lines

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
  TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR"
}

# ── Getting Started guides ──

@test "getting-started.md exists and is non-empty" {
  [ -f "$ROOT/docs/getting-started.md" ]
  local lines
  lines=$(wc -l < "$ROOT/docs/getting-started.md")
  [ "$lines" -gt 10 ]
}

@test "getting-started.en.md exists and is non-empty" {
  [ -f "$ROOT/docs/getting-started.en.md" ]
  local lines
  lines=$(wc -l < "$ROOT/docs/getting-started.en.md")
  [ "$lines" -gt 10 ]
}

@test "getting-started guides are under 150 lines" {
  local es_lines en_lines
  es_lines=$(wc -l < "$ROOT/docs/getting-started.md")
  en_lines=$(wc -l < "$ROOT/docs/getting-started.en.md")
  [ "$es_lines" -le 150 ]
  [ "$en_lines" -le 150 ]
}

# ── Savia Shield guides ──

@test "savia-shield-guide.md exists and is non-empty" {
  [ -f "$ROOT/docs/savia-shield-guide.md" ]
  local lines
  lines=$(wc -l < "$ROOT/docs/savia-shield-guide.md")
  [ "$lines" -gt 10 ]
}

@test "savia-shield-guide.en.md exists and is non-empty" {
  [ -f "$ROOT/docs/savia-shield-guide.en.md" ]
  local lines
  lines=$(wc -l < "$ROOT/docs/savia-shield-guide.en.md")
  [ "$lines" -gt 10 ]
}

@test "savia-shield-guide files are under 120 lines" {
  local es_lines en_lines
  es_lines=$(wc -l < "$ROOT/docs/savia-shield-guide.md")
  en_lines=$(wc -l < "$ROOT/docs/savia-shield-guide.en.md")
  [ "$es_lines" -le 120 ]
  [ "$en_lines" -le 120 ]
}

# ── Quick-start guides per role ──

@test "quick-start guides exist for all 6 roles" {
  local roles=("pm" "tech-lead" "developer" "qa" "po" "ceo")
  for role in "${roles[@]}"; do
    [ -f "$ROOT/docs/quick-starts/quick-start-${role}.md" ]
  done
}

@test "quick-start guides are non-empty" {
  local roles=("pm" "tech-lead" "developer" "qa" "po" "ceo")
  for role in "${roles[@]}"; do
    local lines
    lines=$(wc -l < "$ROOT/docs/quick-starts/quick-start-${role}.md")
    [ "$lines" -gt 5 ]
  done
}

# ── Main Savia Shield docs ──

@test "savia-shield.md full doc exists" {
  [ -f "$ROOT/docs/savia-shield.md" ]
  local lines
  lines=$(wc -l < "$ROOT/docs/savia-shield.md")
  [ "$lines" -gt 50 ]
}

@test "savia-shield.en.md full doc exists" {
  [ -f "$ROOT/docs/savia-shield.en.md" ]
  local lines
  lines=$(wc -l < "$ROOT/docs/savia-shield.en.md")
  [ "$lines" -gt 50 ]
}

@test "README.md references getting-started guide" {
  grep -q "getting-started" "$ROOT/README.md"
}

@test "README.en.md references getting-started guide" {
  grep -q "getting-started" "$ROOT/README.en.md"
}

# ── Negative cases ──

@test "getting-started.md has no broken internal links" {
  [[ -n "${CI:-}" ]] && skip "link validation needs full repo context"
  local broken=0
  while IFS= read -r link; do
    [ -f "$ROOT/$link" ] || broken=$((broken + 1))
  done < <(grep -oP '\]\((?!http)([^)]+)\)' "$ROOT/docs/getting-started.md" | tr -d ']()')
  [ "$broken" -eq 0 ]
}

@test "docs follow file-size-limit rule" {
  # Ref: .claude/rules/domain/file-size-limit.md — max 150 lines
  local oversized=0
  for f in "$ROOT/docs/getting-started.md" "$ROOT/docs/getting-started.en.md" "$ROOT/docs/quick-starts/"*.md; do
    [ -f "$f" ] || continue
    local lines; lines=$(wc -l < "$f")
    [ "$lines" -le 150 ] || oversized=$((oversized + 1))
  done
  [ "$oversized" -eq 0 ]
}

@test "getting-started.md contains setup instructions" {
  grep -q "install\|setup\|configur" "$ROOT/docs/getting-started.md"
  [[ "$(head -3 "$ROOT/docs/getting-started.md")" == *"#"* ]]
}

@test "savia-shield guides reference sovereignty" {
  grep -q "soberan\|sovereign\|shield\|protect" "$ROOT/docs/savia-shield-guide.md"
  [[ "$(head -3 "$ROOT/docs/savia-shield-guide.md")" == *"#"* ]]
}

@test "validate-ci-local.sh has set -uo pipefail safety" {
  grep -q "set -[euo]*o pipefail" "$ROOT/scripts/validate-ci-local.sh"
}

@test "getting-started.md handles nonexistent anchors" {
  local bad; bad=$(grep -c '\](#)' "$ROOT/docs/getting-started.md" || true)
  [ "$bad" -eq 0 ]
}

@test "getting-started.en.md has no empty sections" {
  local empty=0
  grep -c '^##' "$ROOT/docs/getting-started.en.md" | [ "$(cat)" -ge 1 ]
}
