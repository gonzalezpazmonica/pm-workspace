#!/usr/bin/env bash
# agent-index-generate.sh — Generate federated agent index from cards (SE-263 S4)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CARDS_DIR="${1:-$ROOT/coordinacion/cards}"
OUTPUT="${2:-$ROOT/coordinacion/domes/_federation/agent-index.json}"

mkdir -p "$(dirname "$OUTPUT")"

python3 << PYEOF
import json, os, glob

cards_dir = os.path.abspath('$CARDS_DIR')
output = os.path.abspath('$OUTPUT')
agents = {}

for card_path in sorted(glob.glob(os.path.join(cards_dir, '*.card.json'))):
    try:
        with open(card_path) as f:
            card = json.load(f)
    except Exception:
        continue
    iid = card.get('instanceId', '')
    if not iid or card.get('status') == 'revoked':
        continue
    skills = [s.get('id', '') for s in card.get('skills', [])]
    max_level = min((s.get('maxLevel', 2) for s in card.get('skills', [])), default=2)
    agents[iid] = {
        'card': os.path.relpath(card_path, cards_dir),
        'principal': card.get('principal', ''),
        'skills': skills,
        'max_level': max_level
    }

index = {
    'generated': 'deterministic-from-cards',
    'federation': 'savia-federation',
    'agents': agents
}

os.makedirs(os.path.dirname(output), exist_ok=True)
with open(output, 'w') as f:
    json.dump(index, f, indent=2, sort_keys=True)

print(f'Agent index: {len(agents)} agents -> {output}')
PYEOF

echo "Agent index generated: $OUTPUT"
