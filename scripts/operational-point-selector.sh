#!/usr/bin/env bash
# operational-point-selector.sh — SE-029 Slice 4.
#
# Toma una sesión multi-turn + presupuesto de tokens objetivo y emite un
# plan de compresión por turno: qué ratio aplicar a cada uno respetando
# el max_ratio por task-class y la marca frozen (Slice 2 + 3).
#
# Formato de entrada (sesión): texto plano con turnos separados por
# líneas de `---TURN---`. Un turno = una sección de texto entre separadores.
#
# Estrategia (MVP, greedy determinístico):
#
#   1. Clasifica cada turno con context-task-classify (Slice 2)
#   2. Obtiene max_ratio_class y frozen flag (Slice 3)
#   3. Si frozen=true → ratio=1 (no comprime)
#   4. Si frozen=partial/false → propone ratio=max_ratio_class (cap máximo)
#   5. Calcula tamaño final total = sum(size_orig / ratio_turn)
#   6. Si cabe en budget → PLAN OK
#   7. Si no cabe → WARN: budget insuficiente, sugerir quitar turnos frozen o aumentar budget
#
# NO realiza la compresión — solo emite el plan (advisory).
#
# Usage:
#   operational-point-selector.sh --session session.txt --budget 50000
#   operational-point-selector.sh --session session.txt --budget 50000 --json
#
# Ref: SE-029 §3 (SE-029-O), ROADMAP §Tier 4.1
# Dep: scripts/context-task-classify.sh (Slice 2)
#      scripts/compress-skip-frozen.sh (Slice 3)
# Safety: read-only, set -uo pipefail.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CLASSIFIER="$REPO_ROOT/scripts/context-task-classify.sh"
FROZEN_CHECK="$REPO_ROOT/scripts/compress-skip-frozen.sh"

SESSION=""
BUDGET=""
JSON=0
SEP_PATTERN='^---TURN---$'

usage() {
  cat <<EOF
Usage:
  $0 --session FILE --budget N [--json]

  --session FILE    Sesión multi-turn, turnos separados por lineas '---TURN---'
  --budget N        Tokens objetivo totales (aprox = words * 1.3)
  --json            Output en JSON (plan estructurado)

Emite plan de compresión por turno respetando frozen + max_ratio.

Ref: SE-029 §3 (SE-029-O). Advisory-only — no comprime.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session) SESSION="$2"; shift 2 ;;
    --budget)  BUDGET="$2"; shift 2 ;;
    --json)    JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

[[ -z "$SESSION" ]] && { echo "ERROR: --session required" >&2; usage; exit 2; }
[[ -z "$BUDGET" ]] && { echo "ERROR: --budget required" >&2; usage; exit 2; }
[[ ! -f "$SESSION" ]] && { echo "ERROR: session file not found: $SESSION" >&2; exit 2; }
[[ ! "$BUDGET" =~ ^[0-9]+$ ]] && { echo "ERROR: --budget must be integer" >&2; exit 2; }
[[ ! -x "$CLASSIFIER" ]] && { echo "ERROR: classifier missing: $CLASSIFIER" >&2; exit 2; }

# Split session into turns (array of temp files).
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

awk -v sep="$SEP_PATTERN" -v tmpdir="$tmpdir" '
  BEGIN { idx=0; out=sprintf("%s/turn-%04d.txt", tmpdir, idx) }
  $0 ~ sep {
    close(out); idx++;
    out=sprintf("%s/turn-%04d.txt", tmpdir, idx);
    next
  }
  { print >> out }
  END { close(out) }
' "$SESSION"

TURN_FILES=("$tmpdir"/turn-*.txt)
N_TURNS=${#TURN_FILES[@]}

if [[ "$N_TURNS" -eq 0 ]]; then
  echo "ERROR: no turns parsed from session" >&2
  exit 2
fi

# Per-turn analysis.
total_orig_words=0
total_plan_words=0
plan_lines=()
json_entries=()

for i in "${!TURN_FILES[@]}"; do
  f="${TURN_FILES[$i]}"
  words=$(wc -w < "$f" | tr -d ' ')
  [[ "$words" -eq 0 ]] && continue

  # Classify.
  cj=$(bash "$CLASSIFIER" --input "$f" --json 2>/dev/null)
  cls=$(echo "$cj" | sed -E 's/.*"class":"([^"]+)".*/\1/')
  frozen=$(echo "$cj" | sed -E 's/.*"frozen":"([^"]+)".*/\1/')
  max_ratio=$(echo "$cj" | sed -E 's/.*"max_ratio":([0-9]+).*/\1/')

  # Pick applied ratio: frozen=true → 1, else → max_ratio (cap).
  if [[ "$frozen" == "true" ]]; then
    applied_ratio=1
  else
    applied_ratio=$max_ratio
  fi

  # Estimate post-compression words = orig / ratio (integer division).
  plan_words=$(( words / applied_ratio ))
  [[ "$plan_words" -lt 1 ]] && plan_words=1

  total_orig_words=$((total_orig_words + words))
  total_plan_words=$((total_plan_words + plan_words))

  plan_lines+=("turn=$((i+1)) class=$cls frozen=$frozen words_orig=$words ratio=${applied_ratio}:1 words_plan=$plan_words")
  json_entries+=("{\"turn\":$((i+1)),\"class\":\"$cls\",\"frozen\":\"$frozen\",\"words_orig\":$words,\"applied_ratio\":$applied_ratio,\"words_plan\":$plan_words}")
done

# Tokens ~ words * 1.3 (rough English+code heuristic).
total_orig_tokens=$(( total_orig_words * 13 / 10 ))
total_plan_tokens=$(( total_plan_words * 13 / 10 ))

# Verdict.
if [[ "$total_plan_tokens" -le "$BUDGET" ]]; then
  verdict="FITS"
  headroom=$(( BUDGET - total_plan_tokens ))
  message="Plan cabe en budget — headroom ${headroom} tokens"
else
  verdict="OVERFLOW"
  excess=$(( total_plan_tokens - BUDGET ))
  message="Plan EXCEDE budget por ${excess} tokens — considera aumentar budget o archivar turnos frozen viejos"
fi

if [[ "$JSON" -eq 1 ]]; then
  # Join JSON entries with commas.
  entries_joined=$(IFS=,; echo "${json_entries[*]}")
  cat <<JSON
{"verdict":"$verdict","n_turns":$N_TURNS,"total_orig_words":$total_orig_words,"total_plan_words":$total_plan_words,"total_orig_tokens":$total_orig_tokens,"total_plan_tokens":$total_plan_tokens,"budget":$BUDGET,"message":"$message","plan":[$entries_joined]}
JSON
else
  echo "=== SE-029 Operational Point Plan ==="
  echo "Turnos analizados: $N_TURNS"
  echo "Words originales:  $total_orig_words  (~${total_orig_tokens} tokens)"
  echo "Words plan:        $total_plan_words  (~${total_plan_tokens} tokens)"
  echo "Budget:            ${BUDGET} tokens"
  echo "Verdict:           $verdict"
  echo "$message"
  echo ""
  echo "Plan por turno:"
  for line in "${plan_lines[@]}"; do
    echo "  $line"
  done
fi

[[ "$verdict" == "OVERFLOW" ]] && exit 1
exit 0
