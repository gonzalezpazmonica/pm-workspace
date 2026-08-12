#!/usr/bin/env bash
# blast-radius.sh — SE-318 S1/S2: consulta de blast-radius pre-write.
#
# Dado un símbolo (o un rango de diff), lista los callers y ficheros
# dependientes afectados ANTES de aplicar un cambio. Backend preferido:
# codegraph (índice AST persistente, callers resueltos). Fallback: grep
# determinista sobre ficheros de código (excluye binarios y .git).
#
# Salida JSON:
#   {symbol, direct: [...], transitive: [...], files: {file: depth}, total}
#
# Uso:
#   blast-radius.sh --symbol <name> [--file <path>] [--depth <n>]
#   blast-radius.sh --diff <base..head>
#   blast-radius.sh --list-backends
#
# Exit: 0 ok (incluye símbolo inexistente → {symbol:null, files:{}}),
#       2 uso inválido. Ref: SE-318.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Repo de operación = cwd actual (el diff/símbolos se consultan en el repo
# donde se invoca el script, no en el workspace). Portable y testeable.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

MODE=""
SYMBOL=""
FILE=""
DIFF=""
DEPTH=1

usage() {
  cat <<EOF
Usage: $0 --symbol <name> [--file <path>] [--depth <n>]
       $0 --diff <base..head> [--depth <n>]
       $0 --list-backends

Blast-radius de un cambio propuesto antes de aplicarlo.

  --symbol <name>   Símbolo (función/clase) a consultar
  --file <path>     Limitar la búsqueda a un fichero (opcional)
  --diff <a..b>     Modo diff: símbolos nuevos/modificados en el rango
  --depth <n>       Profundidad transitiva (default 1 = direct + callees a 1 salto)
  --list-backends   Muestra el backend activo (codegraph|grep)

Exit: 0 ok, 2 uso inválido. Ref: SE-318 (blast-radius pre-commit).
EOF
}

[[ $# -eq 0 ]] && { usage; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --symbol) MODE="symbol"; SYMBOL="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --diff) MODE="diff"; DIFF="$2"; shift 2 ;;
    --depth) DEPTH="$2"; shift 2 ;;
    --list-backends) MODE="backends"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: argumento desconocido '$1'" >&2; usage; exit 2 ;;
  esac
done

# ── Backend activo ──────────────────────────────────────────────────────────
CODEGRAPH_BIN="$(command -v codegraph 2>/dev/null || true)"
USE_CODEGRAPH=0
if [[ -n "$CODEGRAPH_BIN" ]] && command -v jq >/dev/null 2>&1; then
  # codegraph requiere índice en el repo; verificar sin hardcodear paths
  if codegraph status >/dev/null 2>&1; then
    USE_CODEGRAPH=1
  fi
fi

# ── Extensions de código (fallback grep) ───────────────────────────────────
CODE_EXTS="sh py ts js tsx jsx java cs go rb php rs vue svelte c cpp h hpp"

list_sources() { # file optional
  local file_filter="${1:-}"
  local base="${REPO_ROOT}"
  if [[ -n "$file_filter" ]]; then
    [[ -f "$base/$file_filter" ]] && printf '%s\n' "$base/$file_filter"
    return
  fi
  # git-tracked sources (rápido y determinista), excluye .git y binarios
  local pat
  pat=$(printf '%s' "$CODE_EXTS" | sed 's/ /|/g')
  git ls-files 2>/dev/null \
    | grep -E "\.($pat)$" \
    | grep -vE "(^|/)(node_modules|\.git|\.codegraph|vendor|dist|build|__pycache__)/" \
    | sed "s|^|$base/|"
}

# ── Fallback grep: callers de un símbolo ───────────────────────────────────
grep_callers() { # symbol [file]
  local sym="$1" file_filter="${2:-}"
  local sources
  sources=$(list_sources "$file_filter")
  [[ -z "$sources" ]] && return 0
  # git grep sobre los sources (rápido, sin límite de args); filtra la
  # definición propia y referencias en imports/comentarios.
  if [[ -n "$file_filter" ]]; then
    grep -nE "\b${sym}\b" $sources 2>/dev/null \
      | grep -vE ":(#|//|/\*|\*|--|<!--)[[:space:]]*$" \
      | grep -vE "\b(import|from|require|use|include|package|module|export|#include)\b.*\b${sym}\b" \
      | grep -vE ":(def|func|function|class|public|private|protected|static|fn|sub|void|int|string|bool|var|let|const)[[:space:]]+${sym}[[:space:]]*(\()?" \
      | cut -d: -f1 \
      | sort -u \
      | sed "s|^${REPO_ROOT}/||"
  else
    local pat
    pat=$(printf '%s' "$CODE_EXTS" | sed 's/ /|/g')
    git grep -lE "\b${sym}\b" -- "*.sh" "*.py" "*.ts" "*.js" "*.tsx" "*.jsx" "*.java" "*.cs" "*.go" "*.rb" "*.php" "*.rs" "*.vue" "*.svelte" "*.c" "*.cpp" "*.h" "*.hpp" 2>/dev/null \
      | grep -vE "(^|/)(node_modules|\.git|\.codegraph|vendor|dist|build|__pycache__)/" \
      | while IFS= read -r f; do
          # descarta ficheros donde el símbolo solo aparece como definición o import
          if grep -nE "\b${sym}\b" "$REPO_ROOT/$f" 2>/dev/null \
              | grep -vE ":(#|//|/\*|\*|--|<!--)[[:space:]]*$" \
              | grep -vE "\b(import|from|require|use|include|package|module|export|#include)\b.*\b${sym}\b" \
              | grep -vE ":[[:space:]]*(def|func|function|class|public|private|protected|static|fn|sub|void|int|string|bool|var|let|const)[[:space:]]+${sym}[[:space:]]*(\()?" \
              | grep -qE ":.*\b${sym}\b"; then
            printf '%s\n' "$f"
          fi
        done
  fi
}

# ── Resolver símbolos desde un diff (S2) ───────────────────────────────────
# Extrae solo DEFINICIONES (funciones/clases) nuevas o modificadas en el diff,
# limitado a ficheros de código. Ignora llamadas/imports (ruido).
diff_symbols() { # base..head
  local range="$1"
  local base head
  base="${range%%..*}"
  head="${range##*..}"
  git diff "$base..$head" 2>/dev/null \
    | grep -E "^[+-].*\b(def|func|function|class|fn|sub|public|private|protected|static)[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*|^[+-][a-zA-Z_][a-zA-Z0-9_]*\(\)" \
    | grep -vE "^[+-]{2}" \
    | grep -oE "(def|func|function|class|fn|sub|public|private|protected|static)[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*|[a-zA-Z_][a-zA-Z0-9_]*\(\)" \
    | grep -oE "[a-zA-Z_][a-zA-Z0-9_]*$" \
    | sed -E 's/\(\)//' \
    | grep -vE "^(def|func|function|class|fn|sub|main|__init__|setup|teardown|run|start|stop|init|__main__)$" \
    | grep -vE "^(and|or|not|if|else|elif|for|while|return|import|from|class|def|with|try|except|in|is|lambda)$" \
    | sort -u
}

# ── Consulta con codegraph (si disponible) ─────────────────────────────────
codegraph_query() { # symbol
  local sym="$1"
  local raw
  raw=$(codegraph impact "$sym" --depth "$DEPTH" --json 2>/dev/null) || raw=""
  if [[ -z "$raw" ]]; then
    raw=$(codegraph callers "$sym" --json 2>/dev/null) || raw=""
  fi
  [[ -z "$raw" ]] && return 1
  printf '%s' "$raw"
}

# ── Emitir JSON final ──────────────────────────────────────────────────────
emit_result() { # symbol direct[] transitive[] [backend]
  python3 - "$1" "$2" "$3" "$4" <<'PYEOF'
import json
import sys

symbol, direct_raw, transitive_raw, backend = sys.argv[1:5]
direct = [d for d in direct_raw.splitlines() if d.strip()]
transitive = [t for t in transitive_raw.splitlines() if t.strip()]
files = {}
for f in direct + transitive:
    files[f] = 1 if f in direct else 2

result = {
    "symbol": symbol or None,
    "backend": backend or "none",
    "direct": direct,
    "transitive": transitive,
    "files": files,
    "total": len(files),
}
print(json.dumps(result, ensure_ascii=False, indent=2))
PYEOF
}

# ── Modos ───────────────────────────────────────────────────────────────────
if [[ "$MODE" == "backends" ]]; then
  if [[ "$USE_CODEGRAPH" -eq 1 ]]; then
    echo "backend=codegraph"
  else
    echo "backend=grep (codegraph no disponible o sin índice)"
  fi
  exit 0
fi

if [[ "$MODE" == "symbol" ]]; then
  if [[ -z "$SYMBOL" ]]; then
    echo "ERROR: --symbol requiere un nombre" >&2
    exit 2
  fi
  DIRECT=""
  TRANSITIVE=""
  BACKEND="grep"
  if [[ "$USE_CODEGRAPH" -eq 1 ]]; then
    RAW=$(codegraph_query "$SYMBOL") && DIRECT="$RAW" && BACKEND="codegraph"
  else
    DIRECT=$(grep_callers "$SYMBOL" "$FILE")
  fi
  # Telemetría SE-313: evento blast.radius (AC-S3.3) — nunca bloquea.
  out=$(emit_result "$SYMBOL" "$DIRECT" "$TRANSITIVE" "$BACKEND")
  printf '%s\n' "$out"
  total=$(printf '%s' "$out" | python3 -c "import sys,json;print(json.load(sys.stdin)['total'])" 2>/dev/null || echo "0")
  bash "$SCRIPT_DIR/otel-emit.sh" "blast.radius" \
    symbol="$SYMBOL" backend="$BACKEND" affected="$total" >/dev/null 2>&1 || true
  exit 0
fi

if [[ "$MODE" == "diff" ]]; then
  if [[ -z "$DIFF" ]]; then
    echo "ERROR: --diff requiere <base..head>" >&2
    exit 2
  fi
  syms=$(diff_symbols "$DIFF")
  if [[ -z "$syms" ]]; then
    emit_result "" "" "" "none"
    exit 0
  fi
  # Cap de símbolos para mantener el coste acotado (diff enormes).
  MAX_SYMS="${BLAST_RADIUS_MAX_SYMBOLS:-40}"
  syms=$(printf '%s\n' "$syms" | head -n "$MAX_SYMS")
  TMP_RESULT="$(mktemp /tmp/blast-radius-diff-XXXXXX.jsonl)"
  trap 'rm -f "$TMP_RESULT"' EXIT
  : > "$TMP_RESULT"
  while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    d=$(grep_callers "$s")
    if [[ -z "$d" ]]; then
      # Símbolo detectado en el diff sin callers: se registra en symbol_files
      # con fichero vacío para que aparezca en "symbols" del reporte.
      printf '%s\t%s\n' "$s" "" >> "$TMP_RESULT"
      continue
    fi
    while IFS= read -r f; do
      printf '%s\t%s\n' "$s" "$f" >> "$TMP_RESULT"
    done <<< "$d"
  done <<< "$syms"
  python3 - "$TMP_RESULT" <<'PYEOF'
import json
import sys

result_file = sys.argv[1]
symbol_files = {}
with open(result_file, encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t", 1)
        sym = parts[0]
        f = parts[1] if len(parts) > 1 else ""
        symbol_files.setdefault(sym, set())
        if f:
            symbol_files[sym].add(f)

files = {}
for sym, fset in symbol_files.items():
    for f in fset:
        files[f] = 1

print(json.dumps({
    "symbol": None,
    "mode": "diff",
    "symbols": sorted(symbol_files.keys()),
    "direct": sorted(files.keys()),
    "transitive": [],
    "files": files,
    "total": len(files),
}, ensure_ascii=False, indent=2))
PYEOF
  rm -f "$TMP_RESULT"
  trap - EXIT
  exit 0
fi

usage
exit 2
