#!/usr/bin/env bash
# implementation-readiness.sh — Gate pre-implementacion (SE-269 S2)
# Verifica que una spec esta lista para codificar.
# Uso: bash scripts/implementation-readiness.sh <spec-file>
# Salida: JSON con veredicto ternario + informe por dimension

set -uo pipefail

SPEC_FILE="${1:-}"
[[ -z "$SPEC_FILE" ]] && { echo '{"error":"Se requiere fichero spec"}' >&2; echo "Uso: $0 <spec-file>" >&2; exit 1; }
[[ ! -f "$SPEC_FILE" ]] && { echo "{\"error\":\"Fichero no encontrado: $SPEC_FILE\"}" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── safe_grep_count: robust grep -c that always returns a single int ──
safe_grep_count() {
  local pattern="$1" file="$2" val
  val=$(grep -cE "$pattern" "$file" 2>/dev/null || true)
  val=$(echo "$val" | head -1 | tr -d '[:space:]')
  [[ -z "$val" || ! "$val" =~ ^[0-9]+$ ]] && echo "0" || echo "$val"
}

check_acs_falsifiable() {
  local ac_count; ac_count=$(safe_grep_count 'AC-[0-9]+\.[0-9]+' "$SPEC_FILE")
  if [[ "$ac_count" -le 0 ]]; then
    echo '{"nombre":"ACs falsificables","banda":"FALLA","hallazgos":["La spec no contiene acceptance criteria (AC-X.Y)"]}'
    return
  fi
  local vague; vague=$(safe_grep_count '(opcional|si es posible|cuando se pueda|idealmente|tal vez)' "$SPEC_FILE")
  if [[ "$vague" -gt 0 ]]; then
    echo "{\"nombre\":\"ACs falsificables\",\"banda\":\"RESERVAS\",\"hallazgos\":[\"$vague ACs contienen lenguaje vago (opcional/si es posible/idealmente)\"]}"
  else
    echo '{"nombre":"ACs falsificables","banda":"PASA","hallazgos":[]}'
  fi
}

check_out_of_scope() {
  if grep -qE 'Out of scope|Fuera de alcance|NO (se|incluye|implementa|cubre)' "$SPEC_FILE" 2>/dev/null; then
    echo '{"nombre":"Out of scope explicito","banda":"PASA","hallazgos":[]}'
  else
    echo '{"nombre":"Out of scope explicito","banda":"RESERVAS","hallazgos":["La spec no declara explicitamente que queda fuera de alcance"]}'
  fi
}

check_riesgos() {
  if grep -qE 'Riesgos identificados|R[0-9]+ \(S[0-9]\)' "$SPEC_FILE" 2>/dev/null; then
    local with_mitigacion; with_mitigacion=$(safe_grep_count 'Mitigacion:|Mitigaci.n:' "$SPEC_FILE")
    local total_risks; total_risks=$(safe_grep_count '^\-\s+\*\*R[0-9]+' "$SPEC_FILE")
    if [[ "$with_mitigacion" -ge "$total_risks" ]]; then
      echo '{"nombre":"Riesgos con mitigacion","banda":"PASA","hallazgos":[]}'
    else
      echo "{\"nombre\":\"Riesgos con mitigacion\",\"banda\":\"RESERVAS\",\"hallazgos\":[\"$total_risks riesgos, $with_mitigacion con mitigacion explicita\"]}"
    fi
  else
    echo '{"nombre":"Riesgos con mitigacion","banda":"RESERVAS","hallazgos":["La spec no identifica riesgos pre-flight"]}'
  fi
}

check_trazabilidad() {
  local has_refs; has_refs=$(safe_grep_count 'SE-[0-9]+|CRIT-[0-9]+|BR[0-9]+|AB#[0-9]+' "$SPEC_FILE")
  if [[ "$has_refs" -gt 0 ]]; then
    echo '{"nombre":"Trazabilidad a requisito/BR","banda":"PASA","hallazgos":[]}'
  else
    echo '{"nombre":"Trazabilidad a requisito/BR","banda":"RESERVAS","hallazgos":["La spec no referencia otros artefactos (SE-/CRIT-/BR-/AB#)"]}'
  fi
}

check_slices_utilizables() {
  local has_effort; has_effort=$(safe_grep_count '\*\*Esfuerzo:\*\*' "$SPEC_FILE")
  local has_slices; has_slices=$(safe_grep_count '## Slice [0-9]+' "$SPEC_FILE")
  if [[ "$has_slices" -gt 0 && "$has_effort" -ge "$has_slices" ]]; then
    echo '{"nombre":"Slices con hito utilizable","banda":"PASA","hallazgos":[]}'
  elif [[ "$has_slices" -gt 0 ]]; then
    echo "{\"nombre\":\"Slices con hito utilizable\",\"banda\":\"RESERVAS\",\"hallazgos\":[\"$has_slices slices, $has_effort con estimacion de esfuerzo\"]}"
  else
    echo '{"nombre":"Slices con hito utilizable","banda":"RESERVAS","hallazgos":["La spec no esta descompuesta en slices con esfuerzo estimado"]}'
  fi
}

check_status() {
  local status; status=$(grep -m1 '\*\*Status:\*\*' "$SPEC_FILE" 2>/dev/null | sed 's/.*\*\*Status:\*\* *//' || echo "DESCONOCIDO")
  case "$status" in
    APPROVED|APPROVED*|IMPLEMENTING*) echo '{"nombre":"Estado de la spec","banda":"PASA","hallazgos":[]}' ;;
    PROPOSED) echo '{"nombre":"Estado de la spec","banda":"RESERVAS","hallazgos":["Spec en estado PROPOSED — no aprobada aun"]}' ;;
    *) echo "{\"nombre\":\"Estado de la spec\",\"banda\":\"RESERVAS\",\"hallazgos\":[\"Estado desconocido o no estandar: $status\"]}" ;;
  esac
}

# ── Run all checks ──
DIMENSIONS=()
DIMENSIONS+=("$(check_acs_falsifiable)")
DIMENSIONS+=("$(check_out_of_scope)")
DIMENSIONS+=("$(check_riesgos)")
DIMENSIONS+=("$(check_trazabilidad)")
DIMENSIONS+=("$(check_slices_utilizables)")
DIMENSIONS+=("$(check_status)")

# ── Aggregate verdict ──
PASA_COUNT=0; RESERVAS_COUNT=0; FALLA_COUNT=0

for dim in "${DIMENSIONS[@]}"; do
  banda=$(echo "$dim" | python3 -c "import sys,json; print(json.load(sys.stdin)['banda'])" 2>/dev/null || echo "ERROR")
  case "$banda" in
    PASA) PASA_COUNT=$((PASA_COUNT + 1)) ;;
    RESERVAS) RESERVAS_COUNT=$((RESERVAS_COUNT + 1)) ;;
    FALLA) FALLA_COUNT=$((FALLA_COUNT + 1)) ;;
  esac
done

if [[ "$FALLA_COUNT" -gt 0 ]]; then
  VEREDICTO="FALLA"; MOTIVO="$FALLA_COUNT dimension(es) no superadas"
elif [[ "$RESERVAS_COUNT" -gt 0 ]]; then
  VEREDICTO="RESERVAS"; MOTIVO="$RESERVAS_COUNT dimension(es) con reservas, $PASA_COUNT pasan"
else
  VEREDICTO="PASA"; MOTIVO="Todas las dimensiones superadas"
fi

# ── Write audit log ──
AUDIT_LOG="${AUDIT_LOG:-output/ternary-ratio-audit.jsonl}"
mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null
python3 -c "
import json, os

entry = {
    'veredicto': '$VEREDICTO',
    'spec': '$SPEC_FILE',
    'pasa': $PASA_COUNT,
    'reservas': $RESERVAS_COUNT,
    'falla': $FALLA_COUNT
}
log_path = '$AUDIT_LOG'
logs = []
if os.path.exists(log_path):
    with open(log_path) as f:
        logs = [json.loads(l) for l in f if l.strip()]
logs = logs[-99:] + [entry]

total = len(logs)
if total >= 10:
    reservas_pct = sum(1 for l in logs if l.get('veredicto') == 'RESERVAS') * 100 / total
    if reservas_pct > 70:
        entry['ratio_warning'] = f'RESERVAS ratio {reservas_pct:.0f}% > 70% — posible binario cobarde (AC-2.5)'

with open(log_path, 'w') as f:
    for l in logs:
        f.write(json.dumps(l, ensure_ascii=False) + '\n')
" 2>/dev/null

# ── Emit final verdict (safe: one JSONL entry per line in temp file) ──
DIMS_TMP="$(mktemp)"
printf '%s\n' "${DIMENSIONS[@]}" > "$DIMS_TMP"

DIMS_JSON=$(python3 -c "
import json
dims = []
with open('$DIMS_TMP') as f:
    for line in f:
        line = line.strip()
        if line:
            dims.append(json.loads(line))
print(json.dumps(dims, ensure_ascii=False))
" 2>/dev/null || echo "[]")
rm -f "$DIMS_TMP"

GATE_TYPE="juicio" bash "$SCRIPT_DIR/ternary-verdict.sh" \
  --banda "$VEREDICTO" \
  --motivo "$MOTIVO" \
  --dimensiones "$DIMS_JSON" \
  ${OWNER:+--owner "$OWNER"}
