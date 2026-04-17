#!/usr/bin/env bash
# claude-md-drift-check.sh — Valida que los conteos en CLAUDE.md coincidan con
# la realidad del workspace. Previene el patrón de "CLAUDE.md dice 56 agents
# pero hay 64" detectado en el audit 2026-04-17 (score 7.2/10).
#
# Ejecuta al arrancar sesión (readiness-check.sh) y en CI.
# Exit 0 si counts match, 2 si drift detectado.
# Ref: docs/propuestas/SPEC-109-savia-self-excellence.md (action 7)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
CLAUDE_MD="$ROOT/CLAUDE.md"

[[ -f "$CLAUDE_MD" ]] || { echo "ERROR: CLAUDE.md not found"; exit 2; }

# Real counts
REAL_AGENTS=$(ls "$ROOT"/.claude/agents/*.md 2>/dev/null | wc -l)
REAL_COMMANDS=$(ls "$ROOT"/.claude/commands/*.md 2>/dev/null | wc -l)
REAL_SKILLS=$(ls "$ROOT"/.claude/skills/*/SKILL.md 2>/dev/null | wc -l)
REAL_HOOKS=$(ls "$ROOT"/.claude/hooks/*.sh 2>/dev/null | wc -l)
REAL_HOOK_REGS=$(python3 -c "
import json
try:
    d = json.load(open('$ROOT/.claude/settings.json'))
    print(sum(len(m.get('hooks', [])) for lst in d.get('hooks', {}).values() for m in lst))
except Exception:
    print(0)
")

DRIFT=0
FINDINGS=""

# Check agents
if ! grep -qE "agents\($REAL_AGENTS\)" "$CLAUDE_MD"; then
  DRIFT=1
  FINDINGS+="  agents: CLAUDE.md does not reference real count $REAL_AGENTS\n"
fi

# Check commands
if ! grep -qE "commands\($REAL_COMMANDS\)" "$CLAUDE_MD"; then
  DRIFT=1
  FINDINGS+="  commands: CLAUDE.md does not reference real count $REAL_COMMANDS\n"
fi

# Check skills
if ! grep -qE "skills\($REAL_SKILLS\)" "$CLAUDE_MD"; then
  DRIFT=1
  FINDINGS+="  skills: CLAUDE.md does not reference real count $REAL_SKILLS\n"
fi

# Check hooks (allow "hooks(N)" OR "hooks(N/Mreg)" forms)
if ! grep -qE "hooks\($REAL_HOOKS" "$CLAUDE_MD"; then
  DRIFT=1
  FINDINGS+="  hooks: CLAUDE.md does not reference real count $REAL_HOOKS (on-disk)\n"
fi

# Check "Catálogo N agentes" in lazy reference table
if ! grep -qE "Catálogo $REAL_AGENTS agentes" "$CLAUDE_MD"; then
  DRIFT=1
  FINDINGS+="  Catálogo agentes: CLAUDE.md says different from $REAL_AGENTS\n"
fi

if [[ "$DRIFT" -eq 0 ]]; then
  echo "PASS: CLAUDE.md counts match reality"
  echo "  agents=$REAL_AGENTS, commands=$REAL_COMMANDS, skills=$REAL_SKILLS, hooks=$REAL_HOOKS ($REAL_HOOK_REGS regs)"
  exit 0
else
  echo "DRIFT DETECTED in CLAUDE.md:"
  printf "%b" "$FINDINGS"
  echo ""
  echo "Reality: agents=$REAL_AGENTS, commands=$REAL_COMMANDS, skills=$REAL_SKILLS, hooks=$REAL_HOOKS ($REAL_HOOK_REGS regs)"
  echo "Update CLAUDE.md to match, or this blocks CI."
  exit 2
fi
