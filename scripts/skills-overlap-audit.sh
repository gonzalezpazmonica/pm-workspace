#!/usr/bin/env bash
# skills-overlap-audit.sh — SE-270 Slice 3 — Skill description similarity matrix
#
# Generates a similarity matrix between all skill descriptions using
# cosine similarity via Python. Outputs formatted table and JSON.
#
# Usage:
#   bash scripts/skills-overlap-audit.sh               # table output
#   bash scripts/skills-overlap-audit.sh --json         # JSON matrix
#   bash scripts/skills-overlap-audit.sh --threshold 0.4 # filter
#   bash scripts/skills-overlap-audit.sh --top 10        # top N pairs
#
# Exit 0 on success.
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
THRESHOLD="0.0"
TOP_N=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)       MODE_JSON=true ;;
    --threshold)  shift; THRESHOLD="${1:-0.0}" ;;
    --top)        shift; TOP_N="${1:-}" ;;
    --help|-h)
      sed -n '2,15p' "$0" | sed 's/^# //'
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

python3 -c "
import os, json, re, sys
from collections import Counter
from math import sqrt

SKILLS_DIR = '$SKILLS_DIR'
THRESHOLD = float('$THRESHOLD')
TOP_N = '$TOP_N'
MODE_JSON = '$MODE_JSON'

def extract_description(md_path):
    try:
        with open(md_path) as f:
            content = f.read()
    except Exception:
        return None
    parts = content.split('---', 2)
    if len(parts) < 3:
        return None
    fm = parts[1]
    for line in fm.split('\n'):
        if line.startswith('description:'):
            desc = line.split(':', 1)[1].strip()
            desc = desc.strip('\"').strip(\"'\")
            return desc
    return None

def tokenize(text):
    text = text.lower()
    text = re.sub(r'[^a-záéíóúñü0-9 ]', ' ', text)
    tokens = [t for t in text.split() if len(t) > 1]
    return Counter(tokens)

def cosine_sim(c1, c2):
    if not c1 or not c2:
        return 0.0
    words = set(c1.keys()) | set(c2.keys())
    dot = sum(c1.get(w, 0) * c2.get(w, 0) for w in words)
    mag1 = sqrt(sum(v**2 for v in c1.values()))
    mag2 = sqrt(sum(v**2 for v in c2.values()))
    if mag1 == 0 or mag2 == 0:
        return 0.0
    return dot / (mag1 * mag2)

skills = {}
for d in sorted(os.listdir(SKILLS_DIR)):
    if d == '_template':
        continue
    md = os.path.join(SKILLS_DIR, d, 'SKILL.md')
    if os.path.isfile(md):
        desc = extract_description(md)
        if desc:
            skills[d] = desc

names = sorted(skills.keys())
n = len(names)

pairs = []
for i in range(n):
    for j in range(i + 1, n):
        sim = cosine_sim(tokenize(skills[names[i]]), tokenize(skills[names[j]]))
        if sim >= THRESHOLD:
            pairs.append((sim, names[i], names[j]))

pairs.sort(key=lambda x: x[0], reverse=True)

if TOP_N:
    pairs = pairs[:int(TOP_N)]

if MODE_JSON == 'true':
    result = {
        'total_skills': n,
        'total_pairs': len(pairs),
        'threshold': THRESHOLD,
        'matrix': [{'similarity': round(s, 4), 'skill_a': a, 'skill_b': b} for s, a, b in pairs]
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))
else:
    print(f'Skills: {n} | Pairs above {THRESHOLD}: {len(pairs)}')
    print()
    if not pairs:
        print('No overlaps found.')
    else:
        print(f'{\"SIM\":>7}  {\"SKILL A\":<40}  {\"SKILL B\":<40}')
        print('-' * 90)
        for sim, a, b in pairs:
            print(f'{sim:7.3f}  {a:<40}  {b:<40}')
        print()
        if pairs:
            top = pairs[0]
            print(f'Highest overlap: {top[1]} <-> {top[2]} ({top[0]:.3f})')

sys.exit(0)
" 2>/dev/null
