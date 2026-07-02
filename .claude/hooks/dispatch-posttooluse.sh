#!/usr/bin/env bash
# dispatch-posttooluse.sh — SE-253 Slice 4
# Único punto de entrada PostToolUse. Lee routing-posttooluse.tsv y despacha.
#
# Input  : JSON de OpenCode/Claude Code en stdin
# Exit   : 0 siempre (PostToolUse no bloquea el flujo principal)
#          exit 2 de hooks se loguea como warning, no se propaga
#
# Reducción: 17 entradas PostToolUse en settings.json → 1 spawn de este dispatcher
# Ref    : docs/rules/domain/se-253-dispatcher-design.md

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROUTING="$REPO_ROOT/hooks/routing-posttooluse.tsv"
INPUT=$(cat)

# ── Extrae tool name ──────────────────────────────────────────────────────────
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

# ── Sanidad ───────────────────────────────────────────────────────────────────
if [[ ! -f "$ROUTING" ]]; then
    echo "[dispatch-posttooluse] WARNING: routing file not found: $ROUTING" >&2
    exit 0
fi

# ── Despacha hooks cuyo matcher coincide con TOOL ─────────────────────────────
while IFS=$'\t' read -r matcher script mode blocking desc; do
    [[ -z "$matcher" ]] && continue
    [[ "$matcher" =~ ^[[:space:]]*# ]] && continue

    if [[ "$matcher" != ".*" ]]; then
        regex="^(${matcher//\./\\.})$"
        [[ ! "$TOOL" =~ $regex ]] && continue
    fi

    script_path="$REPO_ROOT/$script"
    if [[ ! -f "$script_path" ]]; then
        echo "[dispatch-posttooluse] WARNING: hook not found: $script_path" >&2
        continue
    fi

    # ── Ejecuta el hook ───────────────────────────────────────────────────────
    if [[ "$mode" == "source" ]]; then
        exit_code=0
        (source "$script_path" <<< "$INPUT") && exit_code=$? || exit_code=$?
    else
        exit_code=0
        printf '%s' "$INPUT" | bash "$script_path" && exit_code=$? || exit_code=$?
    fi

    # ── PostToolUse: exit 2 se loguea pero NO bloquea ─────────────────────────
    if [[ "$exit_code" -eq 2 ]]; then
        echo "[dispatch-posttooluse] WARNING: hook returned 2 (ignored in PostToolUse): $script" >&2
    fi

done < <(grep -v $'^\t*#' "$ROUTING" 2>/dev/null || true)

# PostToolUse siempre devuelve 0
exit 0
