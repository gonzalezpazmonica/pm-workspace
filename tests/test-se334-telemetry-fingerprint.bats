#!/usr/bin/env bats
# SE-334 S1/S2 — fingerprint determinista + issues + alertas
# Spec: docs/specs/SE-334-telemetry-intelligence.spec.md (AC-1.x, AC-2.x, AC-5.x)
# Nota: IPs de ejemplo uso IPs de documentación RFC 5737 (192.0.2.x) — nunca
# direcciones privadas reales (crédito: shield-confidencialidad).

FP="scripts/telemetry-fingerprint.py"
ISSUES="scripts/telemetry-issues.sh"
ALERT="scripts/telemetry-alert.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  FIXDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$FIXDIR"
}

event() {
  cat > "$FIXDIR/ev.json" << EOF
{"exception_type":"$1","message":"$2","error":{"exc_chain":[{"loc":["x"],"exc_type":"$1","message":"$2 $3"}]}}
EOF
}

@test "AC-1.1: mismo error con IDs/URLs/timestamps distintos → MISMO fingerprint" {
  event "DispatchError" "failed to dispatch request 550e8400-e29b-41d4-a716-446655440000" "at https://192.0.2.1:8443 2026-08-22T10:00:00Z"
  local a; a=$(python3 scripts/telemetry-fingerprint.py "$FIXDIR/ev.json")
  event "DispatchError" "failed to dispatch request 123e4567-e89b-12d3-a456-426614174000" "at https://192.0.2.2:8443 2026-08-22T11:30:00Z"
  local b; b=$(python3 scripts/telemetry-fingerprint.py "$FIXDIR/ev.json")
  [[ "$(echo "$a" | python3 -c "import sys,json;print(json.load(sys.stdin)['hash'])")" == \
     "$(echo "$b" | python3 -c "import sys,json;print(json.load(sys.stdin)['hash'])")" ]]
}

@test "AC-1.2: errores distintos → fingerprints distintos" {
  event "DispatchError" "failed to dispatch request 550e8400-e29b-41d4-a716-446655440000" "at https://192.0.2.1:8443"
  local a; a=$(python3 scripts/telemetry-fingerprint.py "$FIXDIR/ev.json")
  event "TimeoutError" "timed out after 30000ms waiting for generation" "at https://api.local"
  local b; b=$(python3 scripts/telemetry-fingerprint.py "$FIXDIR/ev.json")
  [[ "$(echo "$a" | python3 -c "import sys,json;print(json.load(sys.stdin)['hash'])")" != \
     "$(echo "$b" | python3 -c "import sys,json;print(json.load(sys.stdin)['hash'])")" ]]
}

@test "AC-1.3: otel-emit.sh --fingerprint adjunta hash + bucket" {
  SAVIA_TELEMETRY_FILE="$FIXDIR/evt.jsonl" SAVIA_FINGERPRINT=1 \
    bash scripts/otel-emit.sh dispatch.failed agent_name=explore \
      error="failed to dispatch request 550e8400-e29b-41d4-a716-446655440000"
  run bash -c "cat '$FIXDIR/evt.jsonl' | python3 -c \"import sys,json;d=json.load(sys.stdin);print('x' if d.get('fingerprint',{}).get('hash') else '')\""
  [[ "$output" == "x" ]]
}

@test "AC-1.4: el fingerprint redacta — sin URLs/IPs/UUIDs crudos en hash ni bucket" {
  event "DispatchError" "connect to https://192.0.2.1:8443 refused for request 550e8400-e29b-41d4-a716-446655440000 at 2026-08-22T10:00:00Z" ""
  local out; out=$(python3 scripts/telemetry-fingerprint.py "$FIXDIR/ev.json")
  echo "$out" | python3 -c "
import sys, json
d = json.load(sys.stdin)
blob = d['bucket'] + d['hash']
for bad in ['192.0.2.1','550e8400','api.','2026-08']:
    assert bad not in blob, f'leak: {bad}'
"
}

@test "AC-1.5: determinista — misma entrada → misma huella (100 iteraciones)" {
  event "DispatchError" "failed to dispatch request 550e8400-e29b-41d4-a716-446655440000" "at https://192.0.2.1:8443"
  local ref; ref=$(python3 scripts/telemetry-fingerprint.py "$FIXDIR/ev.json")
  local i h
  for i in $(seq 1 100); do
    h=$(python3 scripts/telemetry-fingerprint.py "$FIXDIR/ev.json")
    [[ "$ref" == "$h" ]] || return 1
  done
}

@test "AC-2.1: issues agrupa N eventos idénticos en 1 issue con count=N" {
  event "DispatchError" "failed to dispatch request 550e8400-e29b-41d4-a716-446655440000" "at https://192.0.2.1:8443"
  local evf="$FIXDIR/events.jsonl"
  for i in 1 2 3 4 5 6; do
    python3 -c "
import json
ev=json.load(open('$FIXDIR/ev.json'))
from importlib.machinery import SourceFileLoader
fp=SourceFileLoader('f','scripts/telemetry-fingerprint.py').load_module()
ev['fingerprint']=fp.fingerprint(ev)
ev['ts']='2026-08-22T10:0${i}:00Z'
print(json.dumps(ev))" >> "$evf"
  done
  TEL_FP_EVENTS="$evf" TEL_FP_ISSUES="$FIXDIR/issues.jsonl" bash "$ISSUES" >/dev/null
  run bash -c "head -1 '$FIXDIR/issues.jsonl' | python3 -c \"import sys,json;print(json.load(sys.stdin)['count'])\""
  [[ "$output" == "6" ]]
}

@test "AC-2.2/2.3: alert cruza umbral y emite JSON compatible" {
  event "DispatchError" "failed to dispatch request 550e8400-e29b-41d4-a716-446655440000" "at https://192.0.2.1:8443"
  local evf="$FIXDIR/events.jsonl" issuesf="$FIXDIR/issues.jsonl"
  for i in 1 2 3 4 5; do
    python3 -c "
import json
ev=json.load(open('$FIXDIR/ev.json'))
from importlib.machinery import SourceFileLoader
fp=SourceFileLoader('f','scripts/telemetry-fingerprint.py').load_module()
ev['fingerprint']=fp.fingerprint(ev)
ev['ts']='2026-08-22T10:0${i}:00Z'
print(json.dumps(ev))" >> "$evf"
  done
  TEL_FP_EVENTS="$evf" TEL_FP_ISSUES="$issuesf" bash "$ISSUES" >/dev/null
  echo "alert_on: count >= 5" > "$FIXDIR/pol.yaml"
  TEL_FP_ISSUES="$issuesf" TEL_FP_ALERT_LOG="$FIXDIR/alerts.jsonl" TEL_FP_POLICY="$FIXDIR/pol.yaml" \
    bash "$ALERT" >/dev/null
  [[ -f "$FIXDIR/alerts.jsonl" ]]
  python3 -c "import json; json.load(open('$FIXDIR/alerts.jsonl'))"
  grep -q "telemetry-alert" "$FIXDIR/alerts.jsonl"
}

@test "AC-5.1: scripts pasan bash -n y sin vendor names" {
  bash -n "$ISSUES" "$ALERT"
  run grep -niE "openai|anthropic|gpt-|gemini" "$ISSUES" "$ALERT" "scripts/telemetry-fingerprint.py"
  [[ "$status" -ne 0 ]]
}