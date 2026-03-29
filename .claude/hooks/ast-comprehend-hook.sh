#!/bin/bash
set -uo pipefail
# ast-comprehend-hook.sh — PreToolUse(Edit): inyecta mapa estructural antes de editar
# Matcher: Edit | Async: false | No bloquea nunca (RN-COMP-02): exit 0 siempre

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$WORKSPACE_ROOT/scripts/ast-comprehend.sh"
MIN_LINES=50
COMPLEXITY_WARN=15

# ── Leer target del input JSON ────────────────────────────────────────────────

INPUT_JSON=""
if [[ ! -t 0 ]]; then
  INPUT_JSON=$(cat)
fi

TARGET=""
if [[ -n "$INPUT_JSON" ]]; then
  TARGET=$(echo "$INPUT_JSON" | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  fp = d.get('tool_input', {}).get('file_path', '') or d.get('file_path', '')
  print(fp)
except:
  print('')
" 2>/dev/null || true)
fi

if [[ -z "$TARGET" ]]; then
  TARGET="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
fi

[[ -z "$TARGET" || ! -f "$TARGET" ]] && exit 0

# ── Verificar mínimo de líneas ────────────────────────────────────────────────

LINE_COUNT=$(wc -l < "$TARGET" 2>/dev/null || echo "0")
[[ "$LINE_COUNT" -lt "$MIN_LINES" ]] && exit 0
[[ ! -f "$SCRIPT" ]] && exit 0

# ── Ejecutar extracción superficial ──────────────────────────────────────────

COMPREHENSION_OUTPUT=$(timeout 15 bash "$SCRIPT" "$TARGET" --surface-only 2>/dev/null || true)
[[ -z "$COMPREHENSION_OUTPUT" ]] && exit 0

# ── Extraer métricas ──────────────────────────────────────────────────────────

_py_extract() {
  echo "$COMPREHENSION_OUTPUT" | python3 -c "$1" 2>/dev/null || echo "?"
}

N_CLASSES=$(_py_extract "
import sys,json
try:
  d=json.load(sys.stdin); print(len(d.get('structure',d).get('classes',[])))
except: print('?')")

N_FUNCTIONS=$(_py_extract "
import sys,json
try:
  d=json.load(sys.stdin); print(len(d.get('structure',d).get('functions',[])))
except: print('?')")

COMPLEXITY=$(_py_extract "
import sys,json
try:
  d=json.load(sys.stdin); c=d.get('complexity',{})
  print(c.get('total_decision_points',d.get('complexity_approx','?')))
except: print('?')")

TOOL_USED=$(_py_extract "
import sys,json
try:
  d=json.load(sys.stdin); print(d.get('meta',{}).get('tool','grep-structural'))
except: print('grep-structural')")

FILENAME=$(basename "$TARGET")

WARN_MSG=""
if [[ "$COMPLEXITY" =~ ^[0-9]+$ && "$COMPLEXITY" -gt "$COMPLEXITY_WARN" ]]; then
  WARN_MSG=" ⚠️  Complejidad alta ($COMPLEXITY puntos de decisión) — proceder con cautela."
fi

# ── Emitir contexto estructural ───────────────────────────────────────────────

cat <<CONTEXT_EOF

╔══════════════════════════════════════════════════════════════╗
║  🔍 AST Comprehension — Pre-edit context                    ║
╚══════════════════════════════════════════════════════════════╝
Fichero: $TARGET
Líneas:  $LINE_COUNT  |  Clases: $N_CLASSES  |  Funciones: $N_FUNCTIONS
Complejidad aproximada: $COMPLEXITY puntos de decisión  [extractor: $TOOL_USED]$WARN_MSG

Mapa estructural (JSON):
$(_py_extract "
import sys,json
try:
  d=json.load(sys.stdin)
  out={}
  if 'structure' in d: out['structure']=d['structure']
  elif 'classes' in d or 'functions' in d:
    out['classes']=d.get('classes',[]); out['functions']=d.get('functions',[])
  if d.get('imports'): out['imports']=d['imports']
  if 'complexity' in d: out['complexity']=d['complexity']
  elif 'complexity_approx' in d: out['complexity_approx']=d['complexity_approx']
  print(json.dumps(out,ensure_ascii=False,indent=2))
except Exception as e: print(str(e)[:200])")

────────────────────────────────────────────────────────────────
CONTEXT_EOF

exit 0
