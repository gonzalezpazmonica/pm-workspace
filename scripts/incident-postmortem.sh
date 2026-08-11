#!/usr/bin/env bash
# incident-postmortem.sh — SE-323 S4: rellena la plantilla de postmortem
# desde un informe RCA. Conserva las secciones humanas vacías para revisión.
#
# Plantilla obligatoria (postmortem-policy.md, 7 secciones). El RCA rellena:
#   - Timeline
#   - Diagnosis Journey
#   - Resolution
# y deja vacías (para el humano):
#   - Mental Model Update
#   - Heuristic Extraction
#   - Comprehension Gap Analysis
#   - Prevention
#
# Uso:
#   incident-postmortem.sh --rca <incident-id>-rca.json [--out <dir>]
#
# Salida: output/postmortems/YYYYMMDD-{incident-id}.md
# Exit: 0 ok, 2 uso/error. Ref: SE-323.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."

RCA=""
OUT_DIR="$REPO_ROOT/output/postmortems"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rca) RCA="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "usage: $0 --rca <rca.json> [--out <dir>]"
      exit 0 ;;
    *) echo "ERROR: argumento desconocido '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$RCA" ]] && { echo "ERROR: falta --rca" >&2; exit 2; }
[[ -f "$RCA" ]] || { echo "ERROR: rca no existe: $RCA" >&2; exit 2; }

INCIDENT_ID="$(jq -r '.incident_id // "unknown"' "$RCA" 2>/dev/null)"
TITLE="$(jq -r '.title // "untitled"' "$RCA" 2>/dev/null)"
SERVICE="$(jq -r '.service // "unknown"' "$RCA" 2>/dev/null)"
ROOT_CAUSE="$(jq -r '.root_cause // "—"' "$RCA" 2>/dev/null)"
CONFIDENCE="$(jq -r '.confidence // "low"' "$RCA" 2>/dev/null)"
NEXT_STEPS="$(jq -r 'if (.next_steps | length) > 0 then ([.next_steps[]] | "- " + join("\n- ")) else "—" end' "$RCA" 2>/dev/null)"
TIMELINE="$(jq -r 'if (.timeline | length) > 0 then ([.timeline[] | "- \(.ts // "?") — \(.event // "?")"] | join("\n")) else "—" end' "$RCA" 2>/dev/null)"
EVIDENCE="$(jq -r 'if (.evidence | length) > 0 then ([.evidence[] | "- [\(.source):\(.line)] \(.signal) — \(.fragment)"] | join("\n")) else "— (sin señales — no se inventa evidencia)" end' "$RCA" 2>/dev/null)"
RH="$(jq -r 'if (.red_herrings_dismissed | length) > 0 then ([.red_herrings_dismissed[]] | "- " + join("\n- ")) else "—" end' "$RCA" 2>/dev/null)"

mkdir -p "$OUT_DIR" 2>/dev/null || true
# Fecha del incidente: primer evento del timeline (alert raised), fallback hoy
INCIDENT_DATE="$(jq -r '.timeline[0].ts // empty' "$RCA" 2>/dev/null | cut -c1-10 | tr -d '-')"
DATE_STAMP="${INCIDENT_DATE:-$(date -u +%Y%m%d)}"
OUT="$OUT_DIR/${DATE_STAMP}-${INCIDENT_ID}.md"

cat > "$OUT" <<EOF
# Postmortem — ${INCIDENT_ID}

> **Incidente:** ${TITLE}
> **Servicio:** ${SERVICE} · **Confianza RCA:** ${CONFIDENCE}
> **Generado automáticamente desde** ${RCA} (SE-323). Revisión humana obligatoria.

## Timeline

${TIMELINE}

## Diagnosis Journey

**Root cause probable (RCA):** ${ROOT_CAUSE}

**Evidencia enlazada:**
${EVIDENCE}

**Red herrings descartadas:**
${RH}

## Resolution

Pasos sugeridos (revisión humana):
${NEXT_STEPS}

## Mental Model Update

> (Revisión humana — ¿qué cambió en el modelo mental del equipo?)

## Heuristic Extraction

> (Revisión humana — mínimo 1. Formato: "Si X, chequea Y")

## Comprehension Gap Analysis

- ¿Código AI-generado?
- ¿Modelo mental preexistente?
- ¿Era preciso o stale?
- ¿Qué documentación ayudaría?

## Prevention

> (Revisión humana — ¿qué lo hubiera atrapado antes?)
EOF

echo "Postmortem: $OUT"
exit 0
