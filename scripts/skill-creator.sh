#!/usr/bin/env bash
# skill-creator.sh — SE-270 Slice 3 — Interactive skill scaffolding
#
# Creates a new skill in .opencode/skills/{name}/ with:
#   - SKILL.md (YAML frontmatter with routing-ready description, tier: extended)
#   - references/ directory
#   - Placeholder test case
#   - DOMAIN.md skeleton
#
# Usage:
#   bash scripts/skill-creator.sh <skill-name>
#   bash scripts/skill-creator.sh <skill-name> --description "desc" --tier core
#   bash scripts/skill-creator.sh <skill-name> --from-template  # interactive
#
# Exit 0 on success.
# Ref: SE-270

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -n "${SAVIA_SKILLS_DIR:-}" ]]; then
  SKILLS_DIR="$SAVIA_SKILLS_DIR"
else
  SKILLS_DIR="$(cd -P "$ROOT/.opencode/skills" && pwd)"
fi

# ── Parse args ─────────────────────────────────────────────────────────────────
SKILL_NAME="${1:-}"
SKILL_DESC="${2:-}"
SKILL_TIER="extended"
FROM_TEMPLATE=false

if [[ -z "$SKILL_NAME" || "$SKILL_NAME" == "--help" || "$SKILL_NAME" == "-h" ]]; then
  echo "Usage: $0 <skill-name> [--description \"desc\"] [--tier core|extended] [--from-template]"
  echo ""
  echo "  skill-name       kebab-case name (e.g. my-new-skill)"
  echo "  --description    skill description (200-400 chars recommended)"
  echo "  --tier           core or extended (default: extended)"
  echo "  --from-template  copy from _template/ instead of generating"
  exit 1
fi

# Validate kebab-case
if ! echo "$SKILL_NAME" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
  echo "ERROR: skill name must be kebab-case (e.g. my-new-skill)" >&2
  exit 1
fi

# Shift past skill name
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --description) shift; SKILL_DESC="${1:-}" ;;
    --tier)       shift; SKILL_TIER="${1:-extended}"
                   if [[ "$SKILL_TIER" != "core" && "$SKILL_TIER" != "extended" ]]; then
                     echo "ERROR: --tier must be 'core' or 'extended'" >&2
                     exit 1
                   fi ;;
    --from-template) FROM_TEMPLATE=true ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

# ── Check target doesn't exist ─────────────────────────────────────────────────
SKILL_DIR="$SKILLS_DIR/$SKILL_NAME"
if [[ -d "$SKILL_DIR" ]]; then
  echo "ERROR: skill directory already exists: $SKILL_DIR" >&2
  exit 1
fi

# ── Generate description if not provided ──────────────────────────────────────
HUMAN_NAME="$(echo "$SKILL_NAME" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')"
if [[ -z "$SKILL_DESC" ]]; then
  SKILL_DESC="Usar cuando se necesita $HUMAN_NAME. Describe propósito concreto, triggers, y outputs."
fi

DATE_STAMP="$(date +%Y-%m-%d)"

# ── Create directory structure ────────────────────────────────────────────────
mkdir -p "$SKILL_DIR/references"
echo "Created: $SKILL_DIR/"

# ── Generate SKILL.md ─────────────────────────────────────────────────────────
cat > "$SKILL_DIR/SKILL.md" <<SKILLEOF
---
name: $SKILL_NAME
description: "$SKILL_DESC"
maturity: stub
context: standalone
context_cost: low
category: "utility"
tags: []
priority: "low"
tier: $SKILL_TIER
consumes: []
produces: []
trigger:
  keywords: [$SKILL_NAME]
---

# Skill: $HUMAN_NAME

<Propósito en una frase. Qué problema resuelve.>

## Authoritative Paths

| Para | Lee este path |
|---|---|
| Referencias | \`references/\` |

## Cuándo usar

- <Trigger 1>
- <Trigger 2>
- <Trigger 3>

## Workflow

1. **Input**: <qué input espera>
2. **Procesamiento**: <lógica principal>
3. **Output**: <qué genera>

## Outputs esperados

- <Fichero / artefacto>

## Related

- Rule: \`docs/rules/domain/\`
SKILLEOF

echo "Created: $SKILL_DIR/SKILL.md"

# ── Generate DOMAIN.md ─────────────────────────────────────────────────────────
cat > "$SKILL_DIR/DOMAIN.md" <<DOMAINEOF
---
name: $SKILL_NAME
---

# Domain: $HUMAN_NAME

<Definir términos de dominio relevantes para esta skill.>
DOMAINEOF

echo "Created: $SKILL_DIR/DOMAIN.md"

# ── Generate placeholder test case ─────────────────────────────────────────────
TEST_FILE="$ROOT/tests/test-se-270-skill-${SKILL_NAME}.bats"
if [[ ! -f "$TEST_FILE" ]]; then
  cat > "$TEST_FILE" <<TESTEOF
#!/usr/bin/env bats
# tests/test-se-270-skill-${SKILL_NAME}.bats
# SE-270 Slice 3 — Activation cases for skill: $SKILL_NAME

SKILL_NAME="$SKILL_NAME"
SKILL_DIR=".opencode/skills/\$SKILL_NAME"

setup() {
  cd "\$(dirname "\${BATS_TEST_FILENAME}")/.."
}

@test "SE-270: $SKILL_NAME SKILL.md exists" {
  [[ -f "\$SKILL_DIR/SKILL.md" ]]
}

@test "SE-270: $SKILL_NAME DOMAIN.md exists" {
  [[ -f "\$SKILL_DIR/DOMAIN.md" ]]
}

@test "SE-270: $SKILL_NAME has valid frontmatter" {
  run grep -c '^name: $SKILL_NAME' "\$SKILL_DIR/SKILL.md"
  [[ "\$output" -ge 1 ]]
}

@test "SE-270: $SKILL_NAME description exists" {
  run grep -c '^description:' "\$SKILL_DIR/SKILL.md"
  [[ "\$output" -ge 1 ]]
}

@test "SE-270: $SKILL_NAME references/ directory exists" {
  [[ -d "\$SKILL_DIR/references" ]]
}
TESTEOF
  echo "Created: $TEST_FILE"
else
  echo "Skipped (already exists): $TEST_FILE"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "Skill '$SKILL_NAME' scaffolded successfully."
echo "  Directory:  $SKILL_DIR/"
echo "  Tier:       $SKILL_TIER"
echo "  Test file:  $TEST_FILE"
echo ""
echo "Next steps:"
echo "  1. Edit $SKILL_DIR/SKILL.md — write the real description and workflow"
echo "  2. Run: bash scripts/skills-lint.sh --skill $SKILL_NAME"
echo "  3. Run: bash scripts/skills-tier-audit.sh"
