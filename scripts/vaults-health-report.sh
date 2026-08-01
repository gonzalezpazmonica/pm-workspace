#!/usr/bin/env bash
# vaults-health-report.sh — Quality and health report for a vault
# Usage: bash scripts/vaults-health-report.sh [--vault <name>] [--json]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT/config/vaults.yaml"
SAVIA_VAULTS_DIR="$ROOT/projects/savia-vaults"
VAULT_NAME="${1:-savialabs}"
JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_NAME="$2"; shift 2 ;;
    --json) JSON=true; shift ;;
    *) shift ;;
  esac
done

VAULT_PATH=$(grep -A5 "^  ${VAULT_NAME}:" "$CONFIG_FILE" 2>/dev/null | grep "path:" | head -1 | sed 's/.*path: *//;s/"//g' | xargs)
[[ -n "$VAULT_PATH" ]] && VAULT_PATH="$ROOT/$VAULT_PATH"

if [[ -z "$VAULT_PATH" ]]; then
  echo "ERROR: Unknown vault: $VAULT_NAME"
  exit 1
fi

echo "=== SaviaVaults Health Report ==="
echo "Vault: $VAULT_NAME ($VAULT_PATH)"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Stats
echo "## Storage"
DOC_COUNT=$(find "$VAULT_PATH" -name '*.md' -not -path '*/.git/*' 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sb "$VAULT_PATH" 2>/dev/null | cut -f1 || echo "0")
echo "- Documents: $DOC_COUNT"
echo "- Size: $(( TOTAL_SIZE / 1024 )) KB"

# Git info
if [[ -d "$VAULT_PATH/.git" ]]; then
  echo ""
  echo "## Version Control"
  LAST_COMMIT=$(cd "$VAULT_PATH" && git log -1 --format="%h %s (%ar)" 2>/dev/null || echo "unknown")
  COMMIT_COUNT=$(cd "$VAULT_PATH" && git rev-list --count HEAD 2>/dev/null || echo "0")
  echo "- Last commit: $LAST_COMMIT"
  echo "- Total commits: $COMMIT_COUNT"
fi

# Freshness
echo ""
echo "## Freshness"
LAST_TS=$(cd "$VAULT_PATH" && git log -1 --format=%ct 2>/dev/null || echo "0")
NOW=$(date +%s)
AGE_H=$(( (NOW - LAST_TS) / 3600 ))
if [[ $AGE_H -gt 168 ]]; then
  echo "- Status: STALE (last update ${AGE_H}h ago)"
elif [[ $AGE_H -gt 24 ]]; then
  echo "- Status: AGING (last update ${AGE_H}h ago)"
else
  echo "- Status: FRESH"
fi

# Coverage estimate
echo ""
echo "## Typing Coverage"
TYPED=$(grep -rl "entity:" "$VAULT_PATH" --include="*.md" 2>/dev/null | wc -l)
UNTYPED=$(( DOC_COUNT - TYPED ))
echo "- Typed entities: $TYPED"
echo "- Untyped documents: $UNTYPED"
[[ $DOC_COUNT -gt 0 ]] && echo "- Coverage: $(( TYPED * 100 / DOC_COUNT ))%"

echo ""
echo "## Quality Indicators"
echo "- Conflicts: run 'savia-vaults health --path $VAULT_PATH' for detailed analysis"
echo "- Orphan entities: see vault_graph stats"
echo "- Expired assertions: use vault_query with temporal filters"

if $JSON; then
  echo ""
  echo "JSON output not yet implemented for health report"
fi
