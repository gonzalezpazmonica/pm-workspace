#!/usr/bin/env bash
# scripts/benchmark-hook-dispatch.sh — SE-253 Slice 4
# Mide el impacto del dispatcher vs el modelo actual de settings.json
#
# Uso:
#   bash scripts/benchmark-hook-dispatch.sh           # modo completo
#   bash scripts/benchmark-hook-dispatch.sh --fast    # solo conteo, sin latencia
#
# Salida (stdout): baseline spawns, dispatcher spawns, latencia estimada

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$REPO_ROOT/.claude/settings.json"
PRE_TSV="$REPO_ROOT/hooks/routing-pretooluse.tsv"
POST_TSV="$REPO_ROOT/hooks/routing-posttooluse.tsv"
DISPATCH_PRE="$REPO_ROOT/.opencode/hooks/dispatch-pretooluse.sh"
DISPATCH_POST="$REPO_ROOT/.opencode/hooks/dispatch-posttooluse.sh"

FAST_MODE="${1:-}"
ITERATIONS=50  # repeticiones para medir latencia media

# ── Colores ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

banner() { printf "\n${BOLD}${BLUE}▶ %s${NC}\n" "$1"; }
ok()     { printf "  ${GREEN}✓${NC} %s\n" "$1"; }
warn()   { printf "  ${YELLOW}⚠${NC} %s\n" "$1"; }
info()   { printf "  ${BLUE}·${NC} %s\n" "$1"; }

# ── 1. Conteo baseline: spawns por tool call en settings.json ─────────────────
banner "Baseline: hooks en settings.json"

if [[ ! -f "$SETTINGS" ]]; then
    warn "settings.json no encontrado: $SETTINGS"
    BASELINE_PRE=0
    BASELINE_POST=0
else
    BASELINE_PRE=$(python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
hooks = d.get('hooks', {})
pre = hooks.get('PreToolUse', [])
count = sum(len(entry.get('hooks', [])) for entry in pre)
print(count)
" 2>/dev/null || echo "0")

    BASELINE_POST=$(python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
hooks = d.get('hooks', {})
post = hooks.get('PostToolUse', [])
count = sum(len(entry.get('hooks', [])) for entry in post)
print(count)
" 2>/dev/null || echo "0")
fi

BASELINE_TOTAL=$((BASELINE_PRE + BASELINE_POST))
info "PreToolUse hooks (baseline):  ${BASELINE_PRE} spawns por invocación"
info "PostToolUse hooks (baseline): ${BASELINE_POST} spawns por invocación"
info "Total baseline:               ${BASELINE_TOTAL} spawns (Pre+Post combinados)"

# ── 2. Conteo dispatcher: entradas en TSV ─────────────────────────────────────
banner "Dispatcher: entradas en routing TSV"

count_tsv_entries() {
    local tsv="$1"
    if [[ ! -f "$tsv" ]]; then echo "0"; return; fi
    grep -cv $'^\t*#\|^[[:space:]]*$' "$tsv" 2>/dev/null || echo "0"
}

count_tsv_blocking() {
    local tsv="$1"
    if [[ ! -f "$tsv" ]]; then echo "0"; return; fi
    grep -v $'^\t*#\|^[[:space:]]*$' "$tsv" 2>/dev/null | awk -F'\t' '$4=="yes"' | wc -l
}

PRE_ENTRIES=$(count_tsv_entries "$PRE_TSV")
POST_ENTRIES=$(count_tsv_entries "$POST_TSV")
PRE_BLOCKING=$(count_tsv_blocking "$PRE_TSV")
POST_BLOCKING=$(count_tsv_blocking "$POST_TSV")

info "routing-pretooluse.tsv:  ${PRE_ENTRIES} entradas (${PRE_BLOCKING} bloqueantes)"
info "routing-posttooluse.tsv: ${POST_ENTRIES} entradas (${POST_BLOCKING} bloqueantes)"
info "Dispatcher spawns (Pre):  1  (dispatch-pretooluse.sh)"
info "Dispatcher spawns (Post): 1  (dispatch-posttooluse.sh)"
info "Total dispatcher:         2  spawns (vs ${BASELINE_TOTAL} baseline)"

if [[ "$BASELINE_TOTAL" -gt 0 ]]; then
    REDUCTION=$(( (BASELINE_TOTAL - 2) * 100 / BASELINE_TOTAL ))
    ok "Reducción de spawns: ${REDUCTION}%  (${BASELINE_TOTAL} → 2)"
else
    warn "No se pudo calcular reducción (baseline = 0)"
fi

# ── 3. Latencia del dispatcher ────────────────────────────────────────────────
if [[ "$FAST_MODE" == "--fast" ]]; then
    banner "Latencia: omitida (--fast mode)"
else
    banner "Latencia del dispatcher (${ITERATIONS} iteraciones)"

    SAMPLE_INPUT='{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.sh"}}'

    if [[ ! -x "$DISPATCH_PRE" ]]; then
        warn "dispatch-pretooluse.sh no encontrado o no ejecutable: $DISPATCH_PRE"
    else
        START_NS=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1e9))")
        for _ in $(seq 1 $ITERATIONS); do
            printf '%s' "$SAMPLE_INPUT" | bash "$DISPATCH_PRE" >/dev/null 2>&1 || true
        done
        END_NS=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1e9))")

        TOTAL_MS=$(( (END_NS - START_NS) / 1000000 ))
        AVG_MS=$(( TOTAL_MS / ITERATIONS ))

        info "Total ${ITERATIONS} llamadas dispatcher: ${TOTAL_MS} ms"
        ok "Latencia media dispatcher (Edit): ${AVG_MS} ms/invocación"

        # Estimación baseline: ~5ms por hook spawn (promedio conservador)
        BASELINE_EDIT_HOOKS=$(python3 -c "
import json
try:
    with open('$SETTINGS') as f:
        d = json.load(f)
    hooks = d.get('hooks', {}).get('PreToolUse', [])
    matchers_edit = [e for e in hooks if 'Edit' in e.get('matcher','') or '.*' in e.get('matcher','')]
    count = sum(len(e.get('hooks',[])) for e in matchers_edit)
    print(count)
except: print(0)
" 2>/dev/null || echo "0")

        ESTIMATED_BASELINE_MS=$((BASELINE_EDIT_HOOKS * 5))
        info "Estimación baseline Edit (${BASELINE_EDIT_HOOKS} hooks × 5ms): ~${ESTIMATED_BASELINE_MS} ms"

        if [[ "$ESTIMATED_BASELINE_MS" -gt 0 && "$AVG_MS" -gt 0 ]]; then
            SPEEDUP=$(( ESTIMATED_BASELINE_MS / AVG_MS ))
            ok "Speedup estimado: ~${SPEEDUP}x"
        fi
    fi
fi

# ── 4. Resumen final ──────────────────────────────────────────────────────────
banner "Resumen SE-253 Slice 4"

printf "\n"
printf "  %-35s %s\n" "Métrica" "Valor"
printf "  %-35s %s\n" "-------" "-----"
printf "  %-35s %s\n" "baseline spawns PreToolUse"    "${BASELINE_PRE}"
printf "  %-35s %s\n" "baseline spawns PostToolUse"   "${BASELINE_POST}"
printf "  %-35s %s\n" "baseline spawns total"         "${BASELINE_TOTAL}"
printf "  %-35s %s\n" "dispatcher spawns Pre+Post"    "2"
printf "  %-35s %s\n" "entradas routing-pretooluse"   "${PRE_ENTRIES}"
printf "  %-35s %s\n" "entradas routing-posttooluse"  "${POST_ENTRIES}"
printf "  %-35s %s\n" "hooks bloqueantes Pre"         "${PRE_BLOCKING}"
printf "  %-35s %s\n" "hooks bloqueantes Post"        "${POST_BLOCKING}"
printf "\n"

ok "Benchmark completado"
