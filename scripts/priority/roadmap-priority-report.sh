#!/usr/bin/env bash
# SPEC-154 Slice 6 — roadmap-priority-report.sh
# Lee todos los specs en docs/propuestas/ con priority_score
# y genera tabla ordenada por priority_score descendente.
# Output markdown a stdout.
set -euo pipefail

SPECS_DIR="${SPECS_DIR:-docs/propuestas}"

get_field() {
    local file="$1" field="$2"
    python3 - "$file" "$field" << 'PYEOF'
import sys, re
path, field = sys.argv[1], sys.argv[2]
with open(path) as f:
    text = f.read()
if not text.startswith("---"):
    sys.exit(0)
end = text.find("\n---", 3)
if end == -1:
    sys.exit(0)
fm = text[3:end]
for line in fm.splitlines():
    m = re.match(r"^(\w[\w_-]*):\s*(.*)", line)
    if m and m.group(1) == field:
        print(m.group(2).strip())
        sys.exit(0)
PYEOF
}

# Collect data into TSV for sorting
tmpfile=$(mktemp)
trap "rm -f $tmpfile" EXIT

for spec in "$SPECS_DIR"/*.md; do
    [ -f "$spec" ] || continue
    name=$(basename "$spec")

    ps=$(get_field "$spec" "priority_score")
    [ -z "$ps" ] && continue

    value=$(get_field "$spec" "value")
    urgency=$(get_field "$spec" "urgency")
    effort_score=$(get_field "$spec" "effort_score")
    status=$(get_field "$spec" "status")
    title=$(get_field "$spec" "title")
    [ -z "$title" ] && title="${name%.md}"

    echo "${ps}	${name%.md}	${title}	V=${value:-?}/U=${urgency:-?}/E=${effort_score:-?}	${status:-?}" >> "$tmpfile"
done

if [ ! -s "$tmpfile" ]; then
    echo "No specs with priority_score found in $SPECS_DIR"
    exit 0
fi

# Sort descending by score (numeric)
sorted=$(sort -t$'\t' -k1 -rn "$tmpfile")

echo "# Priority Report — $(date +%Y-%m-%d)"
echo ""
echo "Specs ordenadas por priority_score descendente."
echo ""
printf "| %-10s | %-40s | %-20s | %-12s | %s |\n" "Score" "Spec" "Title" "V/U/E" "Status"
printf "|%s|%s|%s|%s|%s|\n" "$(python3 -c "print('-'*12)")" "$(python3 -c "print('-'*42)")" "$(python3 -c "print('-'*22)")" "$(python3 -c "print('-'*14)")" "$(python3 -c "print('-'*10)")"

while IFS=$'\t' read -r ps spec_id title vue status; do
    printf "| %-10s | %-40s | %-20s | %-12s | %s |\n" "$ps" "$spec_id" "${title:0:20}" "$vue" "$status"
done <<< "$sorted"

echo ""
total=$(echo "$sorted" | wc -l | tr -d ' ')
echo "_Total specs with priority_score: ${total}_"
