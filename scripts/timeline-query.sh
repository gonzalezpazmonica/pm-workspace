#!/usr/bin/env bash
# timeline-query.sh — Query historical value of a field from bi-temporal timeline
# Usage: timeline-query.sh <file> --at <YYYY-MM-DD>
# Exit 0 with value printed to stdout, exit 1 if no timeline or date out of range.
# Ref: SPEC-182 bi-temporal timeline frontmatter
set -uo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <file> --at <YYYY-MM-DD>

  file    Path to spec or decision markdown file
  --at    Query date in ISO-8601 format (YYYY-MM-DD)

Returns the tracked field value that was current at the given date.
Exit 0 on success, exit 1 if no timeline exists or date is out of range.
EOF
  exit 0
}

FILE=""
QUERY_DATE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --at)
      shift
      QUERY_DATE="${1:-}"
      ;;
    --help|-h) usage ;;
    *) FILE="$1" ;;
  esac
  shift
done

if [[ -z "$FILE" ]]; then
  echo "ERROR: file argument required" >&2
  exit 1
fi
if [[ -z "$QUERY_DATE" ]]; then
  echo "ERROR: --at <date> required" >&2
  exit 1
fi
if [[ ! -f "$FILE" ]]; then
  echo "ERROR: file not found: $FILE" >&2
  exit 1
fi

# Validate date format
if ! echo "$QUERY_DATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  echo "ERROR: date must be YYYY-MM-DD format, got: $QUERY_DATE" >&2
  exit 1
fi

# Query via Python3 — parse YAML timeline from frontmatter
python3 /dev/stdin "$FILE" "$QUERY_DATE" << 'PYEOF'
import sys, re

file_path = sys.argv[1]
query_date = sys.argv[2]

with open(file_path, 'r') as f:
    content = f.read()

# Extract frontmatter block
fm_match = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
if not fm_match:
    print("ERROR: no frontmatter found", file=sys.stderr)
    sys.exit(1)

fm_text = fm_match.group(1)

# Find timeline: block in frontmatter
if not re.search(r'^timeline\s*:', fm_text, re.MULTILINE):
    print("ERROR: no timeline key in frontmatter", file=sys.stderr)
    sys.exit(1)

# Parse timeline entries: each starts with '  - from:'
entries = []
entry_pattern = re.compile(
    r'  - from:\s*"?(\d{4}-\d{2}-\d{2})"?.*?'
    r'(?:until:\s*"?(\d{4}-\d{2}-\d{2})"?.*?)?'
    r'value:\s*"?([^"\n]+)"?',
    re.DOTALL
)

# Split timeline block into individual entries
timeline_match = re.search(r'^timeline\s*:\s*\n((?:  [-\s][^\n]*\n?)*)', fm_text, re.MULTILINE)
if not timeline_match:
    print("ERROR: could not parse timeline block", file=sys.stderr)
    sys.exit(1)

timeline_block = timeline_match.group(1)
# Parse each entry
current_entry = {}
for line in timeline_block.split('\n'):
    from_m = re.match(r'\s+- from:\s*"?(\d{4}-\d{2}-\d{2})"?', line)
    until_m = re.match(r'\s+until:\s*"?(\d{4}-\d{2}-\d{2})"?', line)
    value_m = re.match(r'\s+value:\s*"?([^"\n]+)"?', line)
    if from_m:
        if current_entry:
            entries.append(current_entry)
        current_entry = {'from': from_m.group(1)}
    elif until_m and current_entry:
        current_entry['until'] = until_m.group(1)
    elif value_m and current_entry:
        current_entry['value'] = value_m.group(1).strip()
if current_entry:
    entries.append(current_entry)

if not entries:
    print("ERROR: timeline has no entries", file=sys.stderr)
    sys.exit(1)

# Find the entry valid at query_date
for entry in entries:
    from_d = entry.get('from', '')
    until_d = entry.get('until', '9999-99-99')  # open-ended
    val = entry.get('value', '')
    if from_d <= query_date <= until_d:
        print(val)
        sys.exit(0)

# Date is out of range
earliest = entries[0].get('from', '')
latest = entries[-1].get('from', '')
print(f"ERROR: date {query_date} out of range (earliest={earliest}, latest={latest})", file=sys.stderr)
sys.exit(1)
PYEOF
