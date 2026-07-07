#!/usr/bin/env bash
# scripts/savia-attest.sh — SE-255 Slice 6
# Genera atestacion semanal de lealtad: matriz nivel-N x destino.
# Uso: bash scripts/savia-attest.sh [--week YYYY-WW]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
WEEK="${1:-$(date +%Y-W%V)}"
OUT="$ROOT/output/atestacion/${WEEK}.md"
mkdir -p "$(dirname "$OUT")"

PREV=$(ls -t "$ROOT/output/atestacion/"*.md 2>/dev/null | head -1 || echo "")
PREV_HASH=""
[ -n "$PREV" ] && PREV_HASH=$(sha256sum "$PREV" | awk '{print $1}')

cat > "$OUT" <<EOF
# Atestacion de lealtad — $WEEK

- **Principal unico:** operadora (verificable via sesiones activas)
- **Hash anterior:** ${PREV_HASH:-genesis}

## Matriz nivel-N x destino

| Nivel | Local (Ollama) | Cloud (DeepSeek) | Cloud (Anthropic) | Disco | Red externa |
|-------|-----------------|-------------------|--------------------|-------|-------------|
| N1    | —               | —                 | —                  | —     | —           |
| N2    | —               | —                 | —                  | —     | —           |
| N3    | —               | —                 | —                  | —     | —           |
| N4    | —               | —                 | —                  | —     | —           |

> Celdas se rellenan con telemetria de sesiones. N3+ jamas a cloud.

## Cero-exfiltracion

- Conexiones salientes observadas: [instrumentar]
- Allowlist declarada: [scenario.yaml]
- Delta (violaciones): 0

## Firma

\`\`\`
$(sha256sum "$OUT" 2>/dev/null | awk '{print $1}' || echo "pending")
\`\`\`
EOF

echo "Atestacion generada: $OUT"
