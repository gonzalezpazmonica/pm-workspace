#!/bin/bash
# budget-guard.sh — Context budget monitor (SPEC-022 F1)
# Called by commands before heavy operations. Returns level and suggestion.
# Usage: source scripts/budget-guard.sh && budget_check [--block]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Estimate context usage from conversation turn count or env hint
# Claude Code doesn't expose exact token count, so we use heuristics:
# - CLAUDE_CONTEXT_PERCENT env var (set by statusline if configured)
# - Fallback: count recent tool calls from agent-trace if available
budget_check() {
    local block_mode=false
    [[ "${1:-}" == "--block" ]] && block_mode=true

    # Try env var first (set by user via /statusline config)
    local pct="${CLAUDE_CONTEXT_PERCENT:-0}"

    # If no env var, try to estimate from trace log size
    if [[ "$pct" == "0" ]]; then
        local trace_dir="${PROJECT_ROOT:-$HOME/claude}/output/agent-trace"
        if [[ -d "$trace_dir" ]]; then
            local today=$(date +%Y-%m-%d)
            local today_entries=$(find "$trace_dir" -name "${today}*" -type f 2>/dev/null | wc -l)
            # Rough heuristic: each trace entry ~ 2-3% context
            pct=$((today_entries * 3))
            [[ $pct -gt 100 ]] && pct=100
        fi
    fi

    # Classify and report
    if [[ $pct -lt 50 ]]; then
        echo "context:healthy:${pct}"
        return 0
    elif [[ $pct -lt 70 ]]; then
        echo "context:warning:${pct}"
        echo "Contexto al ${pct}%. Considera /compact pronto." >&2
        return 0
    elif [[ $pct -lt 85 ]]; then
        echo "context:high:${pct}"
        echo "Contexto al ${pct}%. Ejecuta /compact antes del siguiente comando pesado." >&2
        return 0
    else
        echo "context:critical:${pct}"
        echo "Contexto al ${pct}%. /compact necesario ahora." >&2
        if [[ "$block_mode" == "true" ]]; then
            echo "Bloqueado: compacta antes de continuar." >&2
            return 1
        fi
        return 0
    fi
}

# Banner format for commands to include in their output
budget_banner() {
    local result=$(budget_check 2>/dev/null)
    local level=$(echo "$result" | cut -d: -f2)
    local pct=$(echo "$result" | cut -d: -f3)

    case "$level" in
        healthy)  ;; # silencio
        warning)  echo "  Contexto: ${pct}% — /compact recomendado" ;;
        high)     echo "  Contexto: ${pct}% — /compact necesario" ;;
        critical) echo "  Contexto: ${pct}% — /compact AHORA" ;;
    esac
}

# If run directly (not sourced), execute budget_check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    budget_check "$@"
fi
