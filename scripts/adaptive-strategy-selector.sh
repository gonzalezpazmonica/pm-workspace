#!/usr/bin/env bash
# adaptive-strategy-selector.sh — Select loading strategy based on model tier
# Outputs JSON with strategy parameters for the given tier.
# Usage: ./scripts/adaptive-strategy-selector.sh <max|high|fast>
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

# Read stdin for hook compatibility
cat /dev/stdin > /dev/null 2>&1 || true

if [[ $# -eq 0 && -z "${SAVIA_MODEL_TIER:-}" ]]; then
  echo "ERROR: tier argument required. Usage: $0 <max|high|fast>" >&2
  exit 1
fi
TIER="${1:-${SAVIA_MODEL_TIER:-fast}}"

case "$TIER" in
  max)
    cat <<'EOF'
{"tier":"max","lazy_loading":"relaxed","agent_budget":5000,"autocompact_pct":70,"load_dormant_rules":5,"load_full_sprint":true}
EOF
    ;;
  high)
    cat <<'EOF'
{"tier":"high","lazy_loading":"moderate","agent_budget":3000,"autocompact_pct":65,"load_dormant_rules":0,"load_full_sprint":false}
EOF
    ;;
  fast)
    cat <<'EOF'
{"tier":"fast","lazy_loading":"aggressive","agent_budget":1000,"autocompact_pct":45,"load_dormant_rules":0,"load_full_sprint":false}
EOF
    ;;
  *)
    echo "ERROR: Unknown tier '${TIER}'. Valid: max, high, fast" >&2
    exit 1
    ;;
esac
