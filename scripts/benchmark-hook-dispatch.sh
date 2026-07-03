#!/usr/bin/env bash
set -euo pipefail
# scripts/benchmark-hook-dispatch.sh — SE-253 Slice 4
#
# Mide el overhead de spawning de hooks y la latencia del dispatcher.
# NOTA IMPORTANTE (2026-07-03): El dispatcher NO reduce latencia de pared.
# Claude Code lanza hooks en PARALELO; el dispatcher los haría SECUENCIALES.
# El valor del dispatcher es trazabilidad y orden garantizado, no throughput.
# Ver docs/propuestas/SE-253-opencode-optimization.md § Slice 4 — Decisión.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$REPO_ROOT/.claude/settings.json"
ROUTING_PRE="$REPO_ROOT/hooks/routing-pretooluse.tsv"
ROUTING_POST="$REPO_ROOT/hooks/routing-posttooluse.tsv"

# ── Conteos desde settings.json ────────────────────────────────────────────
pre_count=$(python3 -c "
import json
d = json.load(open('$SETTINGS'))
print(len(d.get('hooks',{}).get('PreToolUse',[])))
" 2>/dev/null || echo "?")

post_count=$(python3 -c "
import json
d = json.load(open('$SETTINGS'))
print(len(d.get('hooks',{}).get('PostToolUse',[])))
" 2>/dev/null || echo "?")

total_baseline=$(( ${pre_count:-0} + ${post_count:-0} ))

# ── Conteos del dispatcher ─────────────────────────────────────────────────
routing_pre=$(grep -v '^#' "$ROUTING_PRE" 2>/dev/null | grep -c . || echo 0)
routing_post=$(grep -v '^#' "$ROUTING_POST" 2>/dev/null | grep -c . || echo 0)
blocking_pre=$(grep -v '^#' "$ROUTING_PRE" 2>/dev/null | awk -F'\t' '$4=="yes"' | grep -c . || echo 0)

echo ""
echo "▶ Baseline: hooks en settings.json"
echo "  · PreToolUse hooks (baseline):  $pre_count spawns por invocación (paralelo)"
echo "  · PostToolUse hooks (baseline): $post_count spawns por invocación (paralelo)"
echo "  · Total baseline:               $total_baseline spawns (paralelos — Claude Code los lanza así)"
echo ""
echo "▶ Dispatcher: entradas en routing TSV"
echo "  · routing-pretooluse.tsv:  $routing_pre entradas ($blocking_pre bloqueantes)"
echo "  · routing-posttooluse.tsv: $routing_post entradas (0 bloqueantes)"
echo "  · Dispatcher spawns (Pre):  1  (dispatch-pretooluse.sh)"
echo "  · Dispatcher spawns (Post): 1  (dispatch-posttooluse.sh)"
echo "  · Total dispatcher:         2  spawns (vs $total_baseline baseline)"
echo "  ✓ Reducción de spawns concurrentes: $(( 100 - 200 / total_baseline ))%  ($total_baseline → 2)"
echo ""
echo "▶ Benchmark de latencia comparativo"
echo ""

# Latencia paralela (baseline simulation)
PARALLEL_TIME=$(TIMEFORMAT='%R'; { time (for i in $(seq 1 "$pre_count"); do bash -c 'exit 0' & done; wait); } 2>&1 | tail -1)
echo "  · Paralelo ($pre_count spawns noop):   ${PARALLEL_TIME}s"

# Latencia secuencial (dispatcher)
SEQUENTIAL_TIME=$(TIMEFORMAT='%R'; { time (for i in $(seq 1 "$pre_count"); do bash -c 'exit 0'; done); } 2>&1 | tail -1)
echo "  · Secuencial ($pre_count spawns noop): ${SEQUENTIAL_TIME}s"

echo ""
echo "▶ Conclusión (honesta)"
echo ""
echo "  El dispatcher reduce spawns CONCURRENTES de $total_baseline a 2."
echo "  Sin embargo, Claude Code lanza hooks en paralelo — el dispatcher"
echo "  los convierte a secuenciales. La latencia de pared puede aumentar."
echo ""
echo "  Beneficio real del dispatcher:"
echo "  - Orden de ejecución garantizado y documentado (routing.tsv)"
echo "  - Trazabilidad: un único punto para añadir logging/timeout"
echo "  - Útil cuando el orden importa (chain de bloqueantes)"
echo ""
echo "  NO activar en settings.json para reducir latencia — sería regresión."
echo "  Activar solo si el orden garantizado es requerimiento explícito."
echo ""
echo "▶ Resumen SE-253 Slice 4"
echo ""
printf "  %-40s %s\n" "Métrica" "Valor"
printf "  %-40s %s\n" "-------" "-----"
printf "  %-40s %s\n" "baseline spawns PreToolUse"  "$pre_count"
printf "  %-40s %s\n" "baseline spawns PostToolUse" "$post_count"
printf "  %-40s %s\n" "baseline spawns total"       "$total_baseline"
printf "  %-40s %s\n" "dispatcher spawns Pre+Post"  "2"
printf "  %-40s %s\n" "entradas routing-pretooluse" "$routing_pre"
printf "  %-40s %s\n" "entradas routing-posttooluse" "$routing_post"
printf "  %-40s %s\n" "hooks bloqueantes Pre"       "$blocking_pre"
printf "  %-40s %s\n" "hooks bloqueantes Post"      "0"
printf "  %-40s %s\n" "settings.json modificado"    "NO — ver conclusión"
echo ""
echo "  ✓ Benchmark completado"
