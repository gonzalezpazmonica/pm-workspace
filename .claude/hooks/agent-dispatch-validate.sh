#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# ────────────────────────────────────────────────────────────────────────────
# PreToolUse Hook: agent-dispatch-validate.sh
# Valida que los prompts enviados a subagentes contengan contexto requerido.
# Previene que agentes creen ficheros sin cumplir convenciones del proyecto.
# Profile tier: strict
# ────────────────────────────────────────────────────────────────────────────

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "strict"
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Solo aplica al tool Task (subagentes)
if [ "$TOOL_NAME" != "Task" ]; then
  exit 0
fi

PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty')
if [ -z "$PROMPT" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CHECKLIST="$PROJECT_DIR/docs/rules/domain/agent-dispatch-checklist.md"
WARNINGS=""
ERRORS=""

# ── Helper: comprobar si el prompt menciona un patrón ──────────────────
prompt_contains() {
  echo "$PROMPT" | grep -qiE "$1"
}

# ── 1. Si el agente va a crear commands (.opencode/commands/) ────────────
if prompt_contains 'commands/.*\.md|crear.*command|create.*command'; then
  if ! prompt_contains 'name:|^name:|frontmatter.*name'; then
    ERRORS+="⚠ DISPATCH: prompt crea commands pero no menciona campo 'name' en frontmatter.\n"
    ERRORS+="  Añadir al prompt: 'Frontmatter obligatorio: name, description'\n"
  fi
  if ! prompt_contains 'description:|frontmatter'; then
    ERRORS+="⚠ DISPATCH: prompt crea commands sin mencionar frontmatter requerido.\n"
  fi
  # Sugerir incluir ejemplo de comando existente
  if ! prompt_contains 'ejemplo|example|como.*existente|existing.*pattern|head.*commands'; then
    WARNINGS+="💡 DISPATCH: prompt crea commands sin referenciar un ejemplo existente como modelo.\n"
  fi
fi

# ── 2. Si el agente va a modificar CHANGELOG.md ───────────────────────
if prompt_contains 'CHANGELOG|changelog'; then
  if ! prompt_contains 'versión actual|current version|última versión|latest version|top|inicio'; then
    WARNINGS+="💡 DISPATCH: prompt modifica CHANGELOG sin indicar leer la versión actual primero.\n"
  fi
  if ! prompt_contains 'descendente|descending|orden|order'; then
    ERRORS+="⚠ DISPATCH: prompt modifica CHANGELOG sin mencionar orden descendente de versiones.\n"
  fi
  if ! prompt_contains 'solo insertar|only insert|no reemplazar|nunca reemplazar|append|prepend'; then
    ERRORS+="⚠ DISPATCH: prompt modifica CHANGELOG sin prohibir reemplazo completo del fichero.\n"
  fi
fi

# ── 3. Si el agente va a crear skills (.opencode/skills/) ───────────────
if prompt_contains 'skills/.*SKILL\.md|crear.*skill|create.*skill'; then
  if ! prompt_contains '150 líneas|150 lines|max.*150|≤.*150'; then
    WARNINGS+="💡 DISPATCH: prompt crea skills sin mencionar límite de 150 líneas.\n"
  fi
  if ! prompt_contains 'DOMAIN\.md|domain.*doc|clara.*philosophy'; then
    WARNINGS+="💡 DISPATCH: prompt crea skill sin mencionar DOMAIN.md (Clara Philosophy).\n"
  fi
fi

# ── 4. Si el agente va a hacer git push/PR/merge ─────────────────────
if prompt_contains 'git push|gh pr|merge'; then
  if ! prompt_contains 'validate-ci-local|pipeline|CI|lint'; then
    WARNINGS+="💡 DISPATCH: prompt incluye push/PR sin mencionar validación CI local previa.\n"
  fi
fi

# ── 5. Si el agente va a crear rules (docs/rules/) ────────────────
if prompt_contains 'rules/.*\.md|crear.*rule|create.*rule'; then
  if ! prompt_contains '150 líneas|150 lines|max.*150|≤.*150'; then
    WARNINGS+="💡 DISPATCH: prompt crea rules sin mencionar límite de líneas.\n"
  fi
fi

# ── Output ─────────────────────────────────────────────────────────────
if [ -n "$ERRORS" ] || [ -n "$WARNINGS" ]; then
  echo "" >&2
  echo "═══ Agent Dispatch Validation ═══" >&2
  if [ -n "$ERRORS" ]; then
    echo -e "$ERRORS" >&2
  fi
  if [ -n "$WARNINGS" ]; then
    echo -e "$WARNINGS" >&2
  fi
  echo "Ref: docs/rules/domain/agent-dispatch-checklist.md" >&2
  echo "═════════════════════════════════" >&2

  # Errores bloquean (exit 2), warnings solo informan (exit 0)
  if [ -n "$ERRORS" ]; then
    exit 2
  fi
fi

exit 0
