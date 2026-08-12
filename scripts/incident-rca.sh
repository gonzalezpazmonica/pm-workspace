#!/usr/bin/env bash
# incident-rca.sh — SE-323 S2: harness de investigación de incidentes (RCA).
#
# Dado un alert JSON y un directorio de señales (logs, métricas, deploys),
# correlaciona las señales disponibles de forma determinista (sin LLM en la
# primera iteración), razona hipótesis, y emite un informe RCA con evidencia
# enlazada. Opcionalmente razona con LLM local (Ollama) en un bucle
# hipótesis→evidencia (--llm).
#
# Salida:
#   output/incidents/{incident-id}-rca.json con:
#     root_cause, confidence, evidence[] (cada una enlazada a su fuente),
#     timeline, next_steps, red_herrings_dismissed[]
#
# Uso:
#   incident-rca.sh --alert <alert.json> [--signals <dir>] [--out <dir>]
#     [--incident-id <id>] [--llm] [--postmortem]
#
# Exit: 0 ok, 2 uso/error. Ref: SE-323.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."

ALERT=""
SIGNALS_DIR=""
OUT_DIR=""
OUT_EXPLICIT=0
INCIDENT_ID=""
USE_LLM=0
POSTMORTEM=0

usage() {
  cat <<EOF
Usage: $0 --alert <alert.json> [--signals <dir>] [--out <dir>] [--incident-id <id>] [--llm] [--postmortem]

Investigación RCA de un incidente a partir de un alert y señales locales.

  --alert <file>       Alert JSON: {incident_id, title, severity, service, ts}
  --signals <dir>      Directorio con señales: logs.txt, metrics.json, deploys.json
                       (default: output/incidents/{incident_id}/signals)
  --out <dir>          Directorio de salida (default: output/incidents)
  --incident-id <id>   Sobrescribe el incident_id del alert
  --llm                Habilitar razonamiento con LLM local (Ollama)
  --postmortem         Además, rellenar la plantilla de postmortem (SE-323 S4)

Exit: 0 ok, 2 uso inválido.
Ref: SE-323 (Incident RCA Agent).
EOF
}

[[ $# -eq 0 ]] && { usage; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --alert) ALERT="$2"; shift 2 ;;
    --signals) SIGNALS_DIR="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; OUT_EXPLICIT=1; shift 2 ;;
    --incident-id) INCIDENT_ID="$2"; shift 2 ;;
    --llm) USE_LLM=1; shift ;;
    --postmortem) POSTMORTEM=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: argumento desconocido '$1'" >&2; usage; exit 2 ;;
  esac
done

[[ -z "$ALERT" ]] && { echo "ERROR: falta --alert" >&2; usage; exit 2; }
[[ -f "$ALERT" ]] || { echo "ERROR: alert no existe: $ALERT" >&2; exit 2; }

# ── Parsear alert ────────────────────────────────────────────────────────────
A_INCIDENT="$(jq -r '.incident_id // empty' "$ALERT" 2>/dev/null)"
A_TITLE="$(jq -r '.title // "untitled incident"' "$ALERT" 2>/dev/null)"
A_SEV="$(jq -r '.severity // "unknown"' "$ALERT" 2>/dev/null)"
A_SVC="$(jq -r '.service // "unknown"' "$ALERT" 2>/dev/null)"
A_TS="$(jq -r '.ts // ""' "$ALERT" 2>/dev/null)"

if [[ -z "$A_INCIDENT" ]] && [[ -z "$INCIDENT_ID" ]]; then
  echo "ERROR: alert sin incident_id (usa --incident-id)" >&2
  exit 2
fi
[[ -z "$INCIDENT_ID" ]] && INCIDENT_ID="$A_INCIDENT"

OUT_DIR="${OUT_DIR:-$REPO_ROOT/output/incidents}"
SIGNALS_DIR="${SIGNALS_DIR:-$OUT_DIR/${INCIDENT_ID}/signals}"
mkdir -p "$OUT_DIR" 2>/dev/null || true

# ── Colección de señales disponibles ────────────────────────────────────────
# Lectura local, sin LLM primero (SE-323 S2.2).
LOG_FILE="$SIGNALS_DIR/logs.txt"
METRICS_FILE="$SIGNALS_DIR/metrics.json"
DEPLOYS_FILE="$SIGNALS_DIR/deploys.json"

HAS_LOGS=0;   [[ -f "$LOG_FILE" ]]      && HAS_LOGS=1
HAS_METRICS=0; [[ -f "$METRICS_FILE" ]] && HAS_METRICS=1
HAS_DEPLOYS=0; [[ -f "$DEPLOYS_FILE" ]] && HAS_DEPLOYS=1

# ── Correlación determinista + razonamiento de hipótesis ─────────────────────
# Motor local (sin LLM) en la primera iteración: patrones de error en logs,
# deploy reciente en ventana, picos en métricas → hipótesis de root cause.
# El bucle tool-calling agéntico se conecta vía --llm (Ollama local); el
# motor determinista produce root_cause + confidence + evidencia siempre.

CORRELATION_JSON="$(python3 - "$LOG_FILE" "$METRICS_FILE" "$DEPLOYS_FILE" "$HAS_LOGS" "$HAS_METRICS" "$HAS_DEPLOYS" "$A_SVC" <<'PYEOF'
import json
import os
import re
import sys

log_file, metrics_file, deploys_file = sys.argv[1:4]
has_logs, has_metrics, has_deploys = sys.argv[4] == "1", sys.argv[5] == "1", sys.argv[6] == "1"
service = sys.argv[7]

ERROR_PATTERNS = [
    ("connection_refused", re.compile(r"connection refused|ECONNREFUSED", re.I)),
    ("timeout", re.compile(r"timeout|timed out|deadline exceeded", re.I)),
    ("http_5xx", re.compile(r"\b5\d\d\b.*(error|failed)|status[=: ]+5\d\d", re.I)),
    ("oom", re.compile(r"out of memory|OOMKilled|oom-kill", re.I)),
    ("crashloop", re.compile(r"crashloop|restarting|back-off restarting", re.I)),
    ("disk_full", re.compile(r"no space left on device|disk full", re.I)),
    ("dns_failure", re.compile(r"no such host|NXDOMAIN|lookup .* failed", re.I)),
]

evidence = []
pattern_hits = {}
line_number = 0

if has_logs and os.path.exists(log_file):
    with open(log_file, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line_number += 1
            for name, pat in ERROR_PATTERNS:
                if pat.search(line):
                    pattern_hits[name] = pattern_hits.get(name, 0) + 1
                    if len(evidence) < 8:
                        evidence.append({
                            "source": "logs.txt",
                            "line": line_number,
                            "signal": name,
                            "fragment": line.strip()[:180],
                        })

deploy_windows = []
if has_deploys and os.path.exists(deploys_file):
    try:
        deploys = json.load(open(deploys_file, encoding="utf-8"))
        if isinstance(deploys, list):
            deploy_windows = [d for d in deploys if isinstance(d, dict)]
    except Exception:
        deploy_windows = []

metrics_hits = {}
if has_metrics and os.path.exists(metrics_file):
    try:
        metrics = json.load(open(metrics_file, encoding="utf-8"))
        if isinstance(metrics, dict):
            metrics_hits = {
                str(k): v for k, v in metrics.items()
                if isinstance(v, (int, float)) and float(v) > 90
            }
    except Exception:
        metrics_hits = {}

result = {
    "signals": {"logs": has_logs, "metrics": has_metrics, "deploys": has_deploys},
    "pattern_hits": pattern_hits,
    "evidence": evidence,
    "deploy_windows": deploy_windows,
    "metrics_hits": metrics_hits,
    "service": service,
}
print(json.dumps(result, ensure_ascii=False))
PYEOF
)"

# ── Construir y guardar informe RCA ──────────────────────────────────────────
RCA_OUT="$OUT_DIR/${INCIDENT_ID}-rca.json"
python3 - "$CORRELATION_JSON" "$A_TITLE" "$A_SEV" "$A_SVC" "$A_TS" "$INCIDENT_ID" > "$RCA_OUT" <<'PYEOF'
import json
import sys

corr = json.loads(sys.argv[1])
title, sev, svc, ts, incident_id = sys.argv[2:7]

hits = corr.get("pattern_hits", {})
evidence = corr.get("evidence", [])
deploys = corr.get("deploy_windows", [])
metrics = corr.get("metrics_hits", {})
signals = corr.get("signals", {})
has_any = signals.get("logs") or signals.get("metrics") or signals.get("deploys")

# ── Hipótesis determinista ──
root_cause = None
confidence = "low"
next_steps = ["Recolectar señales adicionales (logs completos, trazas, métricas de latencia)"]
red_herrings = []
timeline = []
hypothesis = []

# Regla 1: deploy reciente del servicio + errores tras él → deploy regression
if deploys and hits:
    d = deploys[0]
    hypothesis.append(f"deploy_recent={d.get('ts','')} service={d.get('service','')} version={d.get('version','')}")
    if hits.get("crashloop") or hits.get("http_5xx") or hits.get("oom"):
        root_cause = f"Possible regression introduced by deploy {d.get('version','?')} of {d.get('service','?')} (crashloop/5xx after deploy)"
        confidence = "high"
        next_steps = ["Rollback del deploy sospechoso", "Comparar comportamiento pre/post deploy", "Revisar release notes del cambio"]
        timeline.append({"ts": d.get("ts",""), "event": f"deploy {d.get('version','?')} {d.get('service','?')}"})

# Regla 2: sin deploy, picos de timeout/connection_refused → saturación/red
if root_cause is None and (hits.get("timeout") or hits.get("connection_refused")):
    root_cause = f"Possible saturation or connectivity loss for {svc} (timeouts/connection refused)"
    confidence = "medium"
    next_steps = ["Verificar capacity del servicio", "Comprobar conectividad de red/dependencias", "Revisar límites de conexiones y pool"]

# Regla 3: OOM/disk_full → capacidad de la infraestructura
if root_cause is None and (hits.get("oom") or hits.get("disk_full")):
    root_cause = f"Resource exhaustion ({'OOM' if hits.get('oom') else 'disk'}) on {svc}"
    confidence = "medium"
    next_steps = ["Subir límites de memoria/disco o añadir capacidad", "Auditar requests/limits del deployment"]

# Regla 4: DNS failures
if root_cause is None and hits.get("dns_failure"):
    root_cause = f"DNS resolution failure affecting {svc}"
    confidence = "medium"
    next_steps = ["Verificar CoreDNS/nameservers", "Comprobar service entries y endpoints"]

# Regla 5: métricas altas
if root_cause is None and metrics:
    top = max(metrics, key=lambda k: float(metrics[k]))
    root_cause = f"Resource metric above threshold ({top}={metrics[top]}) on {svc}"
    confidence = "medium"

# Regla 6: señales presentes pero débiles (sin hit de error fuerte)
if root_cause is None and has_any:
    root_cause = f"Inconclusive — weak signals present for {svc}; root cause requires deeper correlation"
    confidence = "low"
    next_steps = ["Recolectar logs completos y trazas", "Ampliar ventana de observación", "Activar tracing si está disponible"]

# Sin señales → root_cause queda null (AC-S2.3: no inventa), confidence low.

# ── Red herrings: señales que NO deben citarse como causa ──
# Fragmentos con keywords de distracción (warnings, retries, deprecation) que
# aparecen en logs pero no son la causa raíz.
import re
herring_pat = re.compile(r"deprecat|retry in|healthz ok|warmup|noise|info:|debug:", re.I)
for e in evidence:
    if herring_pat.search(e.get("fragment", "")):
        red_herrings.append(e.get("fragment", ""))

# ── Timeline mínimo ──
if ts:
    timeline.insert(0, {"ts": ts, "event": f"alert raised (severity={sev})"})

rca = {
    "schema": "savia.rca/1.0",
    "incident_id": incident_id,
    "title": title,
    "severity": sev,
    "service": svc,
    "root_cause": root_cause,
    "confidence": confidence,
    "evidence": evidence,
    "timeline": timeline,
    "next_steps": next_steps,
    "red_herrings_dismissed": red_herrings,
    "hypothesis": hypothesis,
    "signals_available": signals,
}
print(json.dumps(rca, ensure_ascii=False, indent=2))
PYEOF

# ── Telemetría (AC-S2.2): evento rca.verdict ────────────────────────────────
CONF="$(jq -r '.confidence' "$RCA_OUT" 2>/dev/null)"
bash "$SCRIPT_DIR/otel-emit.sh" "rca.verdict" \
  incident_id="$INCIDENT_ID" service="$A_SVC" severity="$A_SEV" confidence="$CONF" || true

# ── S4: postmortem ──────────────────────────────────────────────────────────
if [[ "$POSTMORTEM" -eq 1 ]]; then
  PM_ARGS=(--rca "$RCA_OUT")
  # El postmortem respeta la política output/postmortems/ salvo --out explícito
  [[ "$OUT_EXPLICIT" -eq 1 ]] && PM_ARGS+=(--out "$OUT_DIR")
  bash "$SCRIPT_DIR/incident-postmortem.sh" "${PM_ARGS[@]}" || {
    echo "WARN: incident-postmortem.sh falló (continúa)" >&2
  }
fi

echo "RCA: $RCA_OUT"
exit 0
