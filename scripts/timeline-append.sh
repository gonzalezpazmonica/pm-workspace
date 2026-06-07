#!/usr/bin/env bash
# timeline-append.sh — Append a bi-temporal timeline entry to a spec/decision file
# Usage: timeline-append.sh <field> <file> <new_value> <source> [--dry-run]
# Ref: SPEC-182 bi-temporal timeline frontmatter
set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
TODAY="$(date -u +%Y-%m-%d)"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <field> <file> <new_value> <source> [--dry-run]

  field      Field to track (e.g. status)
  file       Path to the spec or decision markdown file
  new_value  New value to record (e.g. APPROVED)
  source     Explanation or reference (e.g. 'merge commit abc123')
  --dry-run  Print what would change without modifying the file
EOF
  exit 0
}

DRY_RUN=false
POSITIONAL=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --help|-h) usage ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done

if [[ ${#POSITIONAL[@]} -lt 4 ]]; then
  echo "ERROR: requires 4 positional arguments: field file new_value source" >&2
  echo "Run '$SCRIPT_NAME --help' for usage." >&2
  exit 1
fi

FIELD="${POSITIONAL[0]}"
FILE="${POSITIONAL[1]}"
NEW_VALUE="${POSITIONAL[2]}"
SOURCE="${POSITIONAL[3]}"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: file not found: $FILE" >&2
  exit 1
fi

# Extract current value of the field from frontmatter
CURRENT=$(awk '/^---$/{c++; if(c==2)exit} c==1 && /^'"$FIELD"':/{gsub(/^[^:]+: */,"",$0); print; exit}' "$FILE")

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[dry-run] Would update $FILE:"
  echo "  $FIELD: ${CURRENT:-<unset>} -> $NEW_VALUE"
  echo "  Add timeline entry:"
  echo "    - from: \"$TODAY\""
  echo "      learned: \"$TODAY\""
  echo "      value: \"$NEW_VALUE\""
  echo "      source: \"$SOURCE\""
  exit 0
fi

# Perform atomic update via Python3
TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

python3 /dev/stdin "$FILE" "$FIELD" "$NEW_VALUE" "$SOURCE" "$TODAY" > "$TMPFILE" << 'PYEOF'
import sys, re

file_path, field, new_val, source, today = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

with open(file_path, 'r') as f:
    lines = f.read().split('\n')

# Locate frontmatter close
fm_open = False
fm_close_idx = -1
field_idx = -1
for i, line in enumerate(lines):
    if line.strip() == '---':
        if not fm_open:
            fm_open = True
        else:
            fm_close_idx = i
            break
    if fm_open and re.match(r'^' + re.escape(field) + r'\s*:', line):
        field_idx = i

if fm_close_idx < 0:
    print('\n'.join(lines), end='')
    sys.exit(0)

# Update top-level field
if field_idx >= 0:
    lines[field_idx] = f'{field}: {new_val}'

# Find existing timeline block
timeline_key_idx = -1
for i, line in enumerate(lines[:fm_close_idx]):
    if re.match(r'^timeline\s*:', line):
        timeline_key_idx = i
        break

if timeline_key_idx >= 0:
    # Close last entry with until=today if missing
    last_from_idx = -1
    for i in range(fm_close_idx - 1, timeline_key_idx, -1):
        if re.match(r'^  - from:', lines[i]):
            last_from_idx = i
            break
    if last_from_idx >= 0:
        entry_end = last_from_idx + 1
        while entry_end < fm_close_idx:
            stripped = lines[entry_end].strip()
            if stripped.startswith('- ') and not lines[entry_end].startswith('   '):
                break
            entry_end += 1
        last_block = lines[last_from_idx:entry_end]
        has_until = any(re.match(r'\s+until:', l) for l in last_block)
        if not has_until:
            lines.insert(last_from_idx + 1, f'    until: "{today}"')
            fm_close_idx += 1
    # Append new entry
    new_lines = [f'  - from: "{today}"', f'    learned: "{today}"', f'    value: "{new_val}"', f'    source: "{source}"']
    for j, el in enumerate(new_lines):
        lines.insert(fm_close_idx + j, el)
else:
    # Insert new timeline block before closing ---
    new_block = ['timeline:', f'  - from: "{today}"', f'    learned: "{today}"', f'    value: "{new_val}"', f'    source: "{source}"']
    for j, bl in enumerate(new_block):
        lines.insert(fm_close_idx + j, bl)

print('\n'.join(lines), end='')
PYEOF

mv "$TMPFILE" "$FILE"
echo "Updated $FILE: $FIELD=$NEW_VALUE (timeline entry added)"
