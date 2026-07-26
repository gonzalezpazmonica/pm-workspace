#!/bin/bash
# context-compaction-policy.sh — SE-270 S7: declared compaction survival policy
# Declares what survives compaction, what drops, what's protected.
# Sourcable by other scripts. Can also be invoked standalone for reporting.
# Usage:
#   source scripts/context-compaction-policy.sh   # loads functions and arrays
#   bash scripts/context-compaction-policy.sh     # prints policy summary
set -uo pipefail

# ── Survival categories ─────────────────────────────────────────────────────────
# These items MUST survive compaction rounds.

SURVIVORS=(
  "current_task:intencion activa y contexto inmediato de la tarea en curso"
  "decisions_with_reasons:decisiones tomadas con su justificacion (no solo el resultado)"
  "error_context:errores recientes y sus causas para evitar repeticion"
  "artifact_paths:rutas de ficheros creados o modificados en esta sesion"
  "style_rules:reglas de estilo activas que afectan al output actual"
  "last_action:ultima accion ejecutada y su resultado para continuidad de flujo"
)

# ── Droppable categories ────────────────────────────────────────────────────────
# These items CAN be dropped during compaction without data loss.

DROPPABLE=(
  "tool_dumps:volcados completos de ejecucion de herramientas (logs, output crudo)"
  "discarded_exploration:exploracion de caminos que no se tomaron"
  "stale_alternatives:alternativas evaluadas y descartadas (una vez tomada la decision)"
  "search_noise:resultados de busqueda que no llevaron a accion"
  "verbose_confirmations:confirmaciones redundantes de acciones ya completadas"
  "incremental_diffs:diffs parciales ya incorporados al codigo final"
)

# ── Protected categories ────────────────────────────────────────────────────────
# These items MUST live in system prompt, NEVER in compactable context.

PROTECTED=(
  "constitution:CONSTITUCION.md — identidad, deberes, prohibiciones, lealtad"
  "red_lines:lineas rojas inmutables — NUNCA enviar sin aprobacion, NUNCA ocultar incertidumbre"
  "radical_honesty:Regla #24 — prohibiciones y obligaciones de honestidad radical"
  "autonomous_safety:reglas de seguridad autonomica — ramas agent/*, PR Draft, reviewer humano"
  "caveman_default:restricciones base de respuesta — zero filler, token efficiency"
  "critical_rules:Rules 1-8 — PAT, WIQL, confirmacion, project CLAUDE.md, SDD gates"
)

# ── Compaction metadata ─────────────────────────────────────────────────────────

declare -A COMPACTION_META=(
  [window_warn_pct]="${CONTEXT_WINDOW_WARN:-70}"
  [window_compact_pct]="${CONTEXT_WINDOW_COMPACT:-80}"
  [window_critical_pct]="${CONTEXT_WINDOW_CRITICAL:-90}"
  [keep_head_turns]="${COMPACTION_KEEP_HEAD:-3}"
  [keep_tail_turns]="${COMPACTION_KEEP_TAIL:-5}"
  [max_compact_rounds]="${COMPACTION_MAX_ROUNDS:-3}"
)

# ── Functions ───────────────────────────────────────────────────────────────────

is_survivor() {
  local item="$1"
  for s in "${SURVIVORS[@]}"; do
    [[ "${s%%:*}" == "$item" ]] && return 0
  done
  return 1
}

is_droppable() {
  local item="$1"
  for d in "${DROPPABLE[@]}"; do
    [[ "${d%%:*}" == "$item" ]] && return 0
  done
  return 1
}

is_protected() {
  local item="$1"
  for p in "${PROTECTED[@]}"; do
    [[ "${p%%:*}" == "$item" ]] && return 0
  done
  return 1
}

should_survive_compaction() {
  local category="$1"
  if is_protected "$category"; then
    echo "PROTECTED — debe vivir en system prompt, no en contexto compactable"
    return 0
  fi
  if is_survivor "$category"; then
    echo "SURVIVES — categoria '$category' sobrevive a compactacion"
    return 0
  fi
  if is_droppable "$category"; then
    echo "DROPS — categoria '$category' puede caer en compactacion"
    return 0
  fi
  echo "UNKNOWN — categoria '$category' no clasificada"
  return 1
}

# Generate a compaction budget report
compaction_budget() {
  local used="${1:-${CONTEXT_WINDOW_USED:-0}}"
  local max="${2:-${CONTEXT_WINDOW_MAX:-200000}}"
  local warn_pct="${COMPACTION_META[window_warn_pct]}"
  local compact_pct="${COMPACTION_META[window_compact_pct]}"
  local critical_pct="${COMPACTION_META[window_critical_pct]}"

  if [[ "$max" -eq 0 ]]; then
    echo "window: unknown (env vars not set)"
    return
  fi

  local pct=$(( (used * 100) / max ))
  local status="OK"
  if (( pct >= critical_pct )); then
    status="CRITICAL"
  elif (( pct >= compact_pct )); then
    status="COMPACT"
  elif (( pct >= warn_pct )); then
    status="WARN"
  fi

  echo "window: ${used}/${max} (${pct}%) — status: ${status}"
  echo "thresholds: warn=${warn_pct}% compact=${compact_pct}% critical=${critical_pct}%"
  echo "keep: head=${COMPACTION_META[keep_head_turns]} turns, tail=${COMPACTION_META[keep_tail_turns]} turns"
  echo "max rounds: ${COMPACTION_META[max_compact_rounds]}"
}

# ── Main (standalone mode) ─────────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "=== SE-270 S7: Context Compaction Policy ==="
  echo ""

  echo "## Survivors (${#SURVIVORS[@]} categories)"
  for s in "${SURVIVORS[@]}"; do
    echo "  - ${s%%:*}: ${s#*:}"
  done
  echo ""

  echo "## Droppable (${#DROPPABLE[@]} categories)"
  for d in "${DROPPABLE[@]}"; do
    echo "  - ${d%%:*}: ${d#*:}"
  done
  echo ""

  echo "## Protected (${#PROTECTED[@]} in system prompt)"
  for p in "${PROTECTED[@]}"; do
    echo "  - ${p%%:*}: ${p#*:}"
  done
  echo ""

  echo "## Window Budget"
  compaction_budget
  echo ""

  echo "## Integration"
  echo "  Source this file: source scripts/context-compaction-policy.sh"
  echo "  Check category:   should_survive_compaction current_task"
  echo "  Budget report:    compaction_budget \$USED \$MAX"
fi
