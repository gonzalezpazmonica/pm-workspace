#!/usr/bin/env bash
# skills-collision-detect.sh — SE-270 Slice 1 — Skill description collision detection
#
# Compares all skill descriptions pairwise using cosine similarity
# (via Python scikit-learn). Reports pairs with similarity >= threshold.
#
# Usage:
#   bash scripts/skills-collision-detect.sh                # report collisions
#   bash scripts/skills-collision-detect.sh --threshold 0.6 # custom threshold
#   bash scripts/skills-collision-detect.sh --json          # JSON output
#
# Exit 0 if no collisions, exit 1 if collisions found.
# Ref: SE-270

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -n "${SAVIA_SKILLS_DIR:-}" ]]; then
  SKILLS_DIR="$SAVIA_SKILLS_DIR"
else
  SKILLS_DIR="$(cd -P "$ROOT/.opencode/skills" && pwd)"
fi

SIM_THRESHOLD="${1:-0.5}"
MODE_JSON=false
COLLISION_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) shift; SIM_THRESHOLD="${1:-0.5}" ;;
    --json) MODE_JSON=true ;;
    --help|-h)
      sed -n '2,13p' "$0" | sed 's/^# //'
      exit 0 ;;
  esac
  shift
done

python3 -c "
import os, json, re, sys
from collections import Counter
from math import sqrt

SKILLS_DIR = '$SKILLS_DIR'
THRESHOLD = float('$SIM_THRESHOLD')

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
collisions = []

for i in range(len(names)):
    for j in range(i + 1, len(names)):
        sim = cosine_sim(tokenize(skills[names[i]]), tokenize(skills[names[j]]))
        if sim >= THRESHOLD:
            collisions.append({
                'skill_a': names[i],
                'skill_b': names[j],
                'similarity': round(sim, 4),
                'desc_a': skills[names[i]],
                'desc_b': skills[names[j]]
            })

if '$MODE_JSON' == 'true':
    print(json.dumps({'threshold': THRESHOLD, 'total_skills': len(skills), 'collisions': collisions}, indent=2, ensure_ascii=False))
else:
    if collisions:
        print(f'Threshold: {THRESHOLD} | Skills scanned: {len(skills)} | Collisions: {len(collisions)}')
        print()
        for c in collisions:
            print(f\"[{c['similarity']:.3f}] {c['skill_a']} <-> {c['skill_b']}\")
            print(f\"  A: {c['desc_a'][:80]}...\")
            print(f\"  B: {c['desc_b'][:80]}...\")
            print()
    else:
        print(f'No collisions found (threshold={THRESHOLD}, skills={len(skills)})')

sys.exit(0 if not collisions else 1)
" 2>/dev/null
