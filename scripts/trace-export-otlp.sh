#!/usr/bin/env bash
# trace-export-otlp.sh — SE-313 S4: export opt-in de telemetría a OTLP.
#
# Convierte output/telemetry-events.jsonl a trazas OTLP (grpc/http) solo si
# SAVIA_OTLP_ENDPOINT está configurado. Sin endpoint → no hace nada y avisa
# (zero telemetry by default — coherente con "MIT, no telemetry").
#
# Uso:
#   SAVIA_OTLP_ENDPOINT=http://collector:4318 trace-export-otlp.sh
#   SAVIA_OTLP_ENDPOINT=... trace-export-otlp.sh --since 24h
#
# Exit codes: 0 ok (o skipped sin endpoint), 1 error de export, 2 usage.
set -uo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TELEMETRY_FILE="${SAVIA_TELEMETRY_FILE:-$REPO_ROOT/output/telemetry-events.jsonl}"
ENDPOINT="${SAVIA_OTLP_ENDPOINT:-}"

SINCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    *) echo "usage: trace-export-otlp.sh [--since <offset>]" >&2; exit 2 ;;
  esac
done

if [[ -z "$ENDPOINT" ]]; then
  echo "SKIP: SAVIA_OTLP_ENDPOINT no configurado — telemetría permanece local (zero telemetry by default)."
  exit 0
fi

[[ -f "$TELEMETRY_FILE" ]] || { echo "SKIP: no hay telemetry-events.jsonl"; exit 0; }

# Convierte cada línea savia.event/1.0 a un envelope OTLP json (endpoint http
# compatible con collector v1). Fallo de export NUNCA bloquea el pipeline.
PYSCRIPT=$(cat << 'PYEOF'
import sys, json

if len(sys.argv) > 1 and sys.argv[1] == "--since":
    from datetime import datetime, timedelta, timezone
    try:
        n = int(sys.argv[2][:-1])
        unit = sys.argv[2][-1]
        since = datetime.now(timezone.utc) - timedelta(**{unit: n})
    except Exception:
        since = None
else:
    since = None

events = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        ev = json.loads(line)
    except Exception:
        continue
    ts = ev.get("ts", "")
    if since and ts:
        try:
            if datetime.fromisoformat(ts.replace("Z", "+00:00")) < since:
                continue
        except Exception:
            pass
    trace_id = ev.get("trace_id", "")
    span_id = ev.get("span_id", "")
    if not trace_id or not span_id:
        continue
    # Mapeo mínimo GenAI semconv: evento → span name, attrs planos a resource
    attributes = [{"key": k, "value": {"stringValue": str(v)}} for k, v in ev.items()
                  if k not in ("schema", "trace_id", "span_id")]
    events.append({
        "resourceSpans": [{
            "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "savia"}}]},
            "scopeSpans": [{
                "scope": {"name": "savia.event"},
                "spans": [{
                    "traceId": trace_id,
                    "spanId": span_id,
                    "name": ev.get("event", "unknown"),
                    "startTimeUnixNano": "0",
                    "endTimeUnixNano": "0",
                    "attributes": attributes,
                }],
            }],
        }],
    })

print(json.dumps(events, ensure_ascii=False))
PYEOF
)

BODY="$(python3 "$REPO_ROOT/scripts/trace-export-otlp.py" --since "$SINCE" < "$TELEMETRY_FILE" 2>/dev/null \
  || python3 -c "$PYSCRIPT" --since "$SINCE" < "$TELEMETRY_FILE" 2>/dev/null)"

[[ -z "$BODY" || "$BODY" == "[]" ]] && { echo "SKIP: sin eventos exportables"; exit 0; }

if curl -sf --max-time 10 -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "$BODY" >/dev/null 2>&1; then
  echo "OK: exportado a $ENDPOINT"
  exit 0
else
  echo "ERROR: fallo de export a $ENDPOINT (no bloqueante)" >&2
  exit 1
fi
