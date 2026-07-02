#!/usr/bin/env bash
# dispatch-pretooluse.sh — SE-253 Slice 4
# Único punto de entrada PreToolUse. Lee routing-pretooluse.tsv y despacha.
#
# Input  : JSON de OpenCode/Claude Code en stdin
# Exit   : 0 (allow), 2 (block), 1 (error interno — nunca bloquea operación)
#
# Reducción: 26 entradas PreToolUse en settings.json → 1 spawn de este dispatcher
# Ref    : docs/rules/domain/se-253-dispatcher-design.md

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROUTING="$REPO_ROOT/hooks/routing-pretooluse.tsv"
INPUT=$(cat)

# ── Extrae tool name (acepta múltiples formatos OpenCode / Claude Code) ───────
TOOL=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    name = (d.get('tool_use', {}) or {}).get('name', '') \
        or d.get('tool_name', '') \
        or d.get('name', '') \
        or ''
    print(name)
except Exception:
    print('')
" 2>/dev/null || echo "")

# ── Sanidad: si no hay routing file, allow con warning ───────────────────────
if [[ ! -f "$ROUTING" ]]; then
    echo "[dispatch-pretooluse] WARNING: routing file not found: $ROUTING" >&2
    exit 0
fi

# ── Despacha hooks cuyo matcher coincide con TOOL ─────────────────────────────
while IFS=$'\t' read -r matcher script mode blocking desc; do
    # Ignorar comentarios y líneas vacías
    [[ -z "$matcher" ]] && continue
    [[ "$matcher" =~ ^[[:space:]]*# ]] && continue

    # Evalúa matcher contra tool name
    # ".*" coincide siempre; cualquier otro patrón se evalúa como regex bash
    if [[ "$matcher" != ".*" ]]; then
        # Convierte matcher de settings (Edit|Write) a regex válida
        regex="^(${matcher//\./\\.})$"
        [[ ! "$TOOL" =~ $regex ]] && continue
    fi

    script_path="$REPO_ROOT/$script"
    if [[ ! -f "$script_path" ]]; then
        # Hook no existe — skip con warning, no bloquear
        echo "[dispatch-pretooluse] WARNING: hook not found: $script_path" >&2
        continue
    fi

    # ── Ejecuta el hook ───────────────────────────────────────────────────────
    if [[ "$mode" == "source" ]]; then
        # source en subshell para aislar efectos secundarios
        exit_code=0
        (source "$script_path" <<< "$INPUT") && exit_code=$? || exit_code=$?
    else
        # spawn: proceso independiente con timeout implícito de la shell
        exit_code=0
        printf '%s' "$INPUT" | bash "$script_path" && exit_code=$? || exit_code=$?
    fi

    # ── Propaga bloqueo si el hook es bloqueante y devolvió 2 ─────────────────
    if [[ "$blocking" == "yes" && "$exit_code" -eq 2 ]]; then
        exit 2
    fi

done < <(grep -v $'^\t*#' "$ROUTING" 2>/dev/null || true)

exit 0
