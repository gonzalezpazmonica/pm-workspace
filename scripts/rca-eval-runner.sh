#!/usr/bin/env bash
# rca-eval-runner.sh — SE-323 S3: puntúa la suite sintética de RCA.
#
# Para cada caso de tests/evals/incident-rca/rca-cases.jsonl:
#   1. materializa el alert + señales en un directorio temporal,
#   2. ejecuta incident-rca.sh,
#   3. puntúa 3 dimensiones (0-100 cada una):
#        - root cause: coincidencia con expected_root_cause (keywords),
#        - evidencia:   >= min_evidence evidence enlazadas,
#        - red herrings: fragmentos red_herrings NO citados como causa.
#   Score global = media (por defecto) o mínimo (--min) de las 3.
#
# Uso:
#   rca-eval-runner.sh [--cases <file>] [--min|--avg] [--json]
#
# Exit: 0 score >= 80 (gate SE-323 S3), 1 score < 80 o fallo, 2 uso.
# Ref: SE-323.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
CASES="$REPO_ROOT/tests/evals/incident-rca/rca-cases.jsonl"
AGG="avg"
JSON_OUT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cases) CASES="$2"; shift 2 ;;
    --min) AGG="min"; shift ;;
    --avg) AGG="avg"; shift ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help)
      echo "usage: $0 [--cases <file>] [--min|--avg] [--json]"
      exit 0 ;;
    *) echo "ERROR: argumento desconocido '$1'" >&2; exit 2 ;;
  esac
done

[[ -f "$CASES" ]] || { echo "ERROR: cases no existe: $CASES" >&2; exit 2; }

WORK="$(mktemp -d /tmp/rca-eval-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# ── Puntuar un caso ──────────────────────────────────────────────────────────
# Args: id title severity service ts expected[] confidence min_evidence herrings[]
score_case() {
  local id="$1" title="$2" sev="$3" svc="$4" ts="$5" expected="$6" exp_conf="$7" min_ev="$8" herrings="$9"

  local case_dir="$WORK/$id"
  mkdir -p "$case_dir/signals"
  printf '{"incident_id":"%s","title":"%s","severity":"%s","service":"%s","ts":"%s"}\n' \
    "$id" "$title" "$sev" "$svc" "$ts" > "$case_dir/alert.json"
  python3 - "$CASES" "$id" "$case_dir/signals" <<'PYEOF'
import json
import os
import sys

cases = sys.argv[1]
cid = sys.argv[2]
signals_dir = sys.argv[3]
with open(cases, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        c = json.loads(line)
        if c.get("id") == cid:
            signals = c.get("signals", {})
            logs = signals.get("logs", [])
            deploys = signals.get("deploys", [])
            metrics = signals.get("metrics", {})
            if logs:
                with open(os.path.join(signals_dir, "logs.txt"), "w", encoding="utf-8") as f:
                    f.write("\n".join(logs) + "\n")
            if deploys:
                with open(os.path.join(signals_dir, "deploys.json"), "w", encoding="utf-8") as f:
                    json.dump(deploys, f, ensure_ascii=False)
            if metrics:
                with open(os.path.join(signals_dir, "metrics.json"), "w", encoding="utf-8") as f:
                    json.dump(metrics, f, ensure_ascii=False)
            break
PYEOF

  bash "$SCRIPT_DIR/incident-rca.sh" \
    --alert "$case_dir/alert.json" \
    --signals "$case_dir/signals" \
    --out "$WORK" --incident-id "$id" >/dev/null 2>&1 || return 1

  local rca="$WORK/${id}-rca.json"
  [[ -f "$rca" ]] || return 1

  python3 - "$rca" "$expected" "$exp_conf" "$min_ev" "$herrings" "$AGG" <<'PYEOF'
import json
import sys

rca_path, expected_raw, exp_conf, min_ev, herrings_raw, agg = sys.argv[1:7]
expected = json.loads(expected_raw) if expected_raw else []
herrings = json.loads(herrings_raw) if herrings_raw else []
min_ev = int(min_ev)

with open(rca_path, encoding="utf-8") as f:
    rca = json.load(f)

rc = rca.get("root_cause") or ""
conf = rca.get("confidence") or ""
evidence = rca.get("evidence") or []
dismissed = rca.get("red_herrings_dismissed") or []

# 1) Root cause: % de keywords esperadas presentes (case-insensitive)
#    Keyword especial "null" → acierta si el RCA NO inventa root_cause.
rc_lower = rc.lower()
if "null" in expected and not rc_lower.strip():
    score_rc = 100
else:
    hits = sum(1 for kw in expected if kw.lower() in rc_lower)
    score_rc = round(100 * hits / max(len(expected), 1))

# 2) Evidencia: >= min_ev → 100; proporcional por debajo
n_ev = len(evidence)
score_ev = 100 if n_ev >= min_ev else (0 if min_ev == 0 else round(100 * n_ev / min_ev))

# 3) Red herrings: fragmentos NO citados como causa (ni en root_cause ni en next_steps)
combined = (rc + " " + " ".join(rca.get("next_steps", []))).lower()
dismissed_ok = sum(1 for h in herrings if h.lower() not in combined)
score_rh = round(100 * dismissed_ok / max(len(herrings), 1)) if herrings else 100

scores = [score_rc, score_ev, score_rh]
score = min(scores) if agg == "min" else round(sum(scores) / len(scores))

print(json.dumps({
    "id": rca.get("incident_id"),
    "root_cause": rc,
    "confidence": conf,
    "expected_confidence": exp_conf,
    "scores": {"root_cause": score_rc, "evidence": score_ev, "red_herrings": score_rh},
    "score": score,
    "evidence_count": n_ev,
    "conf_match": 1 if conf == exp_conf else 0,
}, ensure_ascii=False))
PYEOF
}

# ── Recorrido de casos ───────────────────────────────────────────────────────
RESULTS=()
declare -i total=0 pass=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  total+=1
  id=$(jq -r '.id' <<<"$line")
  title=$(jq -r '.title' <<<"$line")
  sev=$(jq -r '.severity' <<<"$line")
  svc=$(jq -r '.service' <<<"$line")
  ts=$(jq -r '.ts' <<<"$line")
  expected=$(jq -c '[.expected_root_cause[]]' <<<"$line")
  exp_conf=$(jq -r '.expected_confidence' <<<"$line")
  min_ev=$(jq -r '.min_evidence' <<<"$line")
  herrings=$(jq -c '[.red_herrings[]]' <<<"$line")

  res=$(score_case "$id" "$title" "$sev" "$svc" "$ts" "$expected" "$exp_conf" "$min_ev" "$herrings")
  if [[ $? -eq 0 ]] && [[ -n "$res" ]]; then
    RESULTS+=("$res")
    s=$(jq -r '.score' <<<"$res")
    if [[ "$s" -ge 80 ]]; then pass+=1; fi
  else
    RESULTS+=("{\"id\":\"$id\",\"score\":0,\"error\":\"runner_failed\"}")
  fi
done < "$CASES"

# ── Agregado ─────────────────────────────────────────────────────────────────
if [[ ${#RESULTS[@]} -eq 0 ]]; then
  [[ "$JSON_OUT" -eq 1 ]] && echo '{"verdict":"FAIL","cases":0,"score":0,"per_case":[]}'
  echo "FAIL: sin casos ejecutables" >&2
  exit 1
fi

python3 - "${RESULTS[@]}" "$JSON_OUT" "$total" <<'PYEOF'
import json
import sys

results = sys.argv[1:-2]
json_out = sys.argv[-2] == "1"
total = int(sys.argv[-1])

parsed = [json.loads(r) for r in results]
scores = [p.get("score", 0) for p in parsed]
avg = round(sum(scores) / len(scores))
conf_match = sum(p.get("conf_match", 0) for p in parsed)

if json_out:
    print(json.dumps({
        "verdict": "PASS" if avg >= 80 else "FAIL",
        "cases": total,
        "passed": sum(1 for s in scores if s >= 80),
        "score": avg,
        "confidence_match": conf_match,
        "per_case": parsed,
    }, ensure_ascii=False, indent=2))
else:
    print(f"score={avg}/100 cases={total} passed={sum(1 for s in scores if s>=80)} conf_match={conf_match}/{total}")
    for p in parsed:
        print(f"  {p.get('id','?'):12s} {p.get('score',0):3d}  rc={p.get('scores',{}).get('root_cause',0):3d} ev={p.get('scores',{}).get('evidence',0):3d} rh={p.get('scores',{}).get('red_herrings',0):3d} conf={p.get('confidence','?')}")
PYEOF
