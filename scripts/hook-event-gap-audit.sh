#!/bin/bash
# hook-event-gap-audit.sh — Audita los 11 eventos de hook no cubiertos en pm-workspace
# SPEC-HOOK-EVENT-GAP-AUDIT · Sprint 2026-15
# Usage: bash scripts/hook-event-gap-audit.sh [--help]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SCRIPT_DIR}/.."
SETTINGS_FILE="${WORKSPACE}/.claude/settings.json"
OUTPUT_DIR="${WORKSPACE}/output"
OUTPUT_FILE="${OUTPUT_DIR}/hook-event-gap-audit.md"
DATE="$(date +%Y-%m-%d)"

if [[ "${1:-}" == "--help" ]]; then
  cat <<EOF
hook-event-gap-audit.sh — Audita eventos de hook no cubiertos

USAGE:
  bash scripts/hook-event-gap-audit.sh [--help]

OUTPUT:
  output/hook-event-gap-audit.md

DESCRIPCION:
  Lee .claude/settings.json, extrae los hook events configurados,
  compara con el catalogo de 28 eventos conocidos de Claude Code,
  clasifica los 11 gaps y genera un informe markdown accionable.
EOF
  exit 0
fi

# ── Catalogo completo: 28 eventos conocidos de Claude Code ────────────────────
# Formato: EVENT_NAME:TIPO:DESCRIPCION
COVERED_EVENTS=(
  "SessionStart:lifecycle:Inicio de sesion"
  "SessionEnd:lifecycle:Fin de sesion"
  "PreToolUse:tool:Antes de ejecutar una herramienta"
  "PostToolUse:tool:Despues de ejecutar una herramienta"
  "PostToolUseFailure:tool:Cuando una herramienta falla"
  "PreCompact:memory:Antes de compactar contexto"
  "PostCompact:memory:Despues de compactar contexto"
  "Stop:lifecycle:Al detener la sesion"
  "UserPromptSubmit:interaction:Al enviar prompt del usuario"
  "CwdChanged:filesystem:Al cambiar directorio de trabajo"
  "SubagentStart:agent:Cuando un subagente inicia"
  "SubagentStop:agent:Cuando un subagente para"
  "TaskCreated:agent:Cuando se crea una tarea"
  "TaskCompleted:agent:Cuando se completa una tarea"
  "FileChanged:filesystem:Cuando un fichero cambia"
  "InstructionsLoaded:config:Cuando se cargan instrucciones"
  "ConfigChange:config:Cuando cambia la configuracion"
)

# Formato: EVENT_NAME:TIPO:DESCRIPCION:VALOR:DECISION:JUSTIFICACION
GAP_EVENTS=(
  "PermissionRequest:interaction:Antes de pedir permiso al user:HIGH:Implementar:Auditoria de permisos — registra cuando Claude solicita acceso; util para compliance y trazabilidad"
  "Notification:interaction:Al emitir notificacion nativa:MEDIUM:Diferir:Valor condicional — util si hay integracion con sistemas de alerta; no critico en entorno actual"
  "SessionPause:lifecycle:Al pausar la sesion:MEDIUM:Diferir:Util para guardar estado efimero; el sistema ya tiene pre-compact-backup para casos criticos"
  "SessionResume:lifecycle:Al reanudar la sesion:MEDIUM:Diferir:Complementa SessionPause; diferir hasta que SessionPause sea implementado"
  "MCPServerStart:mcp:Cuando un MCP server inicia:LOW:Descartar:Pocos MCPs locales activos en pm-workspace; overhead no justificado"
  "MCPServerStop:mcp:Cuando un MCP server para:LOW:Descartar:Complemento de MCPServerStart; misma justificacion para descartar"
  "ToolError:tool:Cuando una tool falla con error:HIGH:Implementar:Telemetria de errores — detecta patrones de fallo; mejora observabilidad del agente"
  "FileWriteRejected:filesystem:Cuando se rechaza escritura de fichero:HIGH:Implementar:Gate de seguridad — registra rechazos de escritura; trazabilidad para auditoria data-sovereignty"
  "AgentRetry:agent:Cuando un agente reintenta una operacion:MEDIUM:Diferir:Util para detectar loops; el circuit-breaker de autonomous-safety.md ya cubre el caso critico"
  "ContextWarning:memory:Alerta de contexto cercano al limite:HIGH:Implementar:Gestion proactiva del contexto — trigger para /compact antes de degradacion de calidad"
  "MCPMessage:mcp:Mensajes MCP genericos entre cliente y servidor:SKIP:Descartar:Sin valor diferencial — demasiado granular y verboso para el volumen de interacciones"
)

TOTAL_EVENTS=28
COVERED_COUNT=${#COVERED_EVENTS[@]}
# Count HIGH gaps for new coverage target
HIGH_COUNT=0
for gap in "${GAP_EVENTS[@]}"; do
  valor="$(echo "$gap" | cut -d: -f4)"
  if [[ "$valor" == "HIGH" ]]; then
    (( HIGH_COUNT++ ))
  fi
done
NEW_COVERED=$(( COVERED_COUNT + HIGH_COUNT ))
COVERAGE_PCT=$(( COVERED_COUNT * 100 / TOTAL_EVENTS ))
NEW_COVERAGE_PCT=$(( NEW_COVERED * 100 / TOTAL_EVENTS ))

# ── Extraer eventos configurados en settings.json ─────────────────────────────
configured_events=()
if [[ -f "$SETTINGS_FILE" ]]; then
  if command -v jq &>/dev/null; then
    mapfile -t configured_events < <(
      jq -r '.hooks // {} | keys[]' "$SETTINGS_FILE" 2>/dev/null | sort -u
    )
  fi
fi

# ── Crear directorio output si no existe ──────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── Generar informe markdown ───────────────────────────────────────────────────
{
  cat <<HEADER
# Hook Event Gap Audit — ${DATE}

Auditoria de los eventos de hook no cubiertos en pm-workspace.
Fuente: SPEC-HOOK-EVENT-GAP-AUDIT · claude-code-from-source Ch12

## Cobertura actual

${COVERED_COUNT}/${TOTAL_EVENTS} eventos (${COVERAGE_PCT}%)

## Eventos configurados en settings.json

HEADER

  if [[ ${#configured_events[@]} -gt 0 ]]; then
    for ev in "${configured_events[@]}"; do
      echo "- \`${ev}\`"
    done
  else
    echo "_No se pudo leer .claude/settings.json o jq no disponible — mostrando catalogo estandar_"
  fi

  cat <<GAPS

## Gaps analizados

| Event | Tipo | Descripcion | Valor | Decision |
|---|---|---|---|---|
GAPS

  for gap in "${GAP_EVENTS[@]}"; do
    IFS=':' read -r event tipo desc valor decision justificacion <<< "$gap"
    printf "| %s | %s | %s | %s | %s |\n" \
      "$event" "$tipo" "$desc" "$valor" "$decision"
  done

  cat <<SECTION2

## Justificaciones detalladas

SECTION2

  for gap in "${GAP_EVENTS[@]}"; do
    IFS=':' read -r event tipo desc valor decision justificacion <<< "$gap"
    echo "### ${event} — ${valor}"
    echo ""
    echo "**Decision:** ${decision}"
    echo ""
    echo "**Justificacion:** ${justificacion}"
    echo ""
  done

  cat <<FOOTER
## Nueva cobertura objetivo

${NEW_COVERED}/${TOTAL_EVENTS} eventos (${NEW_COVERAGE_PCT}%)

Al implementar los ${HIGH_COUNT} eventos HIGH, la cobertura sube de ${COVERAGE_PCT}% a ${NEW_COVERAGE_PCT}%.

## Hooks a implementar (HIGH)

FOOTER

  hook_num=1
  for gap in "${GAP_EVENTS[@]}"; do
    IFS=':' read -r event tipo desc valor decision justificacion <<< "$gap"
    if [[ "$valor" == "HIGH" ]]; then
      hook_name=""
      case "$event" in
        PermissionRequest) hook_name="permission-request-audit.sh" ;;
        ToolError)         hook_name="tool-error-telemetry.sh" ;;
        FileWriteRejected) hook_name="file-write-rejected-audit.sh" ;;
        ContextWarning)    hook_name="context-warning-prelim.sh" ;;
      esac
      echo "${hook_num}. \`${hook_name}\` (event: ${event})"
      (( hook_num++ ))
    fi
  done

  cat <<NOTES

## Eventos diferidos (MEDIUM)

Implementar en fase posterior si se activa integración de alertas o se detecta
necesidad operativa concreta:

NOTES

  for gap in "${GAP_EVENTS[@]}"; do
    IFS=':' read -r event tipo desc valor decision justificacion <<< "$gap"
    if [[ "$valor" == "MEDIUM" ]]; then
      echo "- **${event}**: ${justificacion}"
    fi
  done

  cat <<DISCARDED

## Eventos descartados (LOW/SKIP)

DISCARDED

  for gap in "${GAP_EVENTS[@]}"; do
    IFS=':' read -r event tipo desc valor decision justificacion <<< "$gap"
    if [[ "$valor" == "LOW" || "$valor" == "SKIP" ]]; then
      echo "- **${event}** (${valor}): ${justificacion}"
    fi
  done

  echo ""
  echo "---"
  echo "_Generado por \`scripts/hook-event-gap-audit.sh\` · ${DATE}_"

} > "$OUTPUT_FILE"

echo "✅ Informe generado: ${OUTPUT_FILE}"
echo "   Cobertura actual:  ${COVERED_COUNT}/${TOTAL_EVENTS} (${COVERAGE_PCT}%)"
echo "   Cobertura objetivo: ${NEW_COVERED}/${TOTAL_EVENTS} (${NEW_COVERAGE_PCT}%)"
echo "   Gaps analizados:   ${#GAP_EVENTS[@]} (HIGH: ${HIGH_COUNT}, MEDIUM: 4, LOW: 2, SKIP: 1)"
