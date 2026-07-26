#!/usr/bin/env bash
# skills-depth-lint.sh — SE-270 Slice 2 — Single-level depth enforcement
#
# Checks that no SKILL.md references another file (single-level enforcement).
# Skills must be self-contained; file references should use the Authoritative
# Paths table format, not embedded file paths in prose.
#
# Usage:
#   bash scripts/skills-depth-lint.sh               # check all skills
#   bash scripts/skills-depth-lint.sh --skill NAME   # single skill
#   bash scripts/skills-depth-lint.sh --json         # JSON output
#
# Exit 0 if no violations, exit 1 if any skill has file references.
# Ref: SE-270

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -n "${SAVIA_SKILLS_DIR:-}" ]]; then
  SKILLS_DIR="$SAVIA_SKILLS_DIR"
else
  SKILLS_DIR="$(cd -P "$ROOT/.opencode/skills" && pwd)"
fi

MODE_JSON=false
FILTER_SKILL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)  MODE_JSON=true ;;
    --skill) shift; FILTER_SKILL="${1:-}" ;;
    --help|-h)
      sed -n '2,14p' "$0" | sed 's/^# //'
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

# ── Parse all skills via python3 ───────────────────────────────────────────────
lint_depth() {
  local skill_filter="${1:-}"
  python3 -c "
import os, json, re, sys

SKILLS_DIR = '$SKILLS_DIR'
FILTER = '$skill_filter'

FILE_REF_RE = re.compile(r'(?:^|\s)(\.\.?/[a-zA-Z0-9_./-]+|\.\.?\\\\[a-zA-Z0-9_./-]+)')

results = []
total = 0
violations_count = 0

for d in sorted(os.listdir(SKILLS_DIR)):
    if d == '_template':
        continue
    if FILTER and d != FILTER:
        continue
    md = os.path.join(SKILLS_DIR, d, 'SKILL.md')
    if not os.path.isfile(md):
        continue
    total += 1
    with open(md) as f:
        content = f.read()
    parts = content.split('---', 2)
    body = parts[2] if len(parts) >= 3 else ''
    lines = body.split('\n')
    vlist = []
    in_table = False
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith('|') and '|' in stripped[1:]:
            in_table = True
            continue
        if in_table:
            if stripped.startswith('|') and '|' in stripped[1:]:
                continue
            else:
                in_table = False
        if FILE_REF_RE.search(line):
            vlist.append(f'line {i}: {stripped[:80]}')
    if vlist:
        violations_count += 1
    results.append({'skill': d, 'violations': vlist})

print(json.dumps({'total': total, 'violations_count': violations_count, 'skills': results}, ensure_ascii=False))
" 2>/dev/null
}

# ── Run ────────────────────────────────────────────────────────────────────────
depth_results="$(lint_depth "$FILTER_SKILL")"
if [[ -z "$depth_results" ]]; then
  echo "ERROR: failed to parse skills" >&2
  exit 1
fi

if $MODE_JSON; then
  echo "$depth_results"
else
  total=$(echo "$depth_results" | python3 -c "import json,sys; print(json.load(sys.stdin)['total'])")
  viol=$(echo "$depth_results" | python3 -c "import json,sys; print(json.load(sys.stdin)['violations_count'])")
  printf "%-42s  %-6s  %s\n" "SKILL" "STATUS" "REFERENCES"
  printf '%0.s-' {1..80}
  echo
  echo "$depth_results" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for s in data['skills']:
    v = s['violations']
    if v:
        print(f'{s[\"skill\"]:<42}  FAIL    {len(v)} file references')
        for vl in v[:5]:
            print(f'         {vl}')
        if len(v) > 5:
            print(f'         ... and {len(v)-5} more')
    else:
        print(f'{s[\"skill\"]:<42}  OK      -')
" 2>&1
  printf '%0.s-' {1..80}
  echo
  echo "Skills with file references: $viol / $total"
fi

echo "$depth_results" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d['violations_count']==0 else 1)" 2>/dev/null
