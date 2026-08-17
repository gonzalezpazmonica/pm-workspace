#!/usr/bin/env bash
# learning-recall.sh — SCL-003 S1: recupera lecciones aprendidas relevantes de
# la cúpula SaviaLearning para el contexto de trabajo actual.
#
# Sin recall el bucle es un almacén muerto: las lecciones se guardan pero nadie
# las consulta cuando se trabaja. Este script cierra ese gap — dado un contexto
# (proyecto, tarea, keywords, prompt), busca en la cúpula las lecciones con
# BM25 (SaviaVaults search) y las devuelve formateadas para inyectar al agente.
#
# Usage:
#   learning-recall.sh --query "<contexto de trabajo>"
#     [--top <N>] [--vault <path>] [--node-path <path>] [--json]
#   learning-recall.sh --query "feature auth" --top 3
#
# Exit codes: 0 ok (con o sin resultados), 2 usage, 3 vault/node missing
#
# Ref: docs/specs/SCL-003-recall-operativo.spec.md
# PURE_BASH — sin bindings de frontend.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

QUERY=""
TOP=5
MIN_SCORE="${SCL_RECALL_MIN_SCORE:-5}"
VAULT="${SCL_VAULT_DIR:-$ROOT/vaults/SaviaLearning}"
NODE_BIN=""
JSON=false
RECALL_LOG="${SCL_RECALL_LOG:-$ROOT/output/learning-loop/recall.jsonl}"

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query) QUERY="$2"; shift 2 ;;
    --top) TOP="$2"; shift 2 ;;
    --min-score) MIN_SCORE="$2"; shift 2 ;;
    --vault) VAULT="$2"; shift 2 ;;
    --node-path) NODE_BIN="$2"; shift 2 ;;
    --json) JSON=true; shift ;;
    --recall-log) RECALL_LOG="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

[[ -z "$QUERY" ]] && usage
[[ -d "$VAULT" ]] || { echo "ERROR: vault not found: $VAULT" >&2; exit 3; }

# ── Locate node (SaviaVaults CLI) ──
if [[ -z "$NODE_BIN" ]]; then
  # Try nvm node, then PATH
  for cand in "$HOME/.nvm/versions/node"/*/bin/node /usr/local/bin/node /usr/bin/node; do
    [[ -x "$cand" ]] && { NODE_BIN="$cand"; break; }
  done
fi
CLI="$ROOT/projects/savia-vaults/dist/cli/index.js"
if [[ -z "$NODE_BIN" || ! -f "$CLI" ]]; then
  echo "ERROR: SaviaVaults CLI no disponible (node o projects/savia-vaults/dist/cli/index.js)" >&2
  exit 3
fi

# ── Search the dome for relevant lessons ──
SEARCH_OUT=$("$NODE_BIN" "$CLI" search "$QUERY" --path "$VAULT" --json 2>/dev/null) || true
if [[ -z "$SEARCH_OUT" || "$SEARCH_OUT" == "[]" ]]; then
  # No relevant lessons — no-op (sin ruido)
  mkdir -p "$(dirname "$RECALL_LOG")"
  printf '{"ts":"%s","query":"%s","hits":0}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$QUERY" >> "$RECALL_LOG" 2>/dev/null || true
  if $JSON; then printf '{"query":"%s","hits":[]}\n' "$QUERY"; fi
  exit 0
fi

# ── Parse and format lessons (top N) ──
FORMATTED=""
HITS=0
if command -v python3 >/dev/null 2>&1; then
  FORMATTED=$(SCL_TOP="$TOP" SCL_MIN_SCORE="$MIN_SCORE" python3 - "$SEARCH_OUT" <<'PY'
import json, os, sys
try:
    results = json.loads(sys.argv[1]) if sys.argv[1].strip().startswith('[') else json.load(sys.stdin)
except Exception:
    results = []
if not isinstance(results, list): results = []
top = int(os.environ.get('SCL_TOP', '5'))
min_score = float(os.environ.get('SCL_MIN_SCORE', '5'))
rows = []
for r in results[:top]:
    score = r.get('score', 0)
    if score < min_score:
        continue  # filtro de relevancia: evita ruido de BM25 con score bajo
    path = r.get('path') or r.get('source') or r.get('entity') or ''
    snippet = (r.get('snippet') or r.get('value') or '')[:160].replace('\n', ' ')
    rows.append({'path': path, 'score': score, 'snippet': snippet})
print(json.dumps({'hits': rows}))
PY
)
  # HITS se cuenta SIEMPRE (usado por el log de utilidad, no solo por el formato)
  HITS=$(echo "$FORMATTED" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('hits',[])))" 2>/dev/null || echo 0)
  if $JSON; then
    echo "$FORMATTED"
  else
    echo "=== Lecciones aprendidas relevantes (${HITS}) ==="
    echo "$FORMATTED" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for h in d.get('hits',[]):
    print(f\"- {h['path']} (score {h['score']:.2f})\")
    print(f\"    {h['snippet']}\")"
  fi
else
  echo "$SEARCH_OUT" | head -c 2000
fi

# ── Log the recall (para métrica de utilidad) ──
mkdir -p "$(dirname "$RECALL_LOG")"
printf '{"ts":"%s","query":"%s","hits":%s}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$QUERY" "$HITS" >> "$RECALL_LOG" 2>/dev/null || true
exit 0
