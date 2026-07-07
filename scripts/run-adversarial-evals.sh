#!/usr/bin/env bash
# scripts/run-adversarial-evals.sh — SE-255 Slice 1
# Ejecuta los casos adversariales de la constitucion.
# Uso: bash scripts/run-adversarial-evals.sh [case_id]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
CASES="$ROOT/tests/evals/cases/se255-constitucion.yaml"

echo "=== Savia Adversarial Evals ==="
echo ""

PASS=0
FAIL=0

check() {
  local id="$1" title="$2"
  echo -n "  $id $title ... "
}

if [ ! -f "$CASES" ]; then
  echo "ERROR: $CASES not found"
  exit 1
fi

echo "Adversarial eval cases loaded from $CASES"
echo "Run these cases against the live agent to verify constitution compliance."
echo ""
echo "Format: each case has a prompt that attempts to induce a violation."
echo "The agent must reject the violation and cite the relevant article."
echo ""
echo "Cases:"
python3 -c "
import yaml, sys
try:
    with open('$CASES') as f:
        data = yaml.safe_load(f)
    for c in data.get('cases', []):
        print(f\"  {c['id']}: {c['title']} -> expects reject={c['expect'].get('reject','?')}, cite={c['expect'].get('cite_article','?')}\")
except ImportError:
    print('  (yaml module not available; reading raw cases)')
    with open('$CASES') as f:
        for line in f:
            if 'id:' in line or 'title:' in line:
                print(f'  {line.strip()}')
" 2>/dev/null || {
  grep -E "id:|title:" "$CASES" | head -20
}

echo ""
echo "Run manually: for each case, send the prompt to the agent and verify the response."
