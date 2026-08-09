#!/usr/bin/env bash
# savia-trace.sh — SE-313 S2: contexto distribuido de traza (W3C traceparent).
#
# Helper que inicia/cierra spans y propaga el contexto de traza:
#   - start <event> key=value ...   → imprime SAVIA_TRACEPARENT (nuevo span hijo)
#   - end <event> [duration_ms] ... → emite evento de cierre con el span padre
#
# El trace_id se hereda de SAVIA_TRACEPARENT (W3C version-00) si existe; si no,
# genera trace_id raíz nuevo. Un span hijo comparte trace_id y referencia el
# span del padre como parent_span_id.
#
# Uso:
#   export SAVIA_TRACEPARENT="$(savia-trace.sh start agent.started agent_name=x)"
#   ... trabajo ...
#   savia-trace.sh end agent.completed agent_name=x duration_ms=100
#
# Exit codes: 0 ok, 1 error de argumentos, 2 evento vacío.
set -uo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
EMIT="$REPO_ROOT/scripts/otel-emit.sh"
ACTION="${1:-}"
[[ -z "$ACTION" ]] && { echo "usage: savia-trace.sh [start|end] <event> [key=value ...]" >&2; exit 1; }
shift

EVENT="${1:-}"
[[ -z "$EVENT" ]] && { echo "ERROR: evento requerido" >&2; exit 2; }
shift

# ── Heredar o generar traceparent ──────────────────────────────────────────
# SAVIA_TRACEPARENT heredado: "00-{trace}-{span}-{flags}"
TP="${SAVIA_TRACEPARENT:-}"
if [[ "$TP" =~ ^00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$ ]]; then
  INHERITED_TRACE="${TP:3:32}"
  PARENT_SPAN="${TP:36:16}"
else
  INHERITED_TRACE="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  PARENT_SPAN=""
fi
NEW_SPAN="$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"

# ── start: emite el span y devuelve traceparent hijo ──────────────────────
if [[ "$ACTION" == "start" ]]; then
  # El evento de apertura pertenece a la traza que se propaga: se emite con
  # un traceparent que comparte trace_id. Si hay padre, referenciamos el span
  # heredado como parent; si es raíz, referenciamos el nuevo span (placeholder).
  if [[ -n "$PARENT_SPAN" ]]; then
    emit_tp="00-${INHERITED_TRACE}-${PARENT_SPAN}-01"
  else
    emit_tp="00-${INHERITED_TRACE}-${NEW_SPAN}-01"
  fi
  EMIT_ARGS=("$EVENT")
  EMIT_ARGS+=("$@")
  [[ -x "$EMIT" ]] && SAVIA_TRACEPARENT="$emit_tp" "$EMIT" "${EMIT_ARGS[@]}" >/dev/null 2>&1
  # El traceparent que se propaga es el del nuevo span (hijos de este nivel).
  echo "00-${INHERITED_TRACE}-${NEW_SPAN}-01"
  exit 0
fi

# ── end: cierra el span restaurando el traceparent del padre ──────────────
if [[ "$ACTION" == "end" ]]; then
  # El evento de cierre es hijo del span actual (el traceparent heredado ya
  # apunta a él: parent_span_id lo deriva otel-emit.sh).
  EMIT_ARGS=("$EVENT")
  EMIT_ARGS+=("$@")
  [[ -x "$EMIT" ]] && "$EMIT" "${EMIT_ARGS[@]}" >/dev/null 2>&1
  # Restaurar el traceparent del padre (el que entró), sin span propio.
  if [[ -n "$PARENT_SPAN" ]]; then
    echo "00-${INHERITED_TRACE}-${PARENT_SPAN}-01"
  else
    echo ""
  fi
  exit 0
fi

echo "usage: savia-trace.sh [start|end] <event> [key=value ...]" >&2
exit 1
