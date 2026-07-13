#!/usr/bin/env bash
# agent-git-discipline.sh — SE-266: Block destructive git + shell ops for concurrent agent safety
# Extended from PR #906 to cover rm -rf, rm without confirmation, and other destructive ops.
# Inspired by Pi (earendil-works/pi AGENTS.md)
set -uo pipefail

INPUT=""
if INPUT=$(timeout 3 cat 2>/dev/null); then
  :
fi

COMMAND=""
if [[ -n "$INPUT" ]]; then
  COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""
fi

[[ -z "$COMMAND" ]] && exit 0

NORMALIZED=$(echo "$COMMAND" | sed 's/^[[:space:]]*//')

# ─── rm -rf / rm -r (recursive delete) ──────────────────────────────────
# Matches: rm -r, rm -rf, rm -fr, rm -R, rm --recursive
# Does NOT match: rm --interactive, rm -i (those are allowed)
if echo "$NORMALIZED" | grep -qE '(^|[;&|])([[:space:]]*sudo[[:space:]]+)?rm[[:space:]]+.*(\s-[a-zA-Z]*[rR][a-zA-Z]*\b|--recursive)'; then
  if echo "$NORMALIZED" | grep -qE '\s--interactive|\s-i\b'; then
    :
  else
    echo "BLOCKED [agent-git-discipline]: rm recursivo (rm -rf / rm -r)." >&2
    echo "  La eliminación recursiva requiere confirmación humana directa." >&2
    exit 2
  fi
fi

# ─── rm sin -i ni paths seguros (sin confirmación humana) ─────────────
if echo "$NORMALIZED" | grep -qE '(^|[;&|])([[:space:]]*sudo[[:space:]]+)?rm[[:space:]]+'; then
  SAFE_PATHS="/tmp/opencode|/tmp/recovery|/tmp/extundelete|/tmp/testdisk"
  if echo "$NORMALIZED" | grep -qE "$SAFE_PATHS"; then
    :
  elif echo "$NORMALIZED" | grep -qE '\-i[[:space:]]|--interactive'; then
    :
  else
    echo "BLOCKED [agent-git-discipline]: rm sin confirmación humana (-i / --interactive)." >&2
    echo "  Usa rm -i o elimina archivos desde tu terminal." >&2
    exit 2
  fi
fi

# ─── Truncado destructivo de archivos (> file, :> file) ────────────────
if echo "$NORMALIZED" | grep -qE '(^|[;&|])([[:space:]]*sudo[[:space:]]+)?(cat[[:space:]]+/dev/null|true|:)[[:space:]]*>[[:space:]]*(~|/home|/etc|/boot|/root)'; then
  echo "BLOCKED [agent-git-discipline]: truncado de archivos del sistema/usuario." >&2
  exit 2
fi

# ─── Escritura directa a dispositivos de bloque ────────────────────────
if echo "$NORMALIZED" | grep -qE '(^|[;&|])[[:space:]]*(sudo[[:space:]]+)?dd[[:space:]]+.*of=/dev/[sh]n?d'; then
  echo "BLOCKED [agent-git-discipline]: dd escribiendo a dispositivo de bloque." >&2
  exit 2
fi

if echo "$NORMALIZED" | grep -qE '(^|[;&|])[[:space:]]*(sudo[[:space:]]+)?mkfs\.'; then
  echo "BLOCKED [agent-git-discipline]: mkfs (formateo de disco)." >&2
  exit 2
fi

# ─── chown recursivo sobre home del usuario ────────────────────────────
if echo "$NORMALIZED" | grep -qE '(^|[;&|])[[:space:]]*(sudo[[:space:]]+)?chown[[:space:]]+-R[[:space:]]+.*(~|/home|/root)'; then
  echo "BLOCKED [agent-git-discipline]: chown -R sobre home del usuario." >&2
  exit 2
fi

# ═══════════════════════════════════════════════════════════════════════
# GIT destructive operations (SE-266 original, Pi-inspired)
# ═══════════════════════════════════════════════════════════════════════

if ! echo "$NORMALIZED" | grep -qE '^[[:space:]]*git[[:space:]]+'; then
  exit 0
fi

# ─── git reset --hard ───────────────────────────────────────────────────
if echo "$NORMALIZED" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
  echo "BLOCKED [agent-git-discipline]: git reset --hard — destruye todo el trabajo no commiteado." >&2
  exit 2
fi

# ─── git clean (bloquear todo menos dry-run) ────────────────────────────
if echo "$NORMALIZED" | grep -qE 'git[[:space:]]+clean'; then
  if echo "$NORMALIZED" | grep -qE 'clean[[:space:]].*(-[a-z]*n[a-z]*|-n|--dry-run)'; then
    :
  else
    echo "BLOCKED [agent-git-discipline]: git clean — elimina archivos no trackeados de todos los agentes." >&2
    echo "  Usa git clean -n o --dry-run para previsualizar primero." >&2
    exit 2
  fi
fi

# ─── git stash ──────────────────────────────────────────────────────────
if echo "$NORMALIZED" | grep -qE 'git[[:space:]]+stash'; then
  echo "BLOCKED [agent-git-discipline]: git stash oculta cambios staged de otros agentes." >&2
  echo "  Alternativa: commitea a tu rama agent/*." >&2
  exit 2
fi

# ─── git checkout . ─────────────────────────────────────────────────────
if echo "$NORMALIZED" | grep -qE 'git[[:space:]]+checkout[[:space:]]+\.'; then
  echo "BLOCKED [agent-git-discipline]: git checkout . destruye el working tree de todos los agentes." >&2
  exit 2
fi

# ─── git add -A / git add . (warn, no block) ────────────────────────────
if echo "$NORMALIZED" | grep -qE 'git[[:space:]]+add[[:space:]]+(-A|\.)[[:space:]]*$'; then
  echo "WARN [agent-git-discipline]: git add -A/. stagea archivos de otros agentes." >&2
  echo "  Usa: git add <path1> <path2>" >&2
fi

exit 0
