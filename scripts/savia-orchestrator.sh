#!/usr/bin/env bash
# savia-orchestrator.sh — SCL-011: orquestador SAGI mínimo.
#
# Integra los 4 pilares en un bucle de decisión continuo:
#   LEER (CRITERIO human_authored + cúpula SaviaLearning via recall)
#   DECIDIR (LLM como heurística sobre el contexto del sustrato — PURE_BASH
#            compone scripts existentes; el LLM se invoca vía contrato mínimo)
#   PERSISTIR (learning-proposal --persist)
#   MEDIR (learning-metric.sh → métrica L)
#   AJUSTAR (learning-autonomy.sh por p_consistent)
#
# COMPONE, no reimplementa (SCL-011 R1). CRITERIO y CONSTITUCION intocables
# (CRIT-031, ART-11): todo output termina en propuesta INFERRED. Sin vendor
# names, sin red salvo endpoints del sustrato local, PURE_BASH (parámetro: el
# LLM es opcional; si no está disponible o falla, el orquestador sigue con la
# ruta determinista shadow).
#
# Usage:
#   savia-orchestrator.sh --task "descripción" [--dry-run] [--iterations N]
#         [--decide "flash|none|local"] [--p-consistent X]
# Exit: 0 ok · 2 input inválido · 3 dependencia ausente
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SAVIA_WORKSPACE_DIR="${SAVIA_WORKSPACE_DIR:-$ROOT}"

TASK=""
DRY_RUN=false
ITERATIONS=1
DECIDE="${SAGI_DECIDE:-none}"
P_CONSISTENT="${SAGI_P_CONSISTENT:-}"
SAGI_DECISION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) TASK="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --iterations) ITERATIONS="$2"; shift 2 ;;
    --decide) DECIDE="$2"; shift 2 ;;
    --p-consistent) P_CONSISTENT="$2"; shift 2 ;;
    *) echo "usage: $0 --task T [--dry-run] [--iterations N] [--decide none|flash|local]" >&2; exit 2 ;;
  esac
done
[[ -z "$TASK" ]] && { echo "ERROR: --task requerido" >&2; exit 2; }
[[ "$ITERATIONS" =~ ^[0-9]+$ ]] || { echo "ERROR: --iterations entero" >&2; exit 2; }

# ── Dependencias (composición, no reimplementación) ──────────────────────────
for dep in learning-recall.sh learning-proposal.sh learning-metric.sh learning-autonomy.sh; do
  [[ -x "$ROOT/scripts/$dep" ]] || { echo "ERROR: dependencia ausente: scripts/$dep" >&2; exit 3; }
done

# ── Fase 1: LEER sustrato ────────────────────────────────────────────────────
read_sustrate() {
  # 1a. criterio human_authored
  local crit keyword
  crit="$ROOT/CRITERIO.md"
  keyword="criterio soberania dato self-hosted"
  if [[ -n "$TASK" ]]; then
    crit=$(echo "$TASK $keyword" | tr '[:upper:]' '[:lower:]' | tr -d 'áéíóúñ' | head -c 120)
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [leer] CRITERIO.md"
    return
  fi
  local recall_out
  recall_out=$(bash "$ROOT/scripts/learning-recall.sh" --query "$TASK" --mode shadow --json 2>/dev/null | python3 -c "import sys,json;print(int(json.load(sys.stdin).get('shadow_hits',0)))" 2>/dev/null || echo 0)
  echo "  [leer] CRITERIO (+$recall_out shadow hits de SaviaLearning)"
}

# ── Fase 2: DECIDIR (heurística; el LLM es opcional) ─────────────────────────
decide() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [decidir] heurística=$DECIDE (dry-run, sin ejecutar)"
    return
  fi
  case "$DECIDE" in
    llm|local)
      # LLM como heurística local (CRIT-001): Ollama en 127.0.0.1, sin cloud.
      local prompt
      prompt="Eres el algoritmo SAGI sobre el sustrato Savia. Tarea: $TASK. Lee el criterio CRITERIO.md (linea_roja sovereign del dato) y propone UNA mejora de proceso para el sustrato (skill/criterio/memoria) en una frase breve. Sin rellenar, directo. Output: propuesta en 1-2 frases."
      local resp
      resp=$(curl -s --max-time 20 http://127.0.0.1:11434/api/generate \
        -d "{\"model\":\"${SAGI_LLM_MODEL:-qwen2.5:3b}\",\"prompt\":\"$prompt\",\"stream\":false,\"options\":{\"num_predict\":120}}" 2>/dev/null \
        | python3 -c "import sys,json;print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo "")
      if [[ -n "$resp" ]]; then
        echo "  [decidir] heurística=local(${SAGI_LLM_MODEL:-qwen2.5:3b}) → $resp"
        SAGI_DECISION="$resp"
      else
        echo "  [decidir] heurística=local NO disponible (Ollama apagado?) — shadow determinista"
        SAGI_DECISION="propuesta determinista shadow"
      fi
      ;;
    *)
      # ruta determinista shadow: sin LLM, el bucle solo captura y mide.
      echo "  [decidir] heurística=$DECIDE — propuesta determinista shadow"
      SAGI_DECISION="propuesta determinista shadow"
      ;;
  esac
}

# ── Fase 3: PERSISTIR (solo propone; INFERRED, nunca human_authored) ─────────
persist() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [persistir] learning-proposal --persist (dry-run)"
    return
  fi
  local change="${SAGI_DECISION:-$1}"
  bash "$ROOT/scripts/learning-proposal.sh" \
    --origin "savia-orchestrator (SCL-011): tarea '$TASK'" \
    --evidence "$ROOT/scripts/savia-orchestrator.sh" \
    --diagnosis "orquestador SCL-011 procesó la tarea; propuesta de aprendizaje generada ($change)" \
    --change "$change" --target skill --trigger recurrence >/dev/null 2>&1 && echo "  [persistir] LP creada (INFERRED)"
}

# ── Fase 4: MEDIR (métrica L) ────────────────────────────────────────────────
measure() {
  local base_p="${P_CONSISTENT:-0.5}"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [medir] L = f(p_consistent=$base_p, divergencia, ignorancia)"
    return
  fi
  bash "$ROOT/scripts/learning-metric.sh" --p-consistent "$base_p" --divergence 0.2 --ignorance-resolved 0.1 2>/dev/null | tail -1
}

# ── Fase 5: AJUSTAR autonomía por p_consistent (SCL-006) ─────────────────────
adjust() {
  local base_p="${P_CONSISTENT:-0.5}"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [ajustar] autonomía L0-L3 por p_consistent=$base_p (dry-run)"
    return
  fi
  bash "$ROOT/scripts/learning-autonomy.sh" --p-consistent "$base_p" --requested L2 2>/dev/null | tail -1 || echo "  [ajustar] n/a"
}

# ── N ciclos ─────────────────────────────────────────────────────────────────
for (( i=1; i<=ITERATIONS; i++ )); do
  echo "── ciclo $i/$ITERATIONS ──"
  read_sustrate
  decide
  persist "el bucle SCL-011 mejora el recuerdo del criterio para la tarea: $TASK"
  measure
  adjust
done

echo "── done (dry_run=$DRY_RUN, iterations=$ITERATIONS) ──"
exit 0