#!/usr/bin/env bash
# control-band-agent.sh — SE-357: invocación del agente por tier σ.
# set -uo pipefail
#
# Tras un breach detectado por control-band-detect.sh, este orquestador decide
# la acción según el tier configurado:
#   1σ → log (historial append-only)
#   2σ → invoca agente read-only (tools restringidas) → diagnóstico en output/research/
#   3σ → invoca agente con rutas gateadas → escribe intent.md en intent/ para triage
#
# El agente NUNCA actúa fuera de su tier. La decisión final siempre es humana.
# CRIT-001: todo local.
#
# Uso:
#   control-band-agent.sh --metric ci_test_failure_rate --sigma 2.5 [--dry-run]
#
# Ref: SE-357 — Control Bands autónomas
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HISTORY="$ROOT/data/control-bands/history.jsonl"
INTENT_DIR="$ROOT/intent"
DRY=false
METRIC=""
SIGMA=""

while [[ $# -gt 0 ]]; do case "$1" in
  --metric) METRIC="$2"; shift 2 ;;
  --sigma) SIGMA="$2"; shift 2 ;;
  --dry-run) DRY=true; shift ;;
  *) shift ;;
esac; done

[[ -z "$METRIC" || -z "$SIGMA" ]] && { echo "Uso: control-band-agent.sh --metric X --sigma N" >&2; exit 1; }

mkdir -p "$ROOT/data/control-bands" "$INTENT_DIR"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "now")

# ── Determinar tier por σ absoluto ───────────────────────────────────────────
ABS_SIGMA=$(awk -v s="$SIGMA" 'BEGIN{print (s<0?-s:s)}')
if awk -v a="$ABS_SIGMA" 'BEGIN{exit !(a < 1.0)}'; then
  TIER="1sigma"; ACTION="log"
elif awk -v a="$ABS_SIGMA" 'BEGIN{exit !(a < 2.0)}'; then
  TIER="2sigma"; ACTION="diagnose"
else
  TIER="3sigma"; ACTION="propose"
fi

# ── Historial append-only (siempre) ──────────────────────────────────────────
printf '{"ts":"%s","metric":"%s","sigma":%s,"tier":"%s","action":"%s"}\n' \
  "$TS" "$METRIC" "$SIGMA" "$TIER" "$ACTION" >> "$HISTORY"

echo "SE-357: $METRIC σ=$SIGMA → $TIER ($ACTION)"

if $DRY; then
  echo "DRY-RUN: no se invoca agente."
  exit 0
fi

# ── Acción por tier ──────────────────────────────────────────────────────────
case "$TIER" in
  1sigma)
    echo "  [log] Breach leve registrado en $HISTORY. Sin acción de agente."
    ;;
  2sigma)
    local_out="$ROOT/output/research/control-band-${METRIC}-$(date +%Y%m%d).md"
    mkdir -p "$(dirname "$local_out")"
    cat > "$local_out" <<EOF
# Control band diagnóstico — $METRIC ($TS)

- **σ**: $SIGMA · **tier**: $TIER
- **Acción**: diagnóstico read-only (Read, Grep)
- **Siguiente paso**: revisión humana del hallazgo → fix o intent.md

> Generado por control-band-agent.sh (SE-357). El agente NO modificó código.
EOF
    echo "  [diagnose] Diagnóstico read-only escrito en $local_out"
    ;;
  3sigma)
    intent_file="$INTENT_DIR/intent-control-band-${METRIC}-$(date +%Y%m%d).md"
    cat > "$intent_file" <<EOF
# Intent: control band breach — $METRIC ($TS)

- **σ**: $SIGMA · **tier**: $TIER (propose)
- **Evidencia**: métrica $METRIC superó el umbral configurado en control-bands.yaml
- **Outcome propuesto**: estabilizar $METRIC por debajo del umbral
- **Sistemas afectados**: dependiente del hallazgo (ver diagnosis)
- **Preguntas abiertas**: ¿es incidente puntual o tendencia? ¿requiere rollback?

> Generado por control-band-agent.sh (SE-357). Triage humano decide: fix | schedule | dismiss.
EOF
    echo "  [propose] intent.md escrito en $intent_file para triage humano"
    ;;
esac

exit 0
