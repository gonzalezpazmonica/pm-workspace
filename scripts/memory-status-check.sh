#!/usr/bin/env bash
# memory-status-check.sh — Tabla de estado de todas las capas de memoria de Savia
# Uso: bash scripts/memory-status-check.sh [--markdown]
# Output: tabla ASCII o Markdown con estado L0-L4 + agentes + vault + hooks
# Confidencialidad: solo muestra metadatos (conteo, tamaño, paths). NUNCA contenido.

set -uo pipefail

MODE="${1:-}"
ROOT="${PM_WORKSPACE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"
HOME_DIR="${HOME:-/root}"

# ── Helpers ────────────────────────────────────────────────────────────────────
ok()   { echo "OK $*"; }
warn() { echo "WARN $*"; }
fail() { echo "FAIL $*"; }

# portable_mtime: portable equivalent of 'date -r file +%Y-%m-%d' — works on GNU/Linux, macOS/BSD and Windows Git bash
portable_mtime() {
  local f="$1"
  stat -c "%y" "$f" 2>/dev/null | cut -d' ' -f1 ||  # GNU/Linux / Git bash
  stat -f "%Sm" -t "%Y-%m-%d" "$f" 2>/dev/null ||    # macOS/BSD
  echo "—"
}

file_status() {
  local path="$1" label="${2:-}"
  if [[ -f "$path" ]]; then
    local lines size
    lines=$(wc -l < "$path" 2>/dev/null || echo "?")
    size=$(wc -c < "$path" 2>/dev/null || echo "?")
    local size_kb=$(( size / 1024 ))
    echo "$(ok "${label:-$path}") · ${lines} líneas · ${size_kb}KB"
  else
    echo "$(fail "${label:-$path}") · no existe"
  fi
}

dir_status() {
  local path="$1" label="${2:-}"
  if [[ -d "$path" ]]; then
    local count
    count=$(find "$path" -name "*.md" -o -name "*.jsonl" 2>/dev/null | wc -l || echo "?")
    echo "$(ok "${label:-$path}") · ${count} ficheros"
  else
    echo "$(fail "${label:-$path}") · no existe"
  fi
}

# ── L0: Índice canónico ────────────────────────────────────────────────────────
L0_PATH="$ROOT/.claude/external-memory/auto/MEMORY.md"
L0_LINES=$(wc -l < "$L0_PATH" 2>/dev/null || echo "?")
L0_ENTRIES=$(grep -c '^- ' "$L0_PATH" 2>/dev/null || echo "0")
if [[ -f "$L0_PATH" ]]; then
  L0_STATUS="$(ok "ok") · ${L0_ENTRIES} entradas · ${L0_LINES} líneas"
else
  L0_STATUS="$(fail "no existe")"
fi

# ── L1: Session snapshots ──────────────────────────────────────────────────────
L1_PATH="$HOME_DIR/.savia-memory/sessions"
if [[ -d "$L1_PATH" ]]; then
  L1_COUNT=$(find "$L1_PATH" -maxdepth 2 -name "*.md" 2>/dev/null | wc -l || echo "0")
  L1_LAST=$(find "$L1_PATH" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1 | xargs basename 2>/dev/null || echo "—")
  L1_STATUS="$(ok "ok") · ${L1_COUNT} snapshots · última: ${L1_LAST}"
else
  L1_STATUS="$(warn "directorio vacío")"
fi

# ── L2: JSONL store ───────────────────────────────────────────────────────────
L2_PATH="$ROOT/output/.memory-store.jsonl"
if [[ -f "$L2_PATH" ]]; then
  L2_ENTRIES=$(wc -l < "$L2_PATH" 2>/dev/null || echo "?")
  L2_SIZE=$(wc -c < "$L2_PATH" 2>/dev/null || echo "0")
  L2_SIZE_KB=$(( L2_SIZE / 1024 ))
  L2_LAST=$(tail -1 "$L2_PATH" 2>/dev/null | grep -o '"ts":"[^"]*"' | cut -d'"' -f4 | cut -c1-10 || echo "—")
  L2_STATUS="$(ok "ok") · ${L2_ENTRIES} entradas · ${L2_SIZE_KB}KB · última: ${L2_LAST}"
else
  L2_STATUS="$(fail "no existe") · bash scripts/memory-store.sh save ..."
fi

# ── L3: SQLite cache ──────────────────────────────────────────────────────────
L3_PATH="$HOME_DIR/.savia/memory-cache.db"
if [[ -f "$L3_PATH" ]]; then
  L3_SIZE=$(wc -c < "$L3_PATH" 2>/dev/null || echo "0")
  L3_SIZE_KB=$(( L3_SIZE / 1024 ))
  L3_MTIME=$(portable_mtime "$L3_PATH")
  L3_STATUS="$(ok "ok") · ${L3_SIZE_KB}KB · actualizado: ${L3_MTIME}"
else
  L3_STATUS="$(fail "no existe") · bash scripts/memory-cache-rebuild.sh"
fi

# ── L4: Session context (RAM) ────────────────────────────────────────────────
L4_STATUS="$(ok "activo") · sesión en curso"

# ── Agentes: memoria pública ──────────────────────────────────────────────────
PUB_PATH="$ROOT/public-agent-memory"
if [[ -d "$PUB_PATH" ]]; then
  PUB_COUNT=$(find "$PUB_PATH" -name "MEMORY.md" 2>/dev/null | wc -l || echo "0")
  PUB_STATUS="$(ok "ok") · ${PUB_COUNT} agentes"
else
  PUB_STATUS="$(fail "no existe")"
fi

# ── Agentes: memoria privada ──────────────────────────────────────────────────
PRV_PATH="$ROOT/private-agent-memory"
if [[ -d "$PRV_PATH" ]]; then
  PRV_COUNT=$(find "$PRV_PATH" -name "MEMORY.md" 2>/dev/null | wc -l || echo "0")
  PRV_STATUS="$(ok "N2") · ${PRV_COUNT} agentes"
else
  PRV_STATUS="$(fail "no existe")"
fi

# ── Vault Obsidian — buscar proyecto activo con vault ────────────────────────
VAULT_PATH=""
VAULT_PROJECT=""
for proj_dir in "$ROOT/projects"/*/; do
  if [[ -d "${proj_dir}.obsidian" ]]; then
    VAULT_PATH="${proj_dir%/}"
    VAULT_PROJECT=$(basename "$VAULT_PATH")
    break
  fi
done
if [[ -n "$VAULT_PATH" && -d "$VAULT_PATH/.obsidian" ]]; then
  VAULT_NOTES=$(find "$VAULT_PATH" -name "*.md" -not -path "*/.git/*" 2>/dev/null | wc -l || echo "?")
  VAULT_STATUS="$(ok "ok") · ${VAULT_NOTES} notas · proyecto: ${VAULT_PROJECT}"
else
  VAULT_STATUS="$(warn "no encontrado") · ningún proyecto con .obsidian/ en projects/"
fi

# ── Hooks de memoria/confidencialidad registrados ────────────────────────────
SETTINGS="$ROOT/.claude/settings.json"
MEM_HOOKS_OK=0
CONF_HOOKS_OK=0
if [[ -f "$SETTINGS" ]]; then
  grep -q "memory-auto-capture" "$SETTINGS" && MEM_HOOKS_OK=$((MEM_HOOKS_OK+1))
  grep -q "memory-verified-gate" "$SETTINGS" && MEM_HOOKS_OK=$((MEM_HOOKS_OK+1))
  grep -q "memory-prime-hook" "$SETTINGS" && MEM_HOOKS_OK=$((MEM_HOOKS_OK+1))
  grep -q "session-end-memory" "$SETTINGS" && MEM_HOOKS_OK=$((MEM_HOOKS_OK+1))
  grep -q "stop-memory-extract" "$SETTINGS" && MEM_HOOKS_OK=$((MEM_HOOKS_OK+1))
  grep -q "data-sovereignty-gate" "$SETTINGS" && CONF_HOOKS_OK=$((CONF_HOOKS_OK+1))
  grep -q "vault-frontmatter-gate" "$SETTINGS" && CONF_HOOKS_OK=$((CONF_HOOKS_OK+1))
  grep -q "artifacts-confidentiality-gate" "$SETTINGS" && CONF_HOOKS_OK=$((CONF_HOOKS_OK+1))
  grep -q "block-credential-leak" "$SETTINGS" && CONF_HOOKS_OK=$((CONF_HOOKS_OK+1))
fi

if [[ $MEM_HOOKS_OK -ge 5 ]]; then
  HOOKS_MEM_STATUS="$(ok "5/5 registrados")"
else
  HOOKS_MEM_STATUS="$(warn "${MEM_HOOKS_OK}/5 registrados")"
fi
if [[ $CONF_HOOKS_OK -ge 4 ]]; then
  HOOKS_CONF_STATUS="$(ok "4/4 registrados")"
else
  HOOKS_CONF_STATUS="$(warn "${CONF_HOOKS_OK}/4 registrados")"
fi

# ── Usuario activo ───────────────────────────────────────────────────────────
ACTIVE_USER_FILE="$ROOT/.claude/profiles/active-user.md"
ACTIVE_SLUG=$(grep -m1 'active_slug:' "$ACTIVE_USER_FILE" 2>/dev/null | sed 's/.*active_slug: *"\([^"]*\)".*/\1/' || echo "")
USER_NAME=""
if [[ -n "$ACTIVE_SLUG" ]]; then
  IDENTITY_FILE="$ROOT/.claude/profiles/users/${ACTIVE_SLUG}/identity.md"
  USER_NAME=$(grep -m1 '^name:' "$IDENTITY_FILE" 2>/dev/null | sed 's/.*name: *"\([^"]*\)".*/\1/' || echo "")
fi

# ── Output ────────────────────────────────────────────────────────────────────
DATE=$(date +%Y-%m-%d 2>/dev/null || echo "")

echo "─────────────────────────────────────────────────────────────────────────"
echo "MEMORIA — Estado de capas                          ${DATE}"
[[ -n "$USER_NAME" ]] && echo "Usuario activo: ${USER_NAME}"
echo "─────────────────────────────────────────────────────────────────────────"
printf "%-18s  %s\n" "Capa" "Estado"
echo "─────────────────────────────────────────────────────────────────────────"
printf "%-18s  %s\n" "L0 Índice"   "$L0_STATUS"
printf "%-18s  %s\n" "L1 Sessions" "$L1_STATUS"
printf "%-18s  %s\n" "L2 JSONL"    "$L2_STATUS"
printf "%-18s  %s\n" "L3 SQLite"   "$L3_STATUS"
printf "%-18s  %s\n" "L4 RAM"      "$L4_STATUS"
echo "─────────────────────────────────────────────────────────────────────────"
printf "%-18s  %s\n" "Agentes pub"    "$PUB_STATUS"
printf "%-18s  %s\n" "Agentes priv"   "$PRV_STATUS"
printf "%-18s  %s\n" "Vault Obsidian" "$VAULT_STATUS"
echo "─────────────────────────────────────────────────────────────────────────"
printf "%-18s  %s\n" "Hooks memoria"  "$HOOKS_MEM_STATUS"
printf "%-18s  %s\n" "Hooks confid."  "$HOOKS_CONF_STATUS"
echo "─────────────────────────────────────────────────────────────────────────"

# ── Frontend-without-hooks banner ─────────────────────────────────────────────
# Source savia-env.sh to detect frontends that lack hook support. Non-fatal.
SAVIA_ENV_SH="$ROOT/scripts/savia-env.sh"
if [[ -f "$SAVIA_ENV_SH" ]]; then
  # shellcheck source=/dev/null
  source "$SAVIA_ENV_SH" 2>/dev/null || true
fi
if ! savia_has_hooks 2>/dev/null; then
  echo ""
  echo "WARN: este frontend no soporta hooks — funciones inactivas:"
  echo "   • memory-auto-capture  (PostToolUse)  — memoria no se guarda automáticamente"
  echo "   • pre-commit-review    (Stop)          — revisión pre-commit no corre"
  echo "   • session-init         (SessionStart)  — daemons no se levantan solos"
  echo "   • post-edit-lint       (PostToolUse)   — lint post-edición inactivo"
fi
