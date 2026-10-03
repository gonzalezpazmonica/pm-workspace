#!/usr/bin/env bash
set -uo pipefail
# context-meter.sh — SE-219 S2: context window % as first-class metric (abtop pattern)
# Ref: docs/propuestas/SE-219-abtop-patterns.md
# Ref: docs/propuestas/SE-069-context-rot-strategy-skill.md (modo --rot)
# Usage: context-meter.sh [--json] [--threshold-warn N] [--threshold-critical N]
#                         [--rot] [--pct N]
#   --rot    añade la banda y la acción de la skill context-rot-strategy
#            (verde <60 continue · amarillo <75 plan-cut · rojo <90 compact · critico clear)
#   --pct N  porcentaje directo 0-100 (prioridad sobre CONTEXT_PCT y tokens)
# Env:  CONTEXT_PCT · CONTEXT_WINDOW_USED + CONTEXT_WINDOW_MAX
#       CONTEXT_METER_SNAPSHOT (default output/context-snapshot.json, relativo al cwd)
#       CONTEXT_METER_WARN (70) · CONTEXT_METER_CRITICAL (85)
#       CONTEXT_ROT_YELLOW (60) · CONTEXT_ROT_RED (75) · CONTEXT_ROT_CRITICAL (90)
# Exit: 0 medición (también sin datos: status unknown) · 2 entrada inválida

THRESHOLD_WARN="${CONTEXT_METER_WARN:-70}"
THRESHOLD_CRITICAL="${CONTEXT_METER_CRITICAL:-85}"
ROT_YELLOW="${CONTEXT_ROT_YELLOW:-60}"
ROT_RED="${CONTEXT_ROT_RED:-75}"
ROT_CRITICAL="${CONTEXT_ROT_CRITICAL:-90}"
OUTPUT_JSON=false
ROT=false
PCT_ARG=""
PCT_ARG_SET=false
SNAPSHOT_FILE="${CONTEXT_METER_SNAPSHOT:-output/context-snapshot.json}"

die() { echo "context-meter: invalid input: $*" >&2; exit 2; }

# Entero no negativo de 1-15 dígitos (evita overflow int64 y evaluación aritmética)
is_uint() { [[ "$1" =~ ^[0-9]{1,15}$ ]]; }

need_value() { [[ $# -ge 2 ]] || die "$1 requires a value"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) OUTPUT_JSON=true; shift ;;
    --rot)  ROT=true; shift ;;
    --pct)
      need_value "$@"; PCT_ARG="$2"; PCT_ARG_SET=true; shift 2 ;;
    --threshold-warn)
      need_value "$@"; THRESHOLD_WARN="$2"; shift 2 ;;
    --threshold-critical)
      need_value "$@"; THRESHOLD_CRITICAL="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: context-meter.sh [--json] [--threshold-warn N] [--threshold-critical N] [--rot] [--pct N]"
      exit 0 ;;
    *) echo "context-meter: unknown option: $1" >&2; exit 2 ;;
  esac
done

for t in "$THRESHOLD_WARN" "$THRESHOLD_CRITICAL" "$ROT_YELLOW" "$ROT_RED" "$ROT_CRITICAL"; do
  is_uint "$t" && (( 10#$t <= 100 )) || die "threshold '$t' must be an integer 0-100"
done
(( 10#$ROT_YELLOW < 10#$ROT_RED && 10#$ROT_RED < 10#$ROT_CRITICAL )) \
  || die "rot thresholds must satisfy yellow < red < critical ($ROT_YELLOW/$ROT_RED/$ROT_CRITICAL)"

# ── Resolve usage ─────────────────────────────────────────────────────────────
USED=0
MAX=0
PCT=0
HAVE_PCT=false
SOURCE="unknown"

check_pct() {
  is_uint "$1" && (( 10#$1 <= 100 )) || die "pct '$1' must be an integer 0-100"
}

check_tokens() {
  is_uint "$1" || die "used '$1' must be a non-negative integer (max 15 digits)"
  is_uint "$2" || die "max '$2' must be a non-negative integer (max 15 digits)"
  if (( 10#$2 > 0 && 10#$1 > 10#$2 )); then die "used $1 exceeds max $2"; fi
}

if $PCT_ARG_SET; then
  check_pct "$PCT_ARG"; PCT=$((10#$PCT_ARG)); HAVE_PCT=true; SOURCE="arg"
elif [[ -n "${CONTEXT_PCT:-}" ]]; then
  check_pct "$CONTEXT_PCT"; PCT=$((10#$CONTEXT_PCT)); HAVE_PCT=true; SOURCE="env-pct"
elif [[ -n "${CONTEXT_WINDOW_USED:-}" && -n "${CONTEXT_WINDOW_MAX:-}" ]]; then
  check_tokens "$CONTEXT_WINDOW_USED" "$CONTEXT_WINDOW_MAX"
  USED=$((10#$CONTEXT_WINDOW_USED)); MAX=$((10#$CONTEXT_WINDOW_MAX)); SOURCE="env"
elif [[ -f "$SNAPSHOT_FILE" ]]; then
  # Solo enteros JSON; cualquier otro tipo se marca para rechazo
  snap=$(python3 - "$SNAPSHOT_FILE" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError) as e:
    print("unreadable snapshot: %s" % e, file=sys.stderr)
    print("BAD BAD")
    sys.exit(0)
if not isinstance(d, dict):
    print("snapshot is not a JSON object", file=sys.stderr)
    print("BAD BAD")
    sys.exit(0)
vals = [d.get("used", 0), d.get("max", 0)]
print(" ".join(str(v) if type(v) is int else "BAD" for v in vals))
PY
)
  read -r snap_used snap_max <<<"$snap"
  check_tokens "${snap_used:-BAD}" "${snap_max:-BAD}"
  USED=$((10#$snap_used)); MAX=$((10#$snap_max))
  (( MAX > 0 )) && SOURCE="snapshot"
fi

if ! $HAVE_PCT && (( MAX > 0 )); then
  PCT=$(( USED * 100 / MAX )); HAVE_PCT=true
fi

# ── Status (SE-219) ───────────────────────────────────────────────────────────
STATUS="unknown"
if $HAVE_PCT; then
  if   (( PCT >= 10#$THRESHOLD_CRITICAL )); then STATUS="critical"
  elif (( PCT >= 10#$THRESHOLD_WARN ));     then STATUS="warn"
  else                                           STATUS="ok"
  fi
fi

# ── Rot band (SE-069) ─────────────────────────────────────────────────────────
BAND="unknown"; ACTION="continue-with-caution"
if $HAVE_PCT; then
  if   (( PCT >= 10#$ROT_CRITICAL )); then BAND="critico";  ACTION="clear"
  elif (( PCT >= 10#$ROT_RED ));      then BAND="rojo";     ACTION="compact"
  elif (( PCT >= 10#$ROT_YELLOW ));   then BAND="amarillo"; ACTION="plan-cut"
  else                                     BAND="verde";    ACTION="continue"
  fi
fi

# ── Output (todos los valores ya validados como enteros o literales fijos) ────
if $OUTPUT_JSON; then
  rot_json=""
  if $ROT; then
    rot_json=$(printf ', "rot": {"band": "%s", "action": "%s", "thresholds": {"yellow": %d, "red": %d, "critical": %d}}' \
      "$BAND" "$ACTION" "$((10#$ROT_YELLOW))" "$((10#$ROT_RED))" "$((10#$ROT_CRITICAL))")
  fi
  printf '{"pct": %d, "used": %d, "max": %d, "status": "%s", "source": "%s"%s}\n' \
    "$PCT" "$USED" "$MAX" "$STATUS" "$SOURCE" "$rot_json"
else
  echo "CONTEXT_PCT=${PCT}"
  echo "CONTEXT_TOKENS_USED=${USED}"
  echo "CONTEXT_TOKENS_MAX=${MAX}"
  echo "CONTEXT_STATUS=${STATUS}"
  if $ROT; then
    echo "CONTEXT_ROT_BAND=${BAND}"
    echo "CONTEXT_ROT_ACTION=${ACTION}"
  fi
fi

exit 0
