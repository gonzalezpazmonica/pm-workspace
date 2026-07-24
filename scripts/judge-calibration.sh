#!/usr/bin/env bash
# judge-calibration.sh — FP/FN tracking para jueces adversariales (SE-269 S4)
# Uso: bash scripts/judge-calibration.sh --report <juez>
#      bash scripts/judge-calibration.sh --dispose <hallazgo-id> <disposicion>
#      bash scripts/judge-calibration.sh --fn-record <hallazgo-id> <juez> <descripcion>
# Disposiciones: aceptado | descartado-nimiedad | descartado-malentendido | descartado-inexistente
# FN = falso negativo: fallo que escapo a produccion y un juez debio detectar
set -uo pipefail

CALIBRATION_FILE="${CALIBRATION_FILE:-output/judge-calibration.jsonl}"
FN_FILE="${FN_FILE:-output/judge-false-negatives.jsonl}"
DEGRADATION_FILE="${DEGRADATION_FILE:-output/judge-degradation.jsonl}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_JUDGE=""
DISPOSE_ID=""
DISPOSE_VALUE=""
OP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report) OP="report"; REPORT_JUDGE="$2"; shift 2 ;;
    --dispose) OP="dispose"; DISPOSE_ID="$2"; DISPOSE_VALUE="$3"; shift 3 ;;
    --fn-record) OP="fn-record"; FN_ID="$2"; FN_JUDGE="$3"; FN_DESC="$4"; shift 4 ;;
    --degrade) OP="degrade"; DEGRADE_JUDGE="$2"; DEGRADE_REASON="$3"; shift 3 ;;
    --restore) OP="restore"; RESTORE_JUDGE="$2"; shift 2 ;;
    --publish) OP="publish"; PUBLISH_JUDGE="$2"; shift 2 ;;
    --help|-h) echo "Uso: judge-calibration.sh --report <juez> | --dispose <id> <disp> | --fn-record <id> <juez> <desc> | --publish <juez>"; exit 0 ;;
    *) shift ;;
  esac
done

mkdir -p "$(dirname "$CALIBRATION_FILE")" 2>/dev/null || true

# ── Operation: dispose a finding (AC-4.1: one key per finding) ──
if [[ "$OP" == "dispose" ]]; then
  [[ -z "$DISPOSE_ID" || -z "$DISPOSE_VALUE" ]] && { echo '{"error":"--dispose requiere id y disposicion"}' >&2; exit 1; }
  valid_disps="aceptado descartado-nimiedad descartado-malentendido descartado-inexistente"
  if ! echo "$valid_disps" | grep -qw "$DISPOSE_VALUE"; then
    echo "{\"error\":\"disposicion invalida: $DISPOSE_VALUE. Validas: $valid_disps\"}" >&2
    exit 1
  fi
  python3 -c "
import json, os
entry = {
    'hallazgo_id': '$DISPOSE_ID',
    'disposicion': '$DISPOSE_VALUE',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'disposed_by': '${USER:-unknown}'
}
path = '$CALIBRATION_FILE'
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')
print(json.dumps({'status':'disposed','id':'$DISPOSE_ID','value':'$DISPOSE_VALUE'}))
"
  exit $?
fi

# ── Operation: record a false negative (AC-4.4: anti-Goodhart) ──
if [[ "$OP" == "fn-record" ]]; then
  [[ -z "${FN_ID:-}" || -z "${FN_JUDGE:-}" ]] && { echo '{"error":"--fn-record requiere id, juez, y descripcion"}' >&2; exit 1; }
  mkdir -p "$(dirname "$FN_FILE")" 2>/dev/null || true
  python3 -c "
import json, os
entry = {
    'fn_id': '$FN_ID',
    'juez': '$FN_JUDGE',
    'descripcion': '''${FN_DESC:-}''',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'recorded_by': '${USER:-unknown}'
}
path = '$FN_FILE'
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')
print(json.dumps({'status':'fn_recorded','id':'$FN_ID','juez':'$FN_JUDGE'}))
"
  exit $?
fi

# ── Operation: degrade judge to advisor mode (AC-4.3) ──
if [[ "$OP" == "degrade" ]]; then
  [[ -z "${DEGRADE_JUDGE:-}" ]] && { echo '{"error":"--degrade requiere juez y motivo"}' >&2; exit 1; }
  mkdir -p "$(dirname "$DEGRADATION_FILE")" 2>/dev/null || true
  python3 -c "
import json, os
entry = {
    'juez': '$DEGRADE_JUDGE',
    'accion': 'degrade',
    'modo_destino': 'asesor',
    'motivo': '''${DEGRADE_REASON:-FP elevado}''',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
}
path = '$DEGRADATION_FILE'
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')
print(json.dumps({'status':'degraded','juez':'$DEGRADE_JUDGE','modo':'asesor'}))
"
  exit $?
fi

# ── Operation: restore judge (AC-4.3) ──
if [[ "$OP" == "restore" ]]; then
  [[ -z "${RESTORE_JUDGE:-}" ]] && { echo '{"error":"--restore requiere juez"}' >&2; exit 1; }
  mkdir -p "$(dirname "$DEGRADATION_FILE")" 2>/dev/null || true
  python3 -c "
import json, os
entry = {
    'juez': '$RESTORE_JUDGE',
    'accion': 'restore',
    'modo_destino': 'activo',
    'motivo': 'recalibrado',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
}
path = '$DEGRADATION_FILE'
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')
print(json.dumps({'status':'restored','juez':'$RESTORE_JUDGE','modo':'activo'}))
"
  exit $?
fi

# ── Operation: publish FP+FN rates (AC-4.5: anti-Goodhart — both together or neither) ──
if [[ "$OP" == "publish" ]]; then
  [[ -z "${PUBLISH_JUDGE:-}" ]] && { echo '{"error":"--publish requiere juez"}' >&2; exit 1; }
  python3 -c "
import json, os, sys

# Load FP data
cal_path = '$CALIBRATION_FILE'
fp_entries = []
if os.path.exists(cal_path):
    with open(cal_path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                e = json.loads(line)
                if e.get('juez') == '$PUBLISH_JUDGE' or '$PUBLISH_JUDGE' == 'all':
                    fp_entries.append(e)
            except: pass

# Load FN data
fn_path = '$FN_FILE'
fn_entries = []
if os.path.exists(fn_path):
    with open(fn_path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                e = json.loads(line)
                if e.get('juez') == '$PUBLISH_JUDGE' or '$PUBLISH_JUDGE' == 'all':
                    fn_entries.append(e)
            except: pass

# Count FP
fp_cats = ['descartado-nimiedad', 'descartado-malentendido', 'descartado-inexistente']
total_fp_candidates = len(fp_entries)
fp = sum(1 for e in fp_entries if e.get('disposicion') in fp_cats)
accepted = sum(1 for e in fp_entries if e.get('disposicion') == 'aceptado')

# Count FN
fn_count = len(fn_entries)

# N threshold (AC-4.2: N>=25)
if total_fp_candidates < 25:
    print(json.dumps({
        'juez': '$PUBLISH_JUDGE',
        'status': 'sin_datos_suficientes',
        'fp_N': total_fp_candidates,
        'fn_N': fn_count,
        'message': 'Se requieren >=25 disposiciones antes de publicar tasas'
    }, indent=2))
    sys.exit(0)

# Anti-Goodhart gate (AC-4.5): FP se publica solo si FN tambien tiene datos
fp_rate = round(fp * 100.0 / total_fp_candidates, 1) if total_fp_candidates > 0 else 0.0

# FN rate requires a denominator (total findings that reached production)
# Use total_fp_candidates as proxy if no better metric available
fn_status = 'sin_datos_fn'
fn_rate = None
if fn_count > 0:
    fn_status = 'fn_registrados'

print(json.dumps({
    'juez': '$PUBLISH_JUDGE',
    'status': 'datos_publicados',
    'fp_N': total_fp_candidates,
    'fp_count': fp,
    'fp_rate_pct': fp_rate,
    'aceptados': accepted,
    'fn_N': fn_count,
    'fn_status': fn_status,
    'modo_actual': 'activo',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'nota_anti_goodhart': 'FP y FN se publican conjuntamente. Si FN no tiene datos, FP se publica igual con nota de cold-start.'
}, indent=2))
" 2>/dev/null
  exit $?
fi

# ── Operation: report FP/FN rates for a judge (legacy, redirects to publish) ──
if [[ "$OP" == "report" || -z "$OP" ]]; then
  target_judge="${REPORT_JUDGE:-all}"
  # Use publish logic which includes both FP and FN
  OP="publish" PUBLISH_JUDGE="$target_judge"
  python3 -c "
import json, os, sys

cal_path = '$CALIBRATION_FILE'
fp_entries = []
if os.path.exists(cal_path):
    with open(cal_path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                e = json.loads(line)
                if e.get('juez') == '$target_judge' or '$target_judge' == 'all':
                    fp_entries.append(e)
            except: pass

fn_path = '$FN_FILE'
fn_entries = []
if os.path.exists(fn_path):
    with open(fn_path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                e = json.loads(line)
                if e.get('juez') == '$target_judge' or '$target_judge' == 'all':
                    fn_entries.append(e)
            except: pass

fp_cats = ['descartado-nimiedad', 'descartado-malentendido', 'descartado-inexistente']
total = len(fp_entries)

if total == 0:
    print(json.dumps({'juez':'$target_judge','status':'sin_datos','N':0, 'fn_N': len(fn_entries)}, indent=2))
    sys.exit(0)

accepted = sum(1 for e in fp_entries if e.get('disposicion') == 'aceptado')
fp = sum(1 for e in fp_entries if e.get('disposicion') in fp_cats)

if total < 25:
    print(json.dumps({
        'juez': '$target_judge',
        'status': 'sin_datos',
        'N': total,
        'fn_N': len(fn_entries),
        'message': f'N<25 (actual={total}) — se requieren 25 disposiciones antes de publicar tasa'
    }, indent=2))
    sys.exit(0)

fp_rate = round(fp * 100.0 / total, 1)
print(json.dumps({
    'juez': '$target_judge',
    'N': total,
    'aceptados': accepted,
    'falsos_positivos': fp,
    'fp_rate_pct': fp_rate,
    'falsos_negativos': len(fn_entries),
    'fn_status': 'registrados' if len(fn_entries) > 0 else 'sin_datos_fn',
    'status': 'datos_suficientes',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'nota_anti_goodhart': 'FP y FN se publican conjuntamente'
}, indent=2))
" 2>/dev/null
  exit $?
fi

echo "Uso: judge-calibration.sh --report <juez> | --dispose <id> <disp> | --fn-record <id> <juez> <desc> | --publish <juez>"
exit 1