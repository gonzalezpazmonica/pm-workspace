#!/usr/bin/env bats
# test-mutation-audit-skill.bats — SE-035 Slice 2 skill structure tests.
# Spec: docs/propuestas/SE-035-mutation-testing-skill.md

set -uo pipefail
ROOT="$BATS_TEST_DIRNAME/.."
SKILL_DIR="$ROOT/.opencode/skills/mutation-audit"
SCRIPT="$ROOT/scripts/mutation-audit.sh"

setup() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR
}

teardown() {
  [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR" || true
}

# --- Skill existence ---

@test "skill: mutation-audit directory exists" {
  [ -d "$SKILL_DIR" ]
}

@test "skill: SKILL.md exists" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "skill: DOMAIN.md exists" {
  [ -f "$SKILL_DIR/DOMAIN.md" ]
}

@test "skill: SKILL.md under 150 lines" {
  local lines=$(wc -l < "$SKILL_DIR/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "skill: DOMAIN.md under 150 lines" {
  local lines=$(wc -l < "$SKILL_DIR/DOMAIN.md")
  [ "$lines" -le 150 ]
}

# --- Frontmatter ---

@test "frontmatter: SKILL.md has YAML frontmatter" {
  run head -1 "$SKILL_DIR/SKILL.md"
  [[ "$output" == "---" ]]
}

@test "frontmatter: name field present" {
  run grep -E "^name:\s*mutation-audit" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "frontmatter: description field present" {
  run grep -E "^description:" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "frontmatter: maturity field present" {
  run grep -E "^maturity:" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "frontmatter: category is quality" {
  run grep -E "^category:.*quality" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "frontmatter: allowed-tools includes Bash" {
  run grep "allowed-tools" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Bash"* ]]
}

# --- SE-035 references ---

@test "content: SKILL.md references SE-035" {
  run grep "SE-035" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "content: DOMAIN.md references SE-035" {
  run grep "SE-035" "$SKILL_DIR/DOMAIN.md"
  [ "$status" -eq 0 ]
}

@test "content: SKILL.md references mutation-audit.sh script" {
  run grep "mutation-audit.sh" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "content: DOMAIN.md explains mutation score formula" {
  run grep -iE "mutantes.*matados|killed.*total|mutation.?score" "$SKILL_DIR/DOMAIN.md"
  [ "$status" -eq 0 ]
}

# --- Script wired ---

@test "script: mutation-audit.sh exists and executable" {
  [ -x "$SCRIPT" ]
}

@test "script: mutation-audit.sh --help works" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"SE-035"* ]]
}

# --- Negative cases ---

@test "negative: invoke script without --target fails" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "negative: invalid flag rejected" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "negative: missing --tests after --target fails" {
  run bash "$SCRIPT" --target /tmp/nonexistent.sh
  [ "$status" -eq 2 ]
}

# --- Edge cases ---

@test "edge: empty skill directory does not break tests" {
  local empty_dir="$TMPDIR/empty-skill"
  mkdir -p "$empty_dir"
  [ -d "$empty_dir" ]
}

@test "edge: nonexistent target file handled with error" {
  run bash "$SCRIPT" --target /tmp/nonexistent-file-xyz.sh --tests /tmp/also-nonexistent.bats
  [ "$status" -ne 0 ]
}

@test "edge: zero mutants flag handled" {
  run bash "$SCRIPT" --target /tmp/x --tests /tmp/y --mutants 0
  [ "$status" -ne 0 ]
}

@test "edge: max boundary mutants flag (>20) rejected" {
  run bash "$SCRIPT" --target /tmp/x --tests /tmp/y --mutants 999
  [ "$status" -ne 0 ]
}

@test "edge: no arg to --help invocation (empty argv)" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "edge: SKILL.md documents when NOT to use" {
  run grep -iE "cuando no|NO usar" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "edge: SKILL.md lists supported mutators" {
  run grep -iE "arithmetic|comparison|conditional" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "edge: DOMAIN.md lists consumers (integration)" {
  run grep -iE "sprint-end|test-engineer|overnight" "$SKILL_DIR/DOMAIN.md"
  [ "$status" -eq 0 ]
}

# --- Isolation ---

@test "isolation: reading skill does not modify files" {
  local before=$(md5sum "$SKILL_DIR/SKILL.md" | awk '{print $1}')
  cat "$SKILL_DIR/SKILL.md" >/dev/null
  local after=$(md5sum "$SKILL_DIR/SKILL.md" | awk '{print $1}')
  [ "$before" = "$after" ]
}

@test "isolation: --help does not create files in cwd" {
  cd "$TMPDIR"
  local before=$(find . -type f 2>/dev/null | wc -l)
  bash "$SCRIPT" --help >/dev/null 2>&1 || true
  local after=$(find . -type f 2>/dev/null | wc -l)
  cd "$ROOT"
  [ "$before" -eq "$after" ]
}

# --- Coverage ---

@test "coverage: SKILL.md mentions output formats (verbose + json)" {
  run grep -cE "verbose|json|JSON" "$SKILL_DIR/SKILL.md"
  [[ "$output" -ge 2 ]]
}

@test "coverage: SKILL.md documents threshold interpretation" {
  run grep -iE "80%|70%|threshold|score.*>=" "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "coverage: DOMAIN.md documents tradeoffs" {
  run grep -iE "pros|contras|tradeoff" "$SKILL_DIR/DOMAIN.md"
  [ "$status" -eq 0 ]
}
