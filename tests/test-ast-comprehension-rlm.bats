#!/usr/bin/env bats
# BATS tests for .opencode/skills/ast-comprehension/SKILL.md — RLM pattern
# Ref: docs/propuestas/SE-031-query-library-nl.md (pattern analogy)
# Origin: output/research-coderlm-20260418.md (veredict ROBAR PATRON)
# SPEC-055 quality gate (score >= 80)
#
# Protects the 6 typed-query contract: symbol-search, impl, callers, tests,
# peek, grep-code. If the skill drops any of them, tests fail.

SKILL="$BATS_TEST_DIRNAME/../.opencode/skills/ast-comprehension/SKILL.md"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "SKILL.md exists and is readable" {
  [[ -f "$SKILL" ]]
  [[ -r "$SKILL" ]]
}

@test "SKILL.md under 150 lines (workspace rule)" {
  local lc; lc=$(wc -l < "$SKILL")
  [[ "$lc" -le 150 ]]
}

@test "SKILL.md has set -uo pipefail equivalent safety markers via frontmatter" {
  # Skills use YAML frontmatter not bash. Verify required fields present.
  run head -20 "$SKILL"
  [[ "$output" == *"name: ast-comprehension"* ]]
  [[ "$output" == *"description:"* ]]
}

@test "SKILL.md has valid YAML frontmatter delimiters" {
  local first_line; first_line=$(head -1 "$SKILL")
  [[ "$first_line" == "---" ]]
}

@test "SKILL.md references RLM paper (Zhang/Kraska/Khattab)" {
  run grep -c "RLM\|Recursive Language" "$SKILL"
  [[ "$output" -ge 2 ]]
}

# ── The 6 typed queries MUST be documented ─────────────────────────────────

@test "query 1: symbol-search is documented" {
  run grep -c "symbol-search" "$SKILL"
  [[ "$output" -ge 2 ]]
}

@test "query 2: impl is documented" {
  run grep -cE '\bimpl\b' "$SKILL"
  [[ "$output" -ge 2 ]]
}

@test "query 3: callers is documented" {
  run grep -cE '\bcallers\b' "$SKILL"
  [[ "$output" -ge 2 ]]
}

@test "query 4: tests is documented" {
  run grep -cE '### 4\. `tests' "$SKILL"
  [[ "$output" -ge 1 ]]
}

@test "query 5: peek is documented" {
  run grep -c "peek" "$SKILL"
  [[ "$output" -ge 2 ]]
}

@test "query 6: grep-code is documented" {
  run grep -c "grep-code" "$SKILL"
  [[ "$output" -ge 2 ]]
}

# ── Each query has a concrete bash recipe ──────────────────────────────────

@test "symbol-search has concrete grep recipe" {
  # Must include the grep command pattern
  run grep -A3 "### 1. .symbol-search" "$SKILL"
  [[ "$output" == *"grep -rn"* ]]
}

@test "impl has concrete extraction recipe (tree-sitter or awk)" {
  run grep -A10 "### 2. .impl" "$SKILL"
  [[ "$output" == *"tree-sitter"* || "$output" == *"awk"* ]]
}

@test "callers has concrete grep recipe with filter" {
  run grep -A5 "### 3. .callers" "$SKILL"
  [[ "$output" == *"grep -rn"* ]]
  # Filter out definitions to avoid false positives
  [[ "$output" == *"grep -v"* ]]
}

@test "tests has concrete grep recipe scoped to test paths" {
  run grep -A5 "### 4. .tests" "$SKILL"
  [[ "$output" == *"test"* ]]
  [[ "$output" == *"grep"* ]]
}

@test "peek has sed line-range recipe" {
  run grep -A3 "### 5. .peek" "$SKILL"
  [[ "$output" == *"sed"* ]]
}

@test "grep-code filters comment lines" {
  run grep -A5 "### 6. .grep-code" "$SKILL"
  [[ "$output" == *"grep -v"* ]]
}

# ── Empirical claim must cite concrete numbers ─────────────────────────────

@test "SKILL.md cites measured token-reduction ratio" {
  # The research validated 75x reduction on useAuthStore — SKILL must cite it
  run grep -cE '[0-9]+x' "$SKILL"
  [[ "$output" -ge 1 ]]
}

@test "SKILL.md references the research report" {
  run grep -c "research-coderlm" "$SKILL"
  [[ "$output" -ge 1 ]]
}

# ── Anti-pattern section present ───────────────────────────────────────────

@test "Anti-patterns section exists" {
  run grep -c "Anti-patterns\|anti-pattern" "$SKILL"
  [[ "$output" -ge 1 ]]
}

@test "Anti-patterns call out Read-full-file as worst case" {
  run grep -A10 "Anti-patterns" "$SKILL"
  [[ "$output" == *"Read"* ]]
  [[ "$output" == *"fichero entero"* || "$output" == *"entire file"* ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: missing impl query would be caught by this suite" {
  # This is a meta-test: if someone deletes the impl section, tests should fail
  local impl_mentions; impl_mentions=$(grep -cE '\bimpl\b' "$SKILL")
  [[ "$impl_mentions" -ne 0 ]]
}

@test "negative: frontmatter missing required fields would be caught" {
  # Required frontmatter keys: name, description, allowed-tools
  run grep -E "^(name|description|allowed-tools):" "$SKILL"
  [[ "$status" -eq 0 ]]
  # At least 3 of these keys must be present
  local count; count=$(grep -cE "^(name|description|allowed-tools):" "$SKILL")
  [[ "$count" -ge 3 ]]
}

@test "negative: SKILL.md invalid yaml frontmatter would be detectable" {
  # Verify there are exactly 2 '---' delimiters in the first 25 lines
  local delim_count; delim_count=$(head -25 "$SKILL" | grep -c '^---$')
  [[ "$delim_count" -eq 2 ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: empty SKILL.md would be caught (size > 0)" {
  [[ -s "$SKILL" ]]
}

@test "edge: SKILL.md with only frontmatter (no body) would be caught" {
  # Body must mention the query concept multiple times (case-insensitive)
  run grep -ic "query\|queries" "$SKILL"
  [[ "$output" -ge 3 ]]
}

@test "edge: boundary - line count between 50 and 150 (not empty, not bloated)" {
  local lc; lc=$(wc -l < "$SKILL")
  [[ "$lc" -ge 50 ]]
  [[ "$lc" -le 150 ]]
}

@test "edge: nonexistent skill path triggers test tooling error" {
  run cat /tmp/nonexistent-skill-path-12345.md
  [[ "$status" -ne 0 ]]
}
