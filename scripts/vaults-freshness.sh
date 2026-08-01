#!/usr/bin/env bash
# vaults-freshness.sh — Check if a vault's context dome is fresh
# Usage: bash scripts/vaults-freshness.sh [--path <dir>]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_PATH="${1:-$ROOT/vaults/SaviaLabs}"

echo "=== Vault Freshness ==="
echo "Vault: $VAULT_PATH"

# Check last commit date
if [[ -d "$VAULT_PATH/.git" ]]; then
  LAST_COMMIT=$(cd "$VAULT_PATH" && git log -1 --format=%ct 2>/dev/null || echo "0")
  NOW=$(date +%s)
  AGE_HOURS=$(( (NOW - LAST_COMMIT) / 3600 ))
  echo "Last commit: $AGE_HOURS hours ago"
  
  if [[ $AGE_HOURS -gt 168 ]]; then
    echo "Status: STALE (>1 week since last update)"
  elif [[ $AGE_HOURS -gt 24 ]]; then
    echo "Status: AGING (>1 day since last update)"
  else
    echo "Status: FRESH"
  fi
else
  echo "Status: NO_GIT (not versioned)"
fi

# Check against workspace
WORKSPACE_CHANGES=$(cd "$ROOT" && git log -1 --format=%ct 2>/dev/null || echo "0")
if [[ "$WORKSPACE_CHANGES" -gt "$LAST_COMMIT" ]]; then
  echo "Warning: workspace has changed since last vault update"
  echo "Run: savia-vaults index --path $VAULT_PATH"
fi
