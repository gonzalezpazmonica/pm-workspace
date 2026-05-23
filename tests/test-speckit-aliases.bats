#!/usr/bin/env bats
# Tests for SPEC-144 — /speckit.* slash command aliases
# Ref: docs/propuestas/SPEC-144-speckit-slash-aliases.md
# SCRIPT=.opencode/commands/speckit.specify.md
set -uo pipefail

REPO_ROOT="${BATS_TEST_DIRNAME}/.."
COMMANDS_DIR="$REPO_ROOT/.claude/commands"
OC_COMMANDS_DIR="$REPO_ROOT/.opencode/commands"
DOC_FILE="$REPO_ROOT/docs/agent-teams-sdd.md"

SPECKIT_COMMANDS=(
  "speckit.constitution"
  "speckit.specify"
  "speckit.clarify"
  "speckit.plan"
  "speckit.tasks"
  "speckit.analyze"
  "speckit.implement"
  "speckit.checklist"
)

setup() {
  TMPDIR=$(mktemp -d -t speckit-test-XXXXXX)
  export TMPDIR
}

teardown() {
  if [[ -n "${TMPDIR:-}" && -d "$TMPDIR" && "$TMPDIR" == */speckit-test-* ]]; then
    rm -rf "$TMPDIR"
  fi
}

# ── Positive cases ───────────────────────────────────────────────────────────

@test "AC-01: all 8 speckit command files exist in .claude/commands" {
  for cmd in "${SPECKIT_COMMANDS[@]}"; do
    [[ -f "$COMMANDS_DIR/$cmd.md" ]] || { echo "Missing: $cmd" >&2; return 1; }
  done
}

@test "AC-01: all 8 speckit command files exist in .opencode/commands" {
  for cmd in "${SPECKIT_COMMANDS[@]}"; do
    [[ -f "$OC_COMMANDS_DIR/$cmd.md" ]] || { echo "Missing: $cmd" >&2; return 1; }
  done
}

@test "AC-01: each speckit alias is concise (<=40 lines)" {
  for cmd in "${SPECKIT_COMMANDS[@]}"; do
    local lines
    lines=$(wc -l < "$COMMANDS_DIR/$cmd.md")
    [[ "$lines" -le 40 ]] || { echo "$cmd has $lines lines" >&2; return 1; }
  done
}

@test "AC-01: each speckit alias has YAML frontmatter name + description" {
  for cmd in "${SPECKIT_COMMANDS[@]}"; do
    local file="$COMMANDS_DIR/$cmd.md"
    head -1 "$file" | grep -q '^---$' || { echo "$cmd no frontmatter" >&2; return 1; }
    grep -q "^name:" "$file" || { echo "$cmd no name" >&2; return 1; }
    grep -q "^description:" "$file" || { echo "$cmd no description" >&2; return 1; }
  done
}

@test "AC-02: each alias documents its delegation target skill/agent" {
  declare -A DELEGATES=(
    [speckit.constitution]="savia-identity"
    [speckit.specify]="product-discovery"
    [speckit.clarify]="context-interview-conductor"
    [speckit.plan]="spec-driven-development"
    [speckit.tasks]="pbi-decomposition"
    [speckit.analyze]="consensus-validation"
    [speckit.implement]="dev-orchestrator"
    [speckit.checklist]="verification-lattice"
  )
  for cmd in "${!DELEGATES[@]}"; do
    grep -q "${DELEGATES[$cmd]}" "$COMMANDS_DIR/$cmd.md" || { echo "$cmd missing target" >&2; return 1; }
  done
}

@test "AC-02: each alias mentions spec-kit compatibility" {
  for cmd in "${SPECKIT_COMMANDS[@]}"; do
    grep -qi "spec-kit" "$COMMANDS_DIR/$cmd.md" || { echo "$cmd no spec-kit ref" >&2; return 1; }
  done
}

@test "AC-03: equivalence table exists in docs/agent-teams-sdd.md" {
  [[ -f "$DOC_FILE" ]]
  grep -q "spec-kit ↔ Savia" "$DOC_FILE" || { echo "table heading missing" >&2; return 1; }
}

@test "AC-03: equivalence table lists all 8 commands" {
  for cmd in "${SPECKIT_COMMANDS[@]}"; do
    grep -q "/$cmd" "$DOC_FILE" || { echo "$cmd not in table" >&2; return 1; }
  done
}

@test "AC-06: smart-routing discovers exactly 8 speckit commands by glob" {
  local count
  count=$(ls "$COMMANDS_DIR"/speckit.*.md 2>/dev/null | wc -l)
  [[ "$count" -eq 8 ]] || { echo "found $count, want 8" >&2; return 1; }
}

@test "AC-06: opencode mirror also exposes 8 speckit commands" {
  local count
  count=$(ls "$OC_COMMANDS_DIR"/speckit.*.md 2>/dev/null | wc -l)
  [[ "$count" -eq 8 ]] || { echo "opencode found $count, want 8" >&2; return 1; }
}

# ── Negative cases ───────────────────────────────────────────────────────────

@test "negative: unknown speckit.* alias does not exist (no rogue files)" {
  run ls "$COMMANDS_DIR/speckit.unknown.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No such file"* ]] || [[ "$output" == *"o existe"* ]] || [[ "$output" == *"cannot access"* ]]
}

@test "negative: missing frontmatter delimiter in fake alias is detected" {
  local fake="$TMPDIR/fake.md"
  echo "name: fake" > "$fake"
  run head -1 "$fake"
  [[ "$output" != "---" ]]
}

@test "negative: alias without delegation target fails grep check" {
  local fake="$TMPDIR/fake-no-target.md"
  printf -- "---\nname: speckit.fake\n---\nbody\n" > "$fake"
  run grep -q "savia-identity" "$fake"
  [ "$status" -ne 0 ]
}

@test "negative: alias missing spec-kit mention is rejected" {
  local fake="$TMPDIR/fake-no-spec-kit.md"
  printf -- "---\nname: speckit.fake\n---\nbody without keyword\n" > "$fake"
  run grep -qi "spec-kit" "$fake"
  [ "$status" -ne 0 ]
}

@test "negative: equivalence table heading missing in empty doc fails" {
  local fake_doc="$TMPDIR/empty-doc.md"
  : > "$fake_doc"
  run grep -q "spec-kit ↔ Savia" "$fake_doc"
  [ "$status" -ne 0 ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: empty alias file has zero lines (boundary, still under 40)" {
  local empty="$TMPDIR/empty.md"
  : > "$empty"
  local lines
  lines=$(wc -l < "$empty")
  [[ "$lines" -eq 0 ]]
  [[ "$lines" -le 40 ]]
}

@test "edge: boundary — alias of exactly 40 lines passes size check" {
  local boundary="$TMPDIR/boundary.md"
  for i in $(seq 1 40); do echo "line $i" >> "$boundary"; done
  local lines
  lines=$(wc -l < "$boundary")
  [[ "$lines" -eq 40 ]]
  [[ "$lines" -le 40 ]]
}

@test "edge: boundary — alias of 41 lines exceeds size cap" {
  local toobig="$TMPDIR/toobig.md"
  for i in $(seq 1 41); do echo "line $i" >> "$toobig"; done
  local lines
  lines=$(wc -l < "$toobig")
  [[ "$lines" -gt 40 ]]
}

@test "edge: nonexistent commands dir reports zero speckit aliases" {
  local missing="$TMPDIR/nonexistent-dir"
  local count
  count=$( { ls "$missing"/speckit.*.md 2>/dev/null || true; } | wc -l)
  [[ "$count" -eq 0 ]]
}

# ── Spec reference ───────────────────────────────────────────────────────────

@test "spec ref: SPEC-144 proposal document exists" {
  local spec="$REPO_ROOT/docs/propuestas/SPEC-144-speckit-slash-aliases.md"
  [[ -f "$spec" ]] || { echo "SPEC-144 missing" >&2; return 1; }
}
