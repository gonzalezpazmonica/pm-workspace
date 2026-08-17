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
HYBRID=false
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
    --hybrid) HYBRID=true; shift ;;
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
if $HYBRID; then
  # SCL-005 híbrido: candidatos = todas las lecciones del dir (sin depender del
  # índice BM25, que no matchea sinónimos). Luego re-ranking semántico.
  CANDIDATES="[]"
  if [[ -d "$VAULT/learning" ]]; then
    CANDIDATES=$(python3 - "$VAULT/learning" <<'PY'
import json, os, sys
d = sys.argv[1]
rows = []
for f in sorted(os.listdir(d)):
    if not f.endswith('.md'): continue
    path = f"learning/{f}"
    try:
        text = open(os.path.join(d, f)).read()
    except Exception:
        text = ""
    rows.append({"path": path, "score": 0, "snippet": text})
print(json.dumps(rows))
PY
)
  fi
  SEARCH_OUT="$CANDIDATES"
else
  SEARCH_OUT=$("$NODE_BIN" "$CLI" search "$QUERY" --path "$VAULT" --json 2>/dev/null) || true
fi
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
  FORMATTED=$(SCL_TOP="$TOP" SCL_MIN_SCORE="$MIN_SCORE" SCL_HYBRID="$HYBRID" python3 - "$SEARCH_OUT" <<'PY'
import json, os, sys
try:
    results = json.loads(sys.argv[1]) if sys.argv[1].strip().startswith('[') else json.load(sys.stdin)
except Exception:
    results = []
if not isinstance(results, list): results = []
top = int(os.environ.get('SCL_TOP', '5'))
min_score = float(os.environ.get('SCL_MIN_SCORE', '5'))
hybrid = os.environ.get('SCL_HYBRID', 'false') == 'true'
rows = []
# En híbrido tomamos TODOS los candidatos (el re-ranking semántico decide);
# en BM25 puro limitamos a top y filtramos por score.
candidates = results if hybrid else results[:top]
for r in candidates:
    score = r.get('score', 0)
    if not hybrid and score < min_score:
        continue  # filtro de relevancia: evita ruido de BM25 con score bajo
    path = r.get('path') or r.get('source') or r.get('entity') or ''
    snippet = (r.get('snippet') or r.get('value') or '')
    if not hybrid:
        snippet = snippet[:160].replace('\n', ' ')
    rows.append({'path': path, 'score': score, 'snippet': snippet})
print(json.dumps({'hits': rows}))
PY
)
  # ── Hybrid re-rank (SCL-005): BM25 + embeddings semánticos ──
  if $HYBRID; then
    HYBRID_PY="$SCRIPT_DIR/learning-hybrid.py"
    if [[ -f "$HYBRID_PY" ]]; then
      # Construir payload: query + docs (texto completo de cada nota candidata)
      DOCS_JSON=$(SCL_QUERY="$QUERY" python3 - "$FORMATTED" <<'PY'
import json, os, sys
d = json.loads(sys.argv[1])
docs = [{"path": h["path"], "text": h.get("snippet", "")} for h in d.get("hits", [])]
print(json.dumps({"query": os.environ.get("SCL_QUERY", ""), "docs": docs}))
PY
)
      HYBRID_OUT=$(SCL_QUERY="$QUERY" SCL_VENV_PYTHON="${SCL_VENV_PYTHON:-$HOME/.savia/venv/bin/python}" \
        python3 "$HYBRID_PY" <<< "$DOCS_JSON" 2>/dev/null) || true
      if [[ -n "$HYBRID_OUT" ]] && echo "$HYBRID_OUT" | grep -q '"hits"'; then
        # Conservar los docs originales (snippet completo) y reordenar por score híbrido
        FORMATTED=$(SCL_ORIG="$FORMATTED" python3 - "$HYBRID_OUT" <<'PY'
import json, os, sys
hy = json.loads(sys.argv[1])
orig = json.loads(os.environ.get("SCL_ORIG", "{}"))
snippets = {h["path"]: h.get("snippet", "") for h in orig.get("hits", [])}
hits = []
for h in hy.get("hits", []):
    if h.get("score", 0) <= 0: continue
    hits.append({"path": h["path"], "score": h["score"], "snippet": snippets.get(h["path"], "")})
print(json.dumps({"hits": hits}))
PY
)
      fi
    fi
  fi
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
