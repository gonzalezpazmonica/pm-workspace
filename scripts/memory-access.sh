#!/usr/bin/env bash
# memory-access.sh — SE-073 Slice 1 — increment access_count + last_access
#
# Usage:
#   bash scripts/memory-access.sh <basename>
#   bash scripts/memory-access.sh feedback_pr_natural_language.md
#
# Behavior:
#   - Reads frontmatter, increments access_count
#   - Sets last_access to today (UTC)
#   - Atomic write via tmp + mv
#   - Idempotent on missing fields (creates them with defaults)
#
# Env:
#   MEMORY_DIR (default: ~/.claude/projects/-home-monica-claude/memory)
#
# Reference: docs/propuestas/SE-073-memory-index-cap-tiered.md

set -uo pipefail

MEMORY_DIR="${MEMORY_DIR:-$HOME/.claude/projects/-home-monica-claude/memory}"

if [[ $# -lt 1 ]]; then
  echo "Usage: memory-access.sh <basename>" >&2
  exit 2
fi

BASENAME="$1"
FILE="${MEMORY_DIR}/${BASENAME}"

if [[ ! -f "${FILE}" ]]; then
  echo "ERROR: file no encontrado: ${FILE}" >&2
  exit 1
fi

TODAY=$(date -u +"%Y-%m-%d")
TMP="${FILE}.tmp.$$"

# Detect if file has frontmatter (starts with ---)
if ! head -1 "${FILE}" | grep -q '^---$'; then
  echo "ERROR: ${BASENAME} no tiene frontmatter — no rotable" >&2
  exit 1
fi

# Use python for safer YAML edit (bash regex on YAML is fragile)
python3 - "${FILE}" "${TMP}" "${TODAY}" <<'PYEOF'
import sys, re

src, dst, today = sys.argv[1], sys.argv[2], sys.argv[3]

with open(src, 'r') as f:
    content = f.read()

# Split frontmatter (between first --- and second ---)
m = re.match(r'^---\n(.*?)\n---\n(.*)$', content, re.DOTALL)
if not m:
    print(f"ERROR: malformed frontmatter in {src}", file=sys.stderr)
    sys.exit(1)

fm, body = m.group(1), m.group(2)

# Increment access_count
if re.search(r'^access_count:\s*\d+', fm, re.MULTILINE):
    fm = re.sub(r'^access_count:\s*(\d+)',
                lambda mm: f'access_count: {int(mm.group(1)) + 1}',
                fm, flags=re.MULTILINE)
else:
    fm = fm.rstrip() + f'\naccess_count: 1'

# Update last_access
if re.search(r'^last_access:', fm, re.MULTILINE):
    fm = re.sub(r'^last_access:.*$',
                f'last_access: {today}',
                fm, flags=re.MULTILINE)
else:
    fm = fm.rstrip() + f'\nlast_access: {today}'

with open(dst, 'w') as f:
    f.write(f'---\n{fm}\n---\n{body}')
PYEOF

if [[ $? -ne 0 ]]; then
  rm -f "${TMP}"
  exit 1
fi

mv "${TMP}" "${FILE}"
echo "memory-access: ${BASENAME} access_count incremented, last_access=${TODAY}"
