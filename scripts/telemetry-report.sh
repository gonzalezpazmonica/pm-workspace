#!/usr/bin/env bash
# telemetry-report.sh — SE-313 S8 (degradación): informe estático de telemetría.
#
# Genera output/telemetry-report-{YYYYMMDD}.md con el resumen de
# telemetry-events.jsonl (schema savia.event/1.0). Reemplaza el endpoint
# /telemetry mientras savia-web no esté disponible (spec SE-313 S8).
#
# Uso: telemetry-report.sh [--since <offset>]
# Exit: 0 ok, 1 sin eventos, 2 usage.
set -uo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TELEMETRY="$REPO_ROOT/output/telemetry-events.jsonl"
SINCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    *) echo "usage: telemetry-report.sh [--since <offset>]" >&2; exit 2 ;;
  esac
done

[[ -f "$TELEMETRY" ]] || { echo "SKIP: no existe telemetry-events.jsonl"; exit 1; }
mkdir -p "$REPO_ROOT/output" 2>/dev/null || true
DATE="$(date -u +%Y%m%d)"
OUT="$REPO_ROOT/output/telemetry-report-${DATE}.md"

# ── Agregar por evento (con filtro --since si se pide) ──────────────────────
PYSCRIPT=$(cat << 'PYEOF'
import sys, json, os
from collections import Counter
since = os.environ.get("REPORT_SINCE", "")
counts = Counter()
by_event = {}
models = Counter()
agents = Counter()
errors = Counter()
total = 0
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        ev = json.loads(line)
    except Exception:
        continue
    ts = ev.get("ts", "")
    if since:
        try:
            from datetime import datetime, timedelta, timezone
            n = int(since[:-1]); unit = since[-1]
            cutoff = datetime.now(timezone.utc) - timedelta(**{unit: n})
            if datetime.fromisoformat(ts.replace("Z", "+00:00")) < cutoff:
                continue
        except Exception:
            pass
    total += 1
    e = ev.get("event", "unknown")
    counts[e] += 1
    by_event.setdefault(e, []).append(ev)
    m = ev.get("gen_ai_request_model") or ev.get("resolved_model") or ev.get("gen_ai_response_model")
    if m:
        models[m] += 1
    a = ev.get("agent_name")
    if a:
        agents[a] += 1
    if ev.get("event") in ("dispatch.failed", "classifier.block"):
        err = ev.get("error") or ev.get("reason") or "unknown"
        errors[err] += 1

print("TOTAL_EVENTS=", total)
print()
print("## Resumen por evento")
for e, c in counts.most_common():
    print(f"- **{e}**: {c}")
print()
print("## Modelos")
for m, c in models.most_common():
    print(f"- {m}: {c}")
print()
print("## Agentes")
for a, c in agents.most_common():
    print(f"- {a}: {c}")
print()
print("## Errores / bloqueos")
for er, c in errors.most_common():
    print(f"- {er}: {c}")
PYEOF
)

REPORT_SINCE="$SINCE" python3 -c "$PYSCRIPT" < "$TELEMETRY" > "$OUT" 2>/dev/null

if ! grep -q "TOTAL_EVENTS=" "$OUT" 2>/dev/null; then
  echo "SKIP: sin eventos parseables"
  rm -f "$OUT"
  exit 1
fi

# Añadir cabecera
sed -i "1i # Reporte de Telemetría — $(date -u +%Y-%m-%d)\n\n**Generado:** $(date -u +%Y-%m-%dT%H:%M:%SZ) · schema savia.event/1.0 (SE-313)" "$OUT"

echo "reporte: $OUT"
exit 0
