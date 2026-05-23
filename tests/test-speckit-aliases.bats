#!/usr/bin/env bats
# Tests for SPEC-144 — /speckit.* slash command aliases
# Ref: docs/propuestas/SPEC-144-speckit-slash-aliases.md

REPO_ROOT="${BATS_TEST_DIRNAME}/.."
COMMANDS_DIR="$REPO_ROOT/.claude/commands"

# The 8 spec-kit alias commands
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

@test "AC-01: all 8 speckit command files exist" {
  for cmd in "${SPECKIT_COMMANDS[@]}"; do
    [[ -f "$COMMANDS_DIR/$cmd.md" ]] || {
      echo "Missing: $COMMANDS_DIR/$cmd.md" >&2
      return 1
    }
  done
}

@test "AC-01: each speckit alias is concise (<=40 lines)" {
  for cmd in "${SPECKIT_COMMANDS[@]}"; do
    local lines
    lines=$(wc -l < "$COMMANDS_DIR/$cmd.md")
    [[ "$lines" -le 40 ]] || {
      echo "$cmd has $lines lines (>40)" >&2
      return 1
    }
  done
}

@test "AC-01: each speckit alias has minimal YAML frontmatter" {
  for cmd in "${SPECKIT_COMMANDS[@]}"; do
    local file="$COMMANDS_DIR/$cmd.md"
    # Frontmatter delimiters present at start
    head -1 "$file" | grep -q '^---$' || {
      echo "$cmd missing opening frontmatter delimiter" >&2
      return 1
    }
    # Required fields
    grep -q "^name:" "$file" || {
      echo "$cmd missing 'name' field" >&2
      return 1
    }
    grep -q "^description:" "$file" || {
      echo "$cmd missing 'description' field" >&2
      return 1
    }
  done
}

@test "AC-02: each alias documents the delegation target skill or agent" {
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
    local file="$COMMANDS_DIR/$cmd.md"
    local target="${DELEGATES[$cmd]}"
    grep -q "$target" "$file" || {
      echo "$cmd does not reference delegation target '$target'" >&2
      return 1
    }
  done
}

@test "AC-02: each alias is marked as spec-kit compatible" {
  for cmd in "${SPECKIT_COMMANDS[@]}"; do
    grep -qi "spec-kit" "$COMMANDS_DIR/$cmd.md" || {
      echo "$cmd does not mention spec-kit compatibility" >&2
      return 1
    }
  done
}

@test "AC-03: equivalence table exists in docs/agent-teams-sdd.md" {
  local doc="$REPO_ROOT/docs/agent-teams-sdd.md"
  [[ -f "$doc" ]]
  grep -q "spec-kit ↔ Savia" "$doc" || {
    echo "Equivalence table heading missing" >&2
    return 1
  }
}

@test "AC-03: equivalence table lists all 8 commands" {
  local doc="$REPO_ROOT/docs/agent-teams-sdd.md"
  for cmd in "${SPECKIT_COMMANDS[@]}"; do
    grep -q "/$cmd" "$doc" || {
      echo "$cmd not in equivalence table" >&2
      return 1
    }
  done
}

@test "AC-06: smart-routing can discover speckit commands by glob" {
  # Convention: smart-routing skill enumerates commands by glob over .claude/commands/
  local count
  count=$(ls "$COMMANDS_DIR"/speckit.*.md 2>/dev/null | wc -l)
  [[ "$count" -eq 8 ]] || {
    echo "Expected 8 speckit.* files, found $count" >&2
    return 1
  }
}
