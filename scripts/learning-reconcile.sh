#!/usr/bin/env bash
# learning-reconcile.sh — SCL-010: reconciliación de lecciones duplicadas/conflictivas.
#
# Detecta pares candidatos entre learning proposals de SaviaLearning y los
# clasifica en el árbol 3-bucket (SPEC-183 / reconciliation-decision-tree):
#   evolution | auto-resolve | conflict-doc
#
# NUNCA muta CRITERIO.md ni levanta provenance (RN-01, CRIT-031): la salida es
# una propuesta de clasificación + JSONL auditable. La resolución es humana.
#
# Usage:
#   learning-reconcile.sh --detect [--vault PATH]
#   learning-reconcile.sh --classify IDA IDB [--vault PATH]
#   learning-reconcile.sh --report
# PURE_BASH + python, sin red, sin LLM (CRIT-001).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT="${SCL_VAULT:-$ROOT/vaults/SaviaLearning}"
LEARN_DIR="$VAULT/learning"
REPORT="$ROOT/output/learning-loop/reconcile.jsonl"
SIM_THRESHOLD="${SCL_RECONCILE_THRESHOLD:-0.55}"

MODE=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --detect) MODE="detect"; shift ;;
    --classify) MODE="classify"; shift ;;
    --report) MODE="report"; shift ;;
    --vault) VAULT="$2"; LEARN_DIR="$VAULT/learning"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

[[ -z "$MODE" ]] && { echo "usage: $0 --detect | --classify IDA IDB | --report" >&2; exit 2; }
[[ -d "$LEARN_DIR" ]] || { echo "ERROR: no learning dir: $LEARN_DIR" >&2; exit 3; }

extract_field() {
  # $1=file $2=field (orig|provenance|lifecycle|evidence|target|criterion|diagnosis|change)
  local f="$1" k="$2"
  case "$k" in
    id)          grep -m1 '^  id: '            "$f" | sed 's/^  id: //' ;;
    provenance)  grep -m1 '^  provenance: '      "$f" | sed 's/^  provenance: //' ;;
    lifecycle)   grep -m1 '^  lifecycle: '       "$f" | sed 's/^  lifecycle: //' ;;
    evidence)    grep -m1 '^  evidence_hash: '   "$f" | sed 's/^  evidence_hash: //' ;;
    target)      grep -m1 '^  target: '          "$f" | sed 's/^  target: //' ;;
    criterion)   grep -m1 '^  criterion_id: '    "$f" | sed 's/^  criterion_id: //' ;;
    origin)      grep -m1 '^  origin: '          "$f" | sed 's/^  origin: //' | head -c 200 ;;
    diagnosis)   sed -n '/^## Diagnóstico/,/^## Cambio propuesto/p' "$f" | grep -v '^##' | tr '\n' ' ' | sed 's/  */ /g' | head -c 220 ;;
    change)      sed -n '/^## Cambio propuesto/,/^## Destino\|^## Origen\|^## Métrica/p' "$f" | grep -v '^##' | tr '\n' ' ' | sed 's/  */ /g' | head -c 220 ;;
    *) echo "" ;;
  esac
}

norm() {
  # normaliza binario para similitud (lowercase, sin puntuación)
  printf '%s' "$1" | python3 -c "
import sys, re, unicodedata
t = sys.stdin.read().lower()
t = unicodedata.normalize('NFD', t)
t = ''.join(c for c in t if unicodedata.category(c) != 'Mn')
t = re.sub(r'[^a-z0-9 ]', ' ', t)
print(' '.join(t.split()))"
}

similarity() {
  # Dice coefficient sobre tokens de dos principios normalizados
  python3 - "$1" "$2" <<'PYEOF'
import sys
def toks(s): return set(s.split())
a, b = toks(sys.argv[1]), toks(sys.argv[2])
if not a or not b: print("0.0"); sys.exit(0)
inter = len(a & b); d = 2*inter/(len(a)+len(b))
print(f"{d:.3f}")
PYEOF
}

detect() {
  local files=() f id_a prov_a princ_a tgt_a hash_a id_b prov_b princ_b tgt_b hash_b
  mapfile -t files < <(ls "$LEARN_DIR"/*.md 2>/dev/null)
  for (( i=0; i<${#files[@]}; i++ )); do
    f="${files[$i]}"
    id_a=$(extract_field "$f" id)
    hash_a=$(extract_field "$f" evidence)
    [[ -z "$hash_a" ]] && continue
    prov_a=$(extract_field "$f" provenance)
    target_a=$(extract_field "$f" target)
    principle_a=$(extract_field "$f" change)
    for (( j=i+1; j<${#files[@]}; j++ )); do
      g="${files[$j]}"
      id_b=$(extract_field "$g" id)
      hash_b=$(extract_field "$g" evidence)
      [[ -z "$hash_b" ]] && continue
      # RN-03: mismo evidence_hash = mismo evento (idempotente) → no es par
      [[ "$hash_a" == "$hash_b" ]] && continue
      prov_b=$(extract_field "$g" provenance)
      target_b=$(extract_field "$g" target)
      principle_b=$(extract_field "$g" change)
      # candidato: mismo target y alta similitud de principio/cambio
      local na nb sim
      na=$(norm "$principle_a $principle_b")
      nb=$(norm "$principle_b $principle_a")
      sim=$(similarity "$(norm "$principle_a")" "$(norm "$principle_b")")
      if [[ "$target_a" == "$target_b" ]] && ( python3 -c "exit(0 if float('$sim') >= $SIM_THRESHOLD else 1)" ); then
        echo "PAIR $id_a $id_b sim=$sim prov=$prov_a/$prov_b target=$target_a"
      fi
    done
  done
}

classify() {
  local id_a="$1" id_b="$2"
  local fa="$LEARN_DIR/${id_a}.md" fb="$LEARN_DIR/${id_b}.md"
  [[ -f "$fa" ]] || { echo "ERROR: lesson not found: $id_a" >&2; exit 3; }
  [[ -f "$fb" ]] || { echo "ERROR: lesson not found: $id_b" >&2; exit 3; }

  local pa pb ca cb ha hb target_a target_b bucket proposal
  pa=$(extract_field "$fa" provenance)
  pb=$(extract_field "$fb" provenance)
  ca=$(extract_field "$fa" change)
  cb=$(extract_field "$fb" change)
  ha=$(extract_field "$fa" evidence)
  hb=$(extract_field "$fb" evidence)
  target_a=$(extract_field "$fa" target)
  target_b=$(extract_field "$fb" target)

  # RN-03
  if [[ "$ha" == "$hb" ]]; then
    bucket="skip-idempotent"; proposal="same-evidence"
  elif [[ "$pa" == "human_authored" && "$pb" != "human_authored" ]]; then
    bucket="auto-resolve"; proposal="a-wins (human_authored)"
  elif [[ "$pb" == "human_authored" && "$pa" != "human_authored" ]]; then
    bucket="auto-resolve"; proposal="b-wins (human_authored)"
  elif [[ "$target_a" == "$target_b" ]]; then
    # ambos INFERRED o ambos human_authored, mismo target
    local sim
    sim=$(similarity "$(norm "$ca")" "$(norm "$cb")")
    if ( python3 -c "exit(0 if float('$sim') >= $SIM_THRESHOLD else 1)" ); then
      bucket="evolution"; proposal="supersedes (sim=$sim, re-expresion)"
    else
      bucket="conflict-doc"; proposal="escalate-human"
    fi
  else
    bucket="conflict-doc"; proposal="escalate-human"
  fi

  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local j
  j="{\"ts\":\"$TS\",\"id_a\":\"$id_a\",\"id_b\":\"$id_b\",\"bucket\":\"$bucket\",\"proposal\":\"$proposal\",\"prov_a\":\"$pa\",\"prov_b\":\"$pb\"}"
  echo "$j"
  echo "$j" >> "$REPORT"
  exit 0
}

report() {
  [[ -f "$REPORT" ]] || { echo "no report yet: $REPORT (run --classify primero)" >&2; exit 0; }
  python3 - "$REPORT" <<'PYEOF'
import json, sys
buckets = {}
n = 0
for line in open(sys.argv[1]):
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
    except json.JSONDecodeError:
        continue
    n += 1
    b = buckets.get(d.get('bucket'), 0) + 1
    buckets[d['bucket']] = b
print(f"pairs={n} buckets={buckets}")
PYEOF
}

mkdir -p "$(dirname "$REPORT")"
case "$MODE" in
  detect)   detect ;;
  classify) [[ ${#ARGS[@]} -eq 2 ]] || { echo "ERROR: --classify necesita IDA IDB" >&2; exit 2; }
            classify "${ARGS[0]}" "${ARGS[1]}" ;;
  report)   report ;;
esac