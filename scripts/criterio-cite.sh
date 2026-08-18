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

python3 - "$CRITERIO" "$ID" <<'PY'
import re
import sys

criterio_path, criterion_id = sys.argv[1:]
with open(criterio_path, encoding='utf-8') as handle:
    lines = handle.read().splitlines()

pattern = re.compile(rf'^({re.escape(criterion_id)})\s*[—:-]\s*(.+?)$')
for index, line in enumerate(lines):
    match = pattern.match(line)
    if not match:
        continue
    print(f'{match.group(1)}: {match.group(2)}')
    for detail in lines[index + 1:index + 8]:
        if detail.startswith(('CRIT-', '##', '---')):
            break
        if detail.strip():
            print(detail)
    raise SystemExit(0)

print(f'ERROR: {criterion_id} not found in CRITERIO.md', file=sys.stderr)
raise SystemExit(1)
PY
