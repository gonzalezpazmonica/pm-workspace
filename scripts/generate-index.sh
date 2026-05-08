#!/usr/bin/env bash
# generate-index.sh — Generate discoverable index of all workspace components
# Usage: bash scripts/generate-index.sh [--markdown | --json | --summary]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:---summary}"

count_glob() {
  local n=0
  for f in $1; do [ -e "$f" ] && n=$((n + 1)); done
  echo "$n"
}

# Gather stats
COMMANDS=$(count_glob "$ROOT/.opencode/commands/*.md")
SKILLS=$(count_glob "$ROOT/.opencode/skills/*/SKILL.md")
AGENTS=$(count_glob "$ROOT/.opencode/agents/*.md")
HOOKS=$(count_glob "$ROOT/.opencode/hooks/*.sh")
RULES_DOMAIN=$(count_glob "$ROOT/docs/rules/domain/*.md")
RULES_WORKFLOW=$(count_glob "$ROOT/docs/rules/workflow/*.md")
TESTS=$(count_glob "$ROOT/tests/hooks/*.bats")
TESTS_STRUCT=$(count_glob "$ROOT/tests/structure/*.bats")

STABLE=$(grep -rl "^maturity: stable" "$ROOT/.opencode/skills/"/*/SKILL.md 2>/dev/null | wc -l)
BETA=$(grep -rl "^maturity: beta" "$ROOT/.opencode/skills/"/*/SKILL.md 2>/dev/null | wc -l)
ALPHA=$(grep -rl "^maturity: alpha" "$ROOT/.opencode/skills/"/*/SKILL.md 2>/dev/null | wc -l)

if [ "$MODE" = "--summary" ]; then
  echo "═══════════════════════════════════════════════════"
  echo "  📚 pm-workspace Component Index"
  echo "═══════════════════════════════════════════════════"
  echo ""
  echo "  Commands:     $COMMANDS"
  echo "  Skills:       $SKILLS (🟢$STABLE 🟡$BETA 🔴$ALPHA)"
  echo "  Agents:       $AGENTS"
  echo "  Hooks:        $HOOKS"
  echo "  Rules:        $((RULES_DOMAIN + RULES_WORKFLOW)) (domain: $RULES_DOMAIN, workflow: $RULES_WORKFLOW)"
  echo "  Tests:        $((TESTS + TESTS_STRUCT)) BATS suites"
  echo ""
  echo "═══════════════════════════════════════════════════"

elif [ "$MODE" = "--json" ]; then
  cat <<JSON
{
  "generated": "$(date -Iseconds)",
  "components": {
    "commands": $COMMANDS,
    "skills": { "total": $SKILLS, "stable": $STABLE, "beta": $BETA, "alpha": $ALPHA },
    "agents": $AGENTS,
    "hooks": $HOOKS,
    "rules": { "domain": $RULES_DOMAIN, "workflow": $RULES_WORKFLOW },
    "tests": { "hooks": $TESTS, "structure": $TESTS_STRUCT }
  }
}
JSON

elif [ "$MODE" = "--markdown" ]; then
  echo "# pm-workspace Component Index"
  echo ""
  echo "> Auto-generated on $(date '+%Y-%m-%d')"
  echo ""
  echo "## Overview"
  echo ""
  echo "| Category | Count | Details |"
  echo "|----------|-------|---------|"
  echo "| Commands | $COMMANDS | Slash commands for PM workflows |"
  echo "| Skills | $SKILLS | $STABLE stable, $BETA beta, $ALPHA alpha |"
  echo "| Agents | $AGENTS | Specialized sub-agents |"
  echo "| Hooks | $HOOKS | PreToolUse validation hooks |"
  echo "| Rules | $((RULES_DOMAIN + RULES_WORKFLOW)) | $RULES_DOMAIN domain + $RULES_WORKFLOW workflow |"
  echo "| Tests | $((TESTS + TESTS_STRUCT)) | BATS test suites |"
  echo ""

  echo "## Skills by Maturity"
  echo ""
  for level in stable beta alpha; do
    emoji="🟢"; [ "$level" = "beta" ] && emoji="🟡"; [ "$level" = "alpha" ] && emoji="🔴"
    echo "### $emoji $(echo "$level" | tr '[:lower:]' '[:upper:]')"
    echo ""
    for f in "$ROOT/.claude/skills"/*/SKILL.md; do
      [ -f "$f" ] || continue
      if head -10 "$f" | grep -q "^maturity: $level"; then
        name=$(basename "$(dirname "$f")")
        desc=$(head -10 "$f" | grep "^description:" | sed 's/^description: *//' | sed 's/^"//' | sed 's/"$//')
        echo "- **$name** — $desc"
      fi
    done
    echo ""
  done

  echo "## Commands (top 20 by category)"
  echo ""
  for f in "$ROOT/.opencode/commands/"*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    desc=$(head -10 "$f" | grep "^description:" | sed 's/^description: *//' | head -1)
    [ -n "$desc" ] && echo "- \`/$name\` — $desc"
  done | head -20
  echo ""
  echo "*($(( COMMANDS - 20 )) more commands available)*"
fi
