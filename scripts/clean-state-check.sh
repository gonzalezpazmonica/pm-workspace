#!/usr/bin/env bash
# clean-state-check.sh — SE-407 S2: estado limpio al cerrar la sesión (advisory, nunca bloquea).
# Uso: bash scripts/clean-state-check.sh [--repo <ruta>]
# Tres dimensiones, cada una en su línea (PASS/WARN):
#   1. checkout principal sin cambios fuera de output/;
#   2. worktrees agent/* retirables: sin cambios y con todo su contenido ya en main
#      (funciona con squash merges: compara contenido, no ascendencia);
#   3. traspaso: commits en main posteriores a la última actualización de session-handoff.md.
# Salida: 0 siempre (advisory); 2 si --repo no es un repositorio git.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    *) echo "uso: clean-state-check.sh [--repo <ruta>]" >&2; exit 2 ;;
  esac
done
if ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: $REPO no es un repositorio git" >&2
  exit 2
fi

MAIN_REF=origin/main
git -C "$REPO" rev-parse -q --verify "$MAIN_REF" >/dev/null || MAIN_REF=main

# 1. Checkout principal: el primer worktree de la lista es el principal.
PRIMARY=$(git -C "$REPO" worktree list --porcelain | awk '/^worktree /{print substr($0, 10); exit}')
DIRTY=$(git -C "$PRIMARY" status --porcelain --untracked-files=all 2>/dev/null | awk '{p=substr($0, 4)} p !~ /^output\// {n++} END {print n+0}')
if [[ "$DIRTY" -eq 0 ]]; then
  echo "PASS Checkout principal limpio"
else
  echo "WARN Checkout principal: $DIRTY cambios fuera de output/ ($PRIMARY)"
fi

# 2. Worktrees agent/* retirables.
RETIRABLE=0
while IFS=$'\t' read -r path branch; do
  [[ "$branch" == agent/* ]] || continue
  [[ -z "$(git -C "$path" status --porcelain 2>/dev/null)" ]] || continue
  base=$(git -C "$REPO" merge-base "$MAIN_REF" "$branch" 2>/dev/null) || continue
  files=$(git -C "$REPO" diff --name-only "$base" "$branch")
  merged=false
  if [[ -z "$files" ]] || git -C "$REPO" diff --quiet "$MAIN_REF" "$branch" -- $files; then
    merged=true
  else
    # Squash merge seguido de otros cambios en los mismos ficheros: el diff completo de la
    # rama coincide (patch-id) con un commit de main posterior a la base (últimos 500).
    pid=$(git -C "$REPO" diff "$base" "$branch" | git patch-id --stable | cut -d' ' -f1)
    if [[ -n "$pid" ]] && git -C "$REPO" log -p -500 --format='commit %H' "$base..$MAIN_REF" \
        | git patch-id --stable | cut -d' ' -f1 | grep -qx "$pid"; then
      merged=true
    fi
  fi
  if $merged; then
    echo "WARN Worktree retirable: $branch ($path): su contenido ya está en main y no tiene cambios"
    RETIRABLE=$((RETIRABLE + 1))
  fi
done < <(git -C "$REPO" worktree list --porcelain | awk '
  /^worktree /{p=substr($0, 10)} /^branch refs\/heads\//{b=substr($0, 19); print p "\t" b}')
[[ "$RETIRABLE" -eq 0 ]] && echo "PASS Worktrees agent/*: ninguno retirable"

# 3. Traspaso de sesión.
HANDOFF=docs/propuestas/session-handoff.md
LAST=$(git -C "$REPO" log -1 --format=%H "$MAIN_REF" -- "$HANDOFF" 2>/dev/null)
if [[ -z "$LAST" ]]; then
  echo "WARN Traspaso: $HANDOFF no existe en $MAIN_REF"
else
  AFTER=$(git -C "$REPO" rev-list --count "$LAST..$MAIN_REF")
  if [[ "$AFTER" -gt 0 ]]; then
    echo "WARN Traspaso: $AFTER commit(s) en main desde la última actualización de session-handoff.md"
  else
    echo "PASS Traspaso al día"
  fi
fi
exit 0
