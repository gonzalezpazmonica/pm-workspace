#!/usr/bin/env bash
# SE-247 — Instala el hook pre-push de seguridad en el repo actual o en uno dado.
# Uso: bash scripts/install-prepush-hook.sh [--repo <path>]
# En worktrees y con core.hooksPath instala donde git lee los hooks (compartido por todos los worktrees).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_GATE="$SCRIPT_DIR/pre-push-security-gate.sh"

# ── Parámetros ────────────────────────────────────────────────────────────────
TARGET_REPO="${PWD}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) TARGET_REPO="$2"; shift 2 ;;
    --help|-h)
      echo "Uso: bash install-prepush-hook.sh [--repo <path>]"
      echo "  Sin --repo: instala en el repositorio actual (cwd)."
      exit 0 ;;
    *) echo "Parámetro desconocido: $1"; exit 1 ;;
  esac
done

# ── Localizar el directorio de hooks que git usa de verdad ─────────────────────
# `--git-path hooks` respeta core.hooksPath y, en worktrees, el directorio común
# (git ignora .git/worktrees/<n>/hooks: instalar ahí dejaba el push sin gate).
git -C "$TARGET_REPO" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "ERROR: $TARGET_REPO no es un repositorio git." >&2
  exit 1
}
HOOKS_DIR="$(git -C "$TARGET_REPO" rev-parse --git-path hooks)"
if [[ "$HOOKS_DIR" != /* ]]; then
  HOOKS_DIR="$TARGET_REPO/$HOOKS_DIR"
fi
mkdir -p "$HOOKS_DIR"
HOOK_TARGET="$HOOKS_DIR/pre-push"
GATE_SCRIPT="$DEFAULT_GATE"

# ── Verificar que el script fuente existe ─────────────────────────────────────
if [[ ! -f "$GATE_SCRIPT" ]]; then
  echo "ERROR: Script fuente no encontrado: $GATE_SCRIPT" >&2
  exit 1
fi

# ── Idempotencia: no sobreescribir sin confirmación ───────────────────────────
if [[ -f "$HOOK_TARGET" ]]; then
  if grep -q "SE-247" "$HOOK_TARGET" 2>/dev/null; then
    echo "[install-prepush-hook] Hook SE-247 ya instalado — sin cambios."
    exit 0
  fi
  # Existe un hook diferente: hacer backup
  BACKUP="$HOOK_TARGET.bak.$(date +%Y%m%d%H%M%S)"
  echo "[install-prepush-hook] pre-push existente encontrado — backup en: $BACKUP"
  cp "$HOOK_TARGET" "$BACKUP"
fi

# ── Instalar hook como wrapper que llama al script ───────────────────────────
cat > "$HOOK_TARGET" <<HOOK
#!/usr/bin/env bash
# SE-247 — Pre-push security gate (instalado por install-prepush-hook.sh)
# Para desinstalar: rm .git/hooks/pre-push
exec bash "${GATE_SCRIPT}" "\$@" <&0
HOOK

chmod +x "$HOOK_TARGET"

echo "[install-prepush-hook] Hook instalado en: $HOOK_TARGET"
echo "[install-prepush-hook] Fuente: $GATE_SCRIPT"
echo "[install-prepush-hook] Para desactivar: SAVIA_PREPUSH_SECURITY=off git push"
