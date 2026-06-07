#!/bin/bash
# memory-recall-audit.sh — SE-212: measure MEMORY.md recall budget utilization
# Ref: docs/propuestas/SE-212-recall-budget-experiment.md
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$WORKSPACE_DIR/output"
mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

# ── Defaults ──────────────────────────────────────────────────────────────────
DEFAULT_MEMORY_FILE="${HOME}/.savia-memory/auto/MEMORY.md"
MEMORY_FILE="${SAVIA_MEMORY_INDEX:-$DEFAULT_MEMORY_FILE}"
CAP_DEFAULT=200
SIMULATE_K=""
REPORT_MODE=false
JSON_MODE=false
CHECK_ONLY=false

# ── Args ──────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --memory-file) MEMORY_FILE="$2"; shift 2 ;;
        --simulate-k)  SIMULATE_K="$2"; shift 2 ;;
        --cap)         CAP_DEFAULT="$2"; shift 2 ;;
        --report)      REPORT_MODE=true; shift ;;
        --json)        JSON_MODE=true; shift ;;
        --check-only)  CHECK_ONLY=true; shift ;;
        --help|-h)
            echo "Usage: memory-recall-audit.sh [--memory-file PATH] [--simulate-k N] [--cap N] [--report] [--json]"
            echo "  --simulate-k N  Show how many additional entries a cap of N would expose"
            echo "  --report        Write output/memory-recall-audit-{date}.md"
            echo "  --json          Output JSON metrics"
            exit 0 ;;
        *) shift ;;
    esac
done

# ── Read MEMORY.md ─────────────────────────────────────────────────────────────
total_entries=0
active_entries=0
oldest_active=""
oldest_ts=""
declare -a entry_lines=()

if [[ ! -f "$MEMORY_FILE" ]]; then
    if [[ "$JSON_MODE" == "true" ]]; then
        echo '{"error":"MEMORY.md not found","file":"'"$MEMORY_FILE"'","total":0,"active":0,"cap":'"$CAP_DEFAULT"',"utilization":0.0}'
    else
        echo "[WARN] SE-212: MEMORY.md not found at: $MEMORY_FILE" >&2
        echo "Cap: $CAP_DEFAULT  |  Entries: 0  |  Utilization: 0.0%"
    fi
    exit 0
fi

# Count entries between ENTRIES_START / ENTRIES_END markers
in_entries=false
cutoff_date=$(date -u -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-30d +%Y-%m-%d 2>/dev/null || echo "2000-01-01")

while IFS= read -r line; do
    if [[ "$line" == "<!-- ENTRIES_START -->" ]]; then
        in_entries=true; continue
    fi
    if [[ "$line" == "<!-- ENTRIES_END -->" ]]; then
        in_entries=false; continue
    fi
    if $in_entries && [[ "$line" =~ ^-[[:space:]] ]]; then
        ((total_entries++)) || true
        entry_lines+=("$line")
        # Try to extract date from the line (format YYYY-MM-DD)
        entry_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || true)
        if [[ -n "$entry_date" ]]; then
            if [[ "$entry_date" > "$cutoff_date" || "$entry_date" == "$cutoff_date" ]]; then
                ((active_entries++)) || true
            fi
            if [[ -z "$oldest_ts" || "$entry_date" < "$oldest_ts" ]]; then
                oldest_ts="$entry_date"
                oldest_active="$line"
            fi
        else
            # No date found — count as active (conservative)
            ((active_entries++)) || true
        fi
    fi
done < "$MEMORY_FILE"

cap=$CAP_DEFAULT
utilization=0
if [[ $cap -gt 0 ]]; then
    utilization=$(python3 -c "print(round($total_entries / $cap * 100, 1))" 2>/dev/null || echo "0")
fi

excluded=0
if [[ $total_entries -gt $cap ]]; then
    excluded=$((total_entries - cap))
fi

# ── --simulate-k ──────────────────────────────────────────────────────────────
sim_output=""
if [[ -n "$SIMULATE_K" ]]; then
    sim_k="${SIMULATE_K:-400}"
    if [[ $sim_k -gt $cap ]]; then
        additional=$((sim_k - cap))
        sim_output="Con k=$sim_k: +$additional entradas adicionales disponibles"
    else
        sim_output="Con k=$sim_k: cap menor o igual al actual ($cap) — sin entradas adicionales"
    fi
fi

# ── Recommendation ────────────────────────────────────────────────────────────
recommendation=""
util_num=$(echo "$utilization" | grep -oE '[0-9]+' | head -1 || echo "0")
if [[ $util_num -ge 80 ]]; then
    recommendation="WARN: Utilización ≥80% ($utilization%). Considerar subir cap a $((cap * 2))."
elif [[ $util_num -ge 60 ]]; then
    recommendation="OK: Utilización moderada ($utilization%). Monitorear."
else
    recommendation="OK: Utilización baja ($utilization%). Cap actual ($cap) suficiente."
fi

# ── Output ────────────────────────────────────────────────────────────────────
if [[ "$JSON_MODE" == "true" ]]; then
    oldest_json="${oldest_ts:-null}"
    [[ "$oldest_json" != "null" ]] && oldest_json="\"$oldest_json\""
    sim_json="null"
    [[ -n "$sim_output" ]] && sim_json="\"$sim_output\""
    echo "{\"total\":$total_entries,\"active\":$active_entries,\"cap\":$cap,\"utilization\":$utilization,\"excluded\":$excluded,\"oldest_active\":$oldest_json,\"simulate_k\":$sim_json,\"recommendation\":\"$recommendation\"}"
elif [[ "$REPORT_MODE" == "true" || "$CHECK_ONLY" == "false" ]]; then
    echo "Cap actual: $cap  |  Entradas activas (30d): $active_entries  |  Utilización: ${utilization}%"
    [[ $excluded -gt 0 ]] && echo "Entradas excluidas (sobre cap): $excluded"
    [[ -n "$sim_output" ]] && echo "$sim_output"
    [[ -n "$oldest_ts" ]] && echo "Entrada más antigua activa: $oldest_ts"
    echo "$recommendation"
fi

# ── Write report ──────────────────────────────────────────────────────────────
if [[ "$REPORT_MODE" == "true" ]]; then
    report_date=$(date +%Y%m%d)
    report_file="$OUTPUT_DIR/memory-recall-audit-${report_date}.md"
    cat > "$report_file" << REPORTEOF
# Memory Recall Budget Audit — ${report_date}
<!-- SE-212 -->

## Métricas

| Métrica | Valor |
|---|---|
| Total entradas | $total_entries |
| Entradas activas (30d) | $active_entries |
| Cap actual | $cap |
| Utilización | ${utilization}% |
| Entradas excluidas | $excluded |
| Entrada más antigua | ${oldest_ts:-N/A} |

## Recomendación

$recommendation

$(if [[ -n "$sim_output" ]]; then echo "## Simulación k\n\n$sim_output"; fi)

## Referencias

- Spec: docs/propuestas/SE-212-recall-budget-experiment.md
- MEMORY.md: $MEMORY_FILE
REPORTEOF
    echo "Informe guardado: $report_file"
fi
