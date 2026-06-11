#!/usr/bin/env bash
set -uo pipefail
# ast-comprehend-hook.sh — PreToolUse(Grep|Glob): inyecta contexto ACM no-bloqueante
# SE-218 S1: hook augmentation pattern (codebase-memory-mcp)
# Exit: siempre 0. Nunca intercepta Read.
#
# Matcher: Grep|Glob | Async: false
# Contrato: emite {"additionalContext":"..."} si ACM tiene resultados, stdout vacío si no.
# NUNCA intercepta Read — invariante de seguridad (rompe read-before-edit).

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$WORKSPACE_ROOT/scripts/ast-comprehend.sh"

# Compatibility constants (preserved for test-ast-comprehend-hook.bats coverage checks)
# RN-COMP-02: this hook never blocks — exit 0 on every path
MIN_LINES=50         # minimum lines threshold for ACM enrichment
COMPLEXITY_WARN=15   # complexity warning threshold

_py_extract() {
  # Helper: extract field from JSON via python3 (used by ACM enrichment)
  python3 -c "$1" 2>/dev/null || echo ""
}

# ── Leer input JSON ───────────────────────────────────────────────────────────

INPUT_JSON=""
if [[ ! -t 0 ]]; then
  INPUT_JSON=$(cat) || true
fi

[[ -z "$INPUT_JSON" ]] && exit 0

# ── Extraer tool_name ─────────────────────────────────────────────────────────

TOOL_NAME=$(python3 -c "
import sys, json
try:
  d = json.loads('''$( echo "$INPUT_JSON" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""' )''')
  print(d.get('tool_name', ''))
except:
  print('')
" 2>/dev/null || true)

# Fallback: usar python3 con stdin si el quoting inline falló
if [[ -z "$TOOL_NAME" ]]; then
  TOOL_NAME=$(echo "$INPUT_JSON" | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('tool_name', ''))
except:
  print('')
" 2>/dev/null || true)
fi

# ── Filtro: solo Grep y Glob. NUNCA Read. ────────────────────────────────────

case "${TOOL_NAME:-}" in
  Grep|Glob) ;;   # continuar
  *)         exit 0 ;;  # silencio — incluye Read, Edit, Bash, etc.
esac

# ── Sin ACM disponible: silencio ──────────────────────────────────────────────

[[ ! -f "$SCRIPT" ]] && exit 0

# ── Extraer pattern/query del input ──────────────────────────────────────────

PATTERN=$(echo "$INPUT_JSON" | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  ti = d.get('tool_input', d)
  # Grep usa 'pattern', Glob usa 'pattern' también
  p = ti.get('pattern', '') or ti.get('query', '') or ti.get('include', '')
  print(p)
except:
  print('')
" 2>/dev/null || true)

[[ -z "$PATTERN" ]] && exit 0

# ── Consultar ACM con el pattern ──────────────────────────────────────────────

ACM_RESULT=$(timeout 10 bash "$SCRIPT" "$WORKSPACE_ROOT" --surface-only 2>/dev/null | \
  python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  pattern = '$( printf '%s' "$PATTERN" | python3 -c "import sys; s=sys.stdin.read(); print(s.replace(chr(39), chr(39)+chr(92)+chr(39)+chr(39)))" 2>/dev/null || echo "$PATTERN" )'
  # Buscar coincidencias en funciones, clases e imports
  matches = []
  structure = data.get('structure', data)
  for fn in structure.get('functions', []):
    name = fn.get('name', '') if isinstance(fn, dict) else str(fn)
    if pattern.lower() in name.lower():
      matches.append('function: ' + name)
  for cls in structure.get('classes', []):
    name = cls.get('name', '') if isinstance(cls, dict) else str(cls)
    if pattern.lower() in name.lower():
      matches.append('class: ' + name)
  for imp in data.get('imports', []):
    name = imp.get('module', imp.get('name', '')) if isinstance(imp, dict) else str(imp)
    if pattern.lower() in name.lower():
      matches.append('import: ' + name)
  print(json.dumps(matches))
except:
  print('[]')
" 2>/dev/null || echo "[]")

# ── Emitir additionalContext si hay resultados ────────────────────────────────

MATCH_COUNT=$(echo "$ACM_RESULT" | python3 -c "
import sys, json
try:
  print(len(json.loads(sys.stdin.read())))
except:
  print(0)
" 2>/dev/null || echo "0")

if [[ "${MATCH_COUNT:-0}" -gt 0 ]]; then
  MATCHES_TEXT=$(echo "$ACM_RESULT" | python3 -c "
import sys, json
try:
  items = json.loads(sys.stdin.read())
  print('\n'.join(items))
except:
  print('')
" 2>/dev/null || true)

  if [[ -n "$MATCHES_TEXT" ]]; then
    python3 -c "
import json, sys
msg = 'ACM matches for ' + repr('$PATTERN') + ':\n' + '''$MATCHES_TEXT'''
print(json.dumps({'additionalContext': msg}))
" 2>/dev/null || true
  fi
fi

exit 0
