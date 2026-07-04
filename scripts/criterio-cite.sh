#!/usr/bin/env bash
# scripts/criterio-cite.sh — SE-255 Slice 5
# Resuelve una cita de criterio (CRIT-XXX) y devuelve su texto.
# Uso: bash scripts/criterio-cite.sh CRIT-007
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
CRITERIO="$ROOT/CRITERIO.md"
ID="${1:-}"

if [[ -z "$ID" ]]; then
  echo "Usage: $0 CRIT-XXX" >&2
  exit 2
fi

if [[ ! -f "$CRITERIO" ]]; then
  echo "ERROR: CRITERIO.md not found" >&2
  exit 1
fi

python3 -c "
import re, sys
with open('$CRITERIO') as f:
    text = f.read()

pattern = rf'^($ID):\s*(.+?)$'
lines = text.split('\n')
found = False
for i, line in enumerate(lines):
    m = re.match(pattern, line)
    if m:
        print(f'{m.group(1)}: {m.group(2)}')
        found = True
        for j in range(i+1, min(i+8, len(lines))):
            if lines[j].startswith('CRIT-') or lines[j].startswith('##') or lines[j].startswith('---'):
                break
            if lines[j].strip():
                print(lines[j])
        break
if not found:
    print(f'ERROR: {ID} not found in CRITERIO.md', file=sys.stderr)
    sys.exit(1)
"
