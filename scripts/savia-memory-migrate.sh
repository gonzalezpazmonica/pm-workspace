#!/bin/bash
# savia-memory-migrate.sh — migra memoria de silos internos/externos al store canónico
set -uo pipefail
# Idempotente (hash-check). Fail-safe: copia, nunca mueve. --cleanup-origin separado.

CLEANUP=false
DRY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cleanup-origin) CLEANUP=true; shift ;;
    --dry-run)        DRY=true; shift ;;
    *) echo "Uso: $0 [--dry-run] [--cleanup-origin]" >&2; exit 2 ;;
  esac
done

# ── Locate repo + target (usa el bootstrap como source of truth) ─────────────
REPO_ROOT=""
if command -v git >/dev/null 2>&1; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
fi
[ -z "$REPO_ROOT" ] && REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Ensure store exists (invoke bootstrap)
BOOT_OUT=$(bash "$REPO_ROOT/scripts/savia-memory-bootstrap.sh" 2>/dev/null | head -1)
TARGET=$(echo "$BOOT_OUT" | grep -oE '"target":"[^"]+"' | cut -d'"' -f4)
[ -z "$TARGET" ] && { echo "ERROR: bootstrap no devolvió target válido" >&2; exit 1; }

say() { echo "  $1"; }
do_copy() {
  local src="$1" dst="$2"
  if [ ! -e "$src" ]; then return 0; fi
  if $DRY; then say "[dry] cp -a $src  →  $dst"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ]; then
    # idempotent: skip if identical
    if diff -rq "$src" "$dst" >/dev/null 2>&1; then
      say "skip (idem)  $src"
      return 0
    fi
  fi
  cp -a "$src" "$dst" && say "copied     $src  →  ${dst#"$TARGET"/}"
}

echo "────────────────────────────────────────────────"
echo "  Migración memoria → $TARGET"
$DRY && echo "  MODO: dry-run (no escribe)"
$CLEANUP && echo "  MODO: cleanup-origin (borrará origen tras copia verificada)"
echo "────────────────────────────────────────────────"

# ── 1. Agent memory — public (está en git) ─────────────────────────────────
echo ""
echo "[1/6] public-agent-memory → agents/public/"
if [ -d "$REPO_ROOT/public-agent-memory" ]; then
  for d in "$REPO_ROOT/public-agent-memory"/*/; do
    [ -d "$d" ] && do_copy "$d" "$TARGET/agents/public/$(basename "$d")"
  done
fi

# ── 2. Agent memory — private (gitignored) ─────────────────────────────────
echo ""
echo "[2/6] private-agent-memory → agents/private/"
if [ -d "$REPO_ROOT/private-agent-memory" ]; then
  for d in "$REPO_ROOT/private-agent-memory"/*/; do
    [ -d "$d" ] && do_copy "$d" "$TARGET/agents/private/$(basename "$d")"
  done
fi

# ── 3. Agent memory — projects/*/agent-memory ──────────────────────────────
echo ""
echo "[3/6] projects/*/agent-memory → agents/projects/<proyecto>/"
if [ -d "$REPO_ROOT/projects" ]; then
  for pdir in "$REPO_ROOT/projects"/*/; do
    [ -d "$pdir/agent-memory" ] || continue
    proj=$(basename "$pdir")
    for adir in "$pdir/agent-memory"/*/; do
      [ -d "$adir" ] && do_copy "$adir" "$TARGET/agents/projects/$proj/$(basename "$adir")"
    done
  done
fi

# ── 4. JSONL store (output/.memory-store.jsonl) ────────────────────────────
echo ""
echo "[4/6] output/.memory-store.jsonl → jsonl-archive/"
JSONL="$REPO_ROOT/output/.memory-store.jsonl"
if [ -f "$JSONL" ]; then
  mkdir -p "$TARGET/jsonl-archive" 2>/dev/null
  do_copy "$JSONL" "$TARGET/jsonl-archive/memory-store-$(date +%Y%m%d).jsonl"
fi

# ── 5. ~/.savia/pm-radar/ (externo) ────────────────────────────────────────
echo ""
echo "[5/6] ~/.savia/pm-radar → pm-radar/"
SAVIA_HOME="${HOME:-}/.savia"
if [ -d "$SAVIA_HOME/pm-radar" ]; then
  do_copy "$SAVIA_HOME/pm-radar/state.json" "$TARGET/pm-radar/state.json"
  for f in "$SAVIA_HOME/pm-radar"/*; do
    [ -f "$f" ] && do_copy "$f" "$TARGET/pm-radar/$(basename "$f")"
  done
else
  say "skip (no existe $SAVIA_HOME/pm-radar)"
fi

# ── 6. ~/.claude/projects/<slug>/memory/ (Claude Code auto-memory) ─────────
echo ""
echo "[6/6] ~/.claude/projects/*/memory → auto/cc-archive/"
CC_BASE="${HOME:-}/.claude/projects"
if [ -d "$CC_BASE" ]; then
  for pdir in "$CC_BASE"/*/; do
    [ -d "$pdir/memory" ] || continue
    slug=$(basename "$pdir")
    do_copy "$pdir/memory" "$TARGET/auto/cc-archive/$slug"
  done
else
  say "skip (no existe $CC_BASE)"
fi

# ── Cleanup (opcional, requiere --cleanup-origin) ──────────────────────────
if $CLEANUP && ! $DRY; then
  echo ""
  echo "── cleanup-origin ─────────────────────────────────────────────"
  echo "  ATENCIÓN: borrando origen tras verificación de copia."
  echo "  public-agent-memory/ NO se borra (sigue en git, es canónica en repo)"
  for d in "$REPO_ROOT/private-agent-memory"/*/; do
    [ -d "$d" ] || continue
    tgt="$TARGET/agents/private/$(basename "$d")"
    if [ -d "$tgt" ] && diff -rq "$d" "$tgt" >/dev/null 2>&1; then
      rm -rf "$d" && say "removed    $d"
    fi
  done
fi

echo ""
echo "────────────────────────────────────────────────"
echo "  Migración completada"
echo "────────────────────────────────────────────────"
echo "  Target: $TARGET"
echo "  Auto:            $(find "$TARGET/auto"           -name '*.md' 2>/dev/null | wc -l) ficheros"
echo "  Agents/public:   $(find "$TARGET/agents/public"  -name '*.md' 2>/dev/null | wc -l) ficheros"
echo "  Agents/private:  $(find "$TARGET/agents/private" -name '*.md' 2>/dev/null | wc -l) ficheros"
echo "  Agents/projects: $(find "$TARGET/agents/projects" -name '*.md' 2>/dev/null | wc -l) ficheros"
echo "  JSONL archive:   $(find "$TARGET/jsonl-archive"   -name '*.jsonl' 2>/dev/null | wc -l) ficheros"
echo "  PM radar state:  $([ -f "$TARGET/pm-radar/state.json" ] && echo "sí" || echo "no")"
echo "────────────────────────────────────────────────"
