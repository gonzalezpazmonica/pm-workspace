#!/bin/bash
# ast-comprehend-hook.sh — PreToolUse: inyecta mapa estructural antes de editar
# Matcher: Edit
# Async: false (debe completarse antes de que el agente edite)
# No bloquea nunca (RN-COMP-02): exit 0 siempre

set -uo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$WORKSPACE_ROOT/scripts/ast-comprehend.sh"
MIN_LINES=50
COMPLEXITY_WARN=15

# ── Leer target del input del tool (PreToolUse pasa JSON por stdin) ───────────

INPUT_JSON=""
if [[ ! -t 0 ]]; then
  INPUT_JSON=$(cat)
fi

# Extraer file_path del JSON de la herramienta Edit
TARGET=""
if [[ -n "$INPUT_JSON" ]]; then
  TARGET=$(echo "$INPUT_JSON" | python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  # Claude Code PreToolUse: tool_input.file_path
  fp = data.get('tool_input', {}).get('file_path', '')
  if not fp:
    fp = data.get('file_path', '')
  print(fp)
except:
  print('')
" 2>/dev/null || true)
fi

# Fallback: leer de variable de entorno si no hay stdin JSON
if [[ -z "$TARGET" ]]; then
  TARGET="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
fi

# Si no hay target o no existe el fichero → salir silenciosamente
if [[ -z "$TARGET" || ! -f "$TARGET" ]]; then
  exit 0
fi

# ── Verificar mínimo de líneas (RN-COMP-01) ───────────────────────────────────

LINE_COUNT=$(wc -l < "$TARGET" 2>/dev/null || echo "0")
if [[ "$LINE_COUNT" -lt "$MIN_LINES" ]]; then
  # Fichero pequeño: no es necesario el mapa estructural
  exit 0
fi

# ── Verificar que el script de comprensión existe ─────────────────────────────

if [[ ! -f "$SCRIPT" ]]; then
  # Script no disponible: continuar sin mapa (RN-COMP-05)
  exit 0
fi

# ── Ejecutar extracción superficial (rápida, < 2s) ───────────────────────────

COMPREHENSION_OUTPUT=""
COMPREHENSION_OUTPUT=$(timeout 15 bash "$SCRIPT" "$TARGET" --surface-only 2>/dev/null || true)

if [[ -z "$COMPREHENSION_OUTPUT" ]]; then
  exit 0
fi

# ── Extraer métricas clave para el banner ─────────────────────────────────────

N_CLASSES=$(echo "$COMPREHENSION_OUTPUT" | python3 -c "
import sys, json
try:
  d = json.loads(sys.stdin.read())
  print(len(d.get('structure', d).get('classes', [])))
except:
  print('?')
" 2>/dev/null || echo "?")

N_FUNCTIONS=$(echo "$COMPREHENSION_OUTPUT" | python3 -c "
import sys, json
try:
  d = json.loads(sys.stdin.read())
  print(len(d.get('structure', d).get('functions', [])))
except:
  print('?')
" 2>/dev/null || echo "?")

COMPLEXITY=$(echo "$COMPREHENSION_OUTPUT" | python3 -c "
import sys, json
try:
  d = json.loads(sys.stdin.read())
  c = d.get('complexity', {})
  print(c.get('total_decision_points', d.get('complexity_approx', '?')))
except:
  print('?')
" 2>/dev/null || echo "?")

TOOL_USED=$(echo "$COMPREHENSION_OUTPUT" | python3 -c "
import sys, json
try:
  d = json.loads(sys.stdin.read())
  print(d.get('meta', {}).get('tool', 'grep-structural'))
except:
  print('grep-structural')
" 2>/dev/null || echo "grep-structural")

FILENAME=$(basename "$TARGET")

# ── Complejidad: advertencia si supera umbral ─────────────────────────────────

WARN_MSG=""
if [[ "$COMPLEXITY" =~ ^[0-9]+$ && "$COMPLEXITY" -gt "$COMPLEXITY_WARN" ]]; then
  WARN_MSG=" ⚠️  Complejidad alta ($COMPLEXITY puntos de decisión) — proceder con cautela."
fi

# ── Emitir contexto estructural para el agente ───────────────────────────────

cat <<CONTEXT_EOF

╔══════════════════════════════════════════════════════════════╗
║  🔍 AST Comprehension — Pre-edit context                    ║
╚══════════════════════════════════════════════════════════════╝
Fichero: $TARGET
Líneas:  $LINE_COUNT  |  Clases: $N_CLASSES  |  Funciones: $N_FUNCTIONS
Complejidad aproximada: $COMPLEXITY puntos de decisión  [extractor: $TOOL_USED]$WARN_MSG

Mapa estructural (JSON):
$(echo "$COMPREHENSION_OUTPUT" | python3 -c "
import sys, json
try:
  d = json.loads(sys.stdin.read())
  # Mostrar solo la parte estructural, no el JSON completo
  out = {}
  if 'structure' in d:
    out['structure'] = d['structure']
  elif 'classes' in d or 'functions' in d:
    out['classes'] = d.get('classes', [])
    out['functions'] = d.get('functions', [])
  if 'imports' in d and d['imports']:
    out['imports'] = d['imports']
  if 'complexity' in d:
    out['complexity'] = d['complexity']
  elif 'complexity_approx' in d:
    out['complexity_approx'] = d['complexity_approx']
  print(json.dumps(out, ensure_ascii=False, indent=2))
except Exception as e:
  print(sys.stdin.read()[:500])
" 2>/dev/null || echo "$COMPREHENSION_OUTPUT" | head -40)

────────────────────────────────────────────────────────────────
CONTEXT_EOF

# Siempre exit 0: la comprensión es advisory, nunca bloquea (RN-COMP-02)
exit 0
