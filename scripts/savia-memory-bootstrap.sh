#!/bin/bash
# savia-memory-bootstrap.sh — crea store externo canónico ../.savia-memory/
set -uo pipefail
# OS-agnostic: solo paths relativos al repo. Idempotente.
# Fail-safe: parent no escribible → {repo}/.savia-memory/ → $HOME/.savia-memory/
# Invocado desde session-init.sh (SessionStart) o manual.

# ── Locate repo root (portable: works under git OR raw clone) ────────────────
REPO_ROOT=""
if command -v git >/dev/null 2>&1; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
fi
if [ -z "$REPO_ROOT" ]; then
  # Fallback: walk up from script location
  REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fi

PARENT_DIR=$(cd "$REPO_ROOT/.." && pwd)
CANONICAL="$PARENT_DIR/.savia-memory"
REPO_LOCAL="$REPO_ROOT/.savia-memory"
HOME_FALLBACK="${HOME:-/tmp}/.savia-memory"

TARGET=""
MODE=""

# ── Decide target in priority order ──────────────────────────────────────────
# 1) ../.savia-memory/  (canónico, parent-relative)
# 2) {repo}/.savia-memory/  (fallback sandbox, gitignored)
# 3) $HOME/.savia-memory/  (último recurso)

try_path() {
  local path="$1"
  # Reject dangerous roots
  case "$path" in
    /|/.savia-memory|C:|C:/|C:/.savia-memory) return 1 ;;
  esac
  # Can we create it? (writable parent OR already exists and writable)
  if mkdir -p "$path" 2>/dev/null && [ -w "$path" ]; then
    echo "$path"
    return 0
  fi
  return 1
}

if T=$(try_path "$CANONICAL"); then
  TARGET="$T"; MODE="canonical"
elif T=$(try_path "$REPO_LOCAL"); then
  TARGET="$T"; MODE="repo-local"
elif T=$(try_path "$HOME_FALLBACK"); then
  TARGET="$T"; MODE="home-fallback"
else
  echo "savia-memory-bootstrap: no writable target found" >&2
  exit 1
fi

# ── Create canonical layout (idempotent) ─────────────────────────────────────
mkdir -p "$TARGET"/{auto,sessions,projects,agents/public,agents/private,agents/projects,pm-radar}
# shield-maps is special: strict perms
mkdir -p "$TARGET/shield-maps"
chmod 700 "$TARGET/shield-maps" 2>/dev/null || true

# ── Schema files ─────────────────────────────────────────────────────────────
if [ ! -f "$TARGET/VERSION" ]; then
  echo "1" > "$TARGET/VERSION"
fi

if [ ! -f "$TARGET/README.md" ]; then
  cat > "$TARGET/README.md" <<'READMEEOF'
# .savia-memory — Canonical External Memory Store

Este directorio vive FUERA del repo Savia (parent-relative) para que:
- No se toque al hacer `git clean`, cambio de rama o reclonar el repo
- Persista entre sesiones Claude Code y Cowork
- Funcione idéntico en Windows, macOS y Linux

## Layout

```
.savia-memory/
├── auto/              memoria auto (user/feedback/project/reference)
├── sessions/          snapshots de sesión
├── projects/          memoria por proyecto PM
├── agents/            memoria de agentes (public/private/projects)
├── shield-maps/       mapas mask/unmask Shield (N4, chmod 700)
└── pm-radar/          state.json del radar PM
```

## No tocar a mano

Escritura vía `scripts/memory-store.sh` o `session-end-memory.sh`.
Lectura automática vía `@.claude/external-memory/...` resuelto por CLAUDE.md raíz.

Ver `docs/propuestas/SPEC-110-memoria-externa-canonica.md`.
READMEEOF
fi

# Seed MEMORY.md skeleton si no existe
if [ ! -f "$TARGET/auto/MEMORY.md" ]; then
  cat > "$TARGET/auto/MEMORY.md" <<'MEMEOF'
# MEMORY Index

> Índice de memoria auto del usuario activo. Cada línea apunta a un fichero individual en este directorio.
> Hard cap: 200 líneas / 25 KB. Entradas <150 caracteres.

<!-- ENTRIES_START -->
<!-- ENTRIES_END -->
MEMEOF
fi

# ── Symlink .claude/external-memory → $TARGET ────────────────────────────────
LINK="$REPO_ROOT/.claude/external-memory"
mkdir -p "$(dirname "$LINK")"

# Compute relative path from $(dirname $LINK) to $TARGET (only when canonical or repo-local)
relpath() {
  local from="$1" to="$2"
  python3 -c "import os; print(os.path.relpath('$to', '$from'))" 2>/dev/null \
    || echo "$to"
}

if [ -L "$LINK" ]; then
  CURR=$(readlink "$LINK")
  # Re-link if pointing elsewhere
  if [ "$CURR" != "$(relpath "$(dirname "$LINK")" "$TARGET")" ] && [ "$CURR" != "$TARGET" ]; then
    rm "$LINK"
  fi
fi

if [ ! -e "$LINK" ]; then
  REL=$(relpath "$(dirname "$LINK")" "$TARGET")
  if ln -s "$REL" "$LINK" 2>/dev/null; then
    :
  elif ln -s "$TARGET" "$LINK" 2>/dev/null; then
    :
  else
    # Windows without Dev Mode: no symlinks available.
    # Create a marker file so the hook can show fallback mode.
    echo "$TARGET" > "$REPO_ROOT/.claude/external-memory-target"
  fi
fi

# Write target marker (gitignored) for debug
echo "$TARGET" > "$REPO_ROOT/.claude/external-memory-target"
echo "$MODE"  >> "$REPO_ROOT/.claude/external-memory-target"

# ── Report (JSON line for hook consumption) ──────────────────────────────────
printf '{"target":"%s","mode":"%s","link":"%s"}\n' "$TARGET" "$MODE" "$LINK"
exit 0
