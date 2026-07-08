#!/bin/bash
set -uo pipefail
# restore-drill.sh — SE-258 Slice 2
# Ejecuta el drill de restauracion y registra el resultado

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_ROOT/docs/restore-drill-log.md"
START_TS=$(date +%s)

echo "=== Restore Drill — $(date +%Y-%m-%d) ==="
echo ""

echo "[1/3] Verifying ledger chain..."
if bash "$REPO_ROOT/scripts/verify-ledger-chain.sh"; then
  LEDGER_OK=1
  echo "ledger: OK"
else
  LEDGER_OK=0
  echo "ledger: BROKEN"
fi

echo ""
echo "[2/3] Verifying memory liveness..."
if bash "$REPO_ROOT/scripts/memory-liveness-check.sh" 2>/dev/null; then
  MEM_OK=1
  echo "memory: OK"
else
  MEM_OK=0
  echo "memory: NOT OK (may be expected in clean environment)"
fi

echo ""
echo "[3/3] Verifying workspace structure..."
WS_OK=1
for dir in .opencode/agents .opencode/hooks .opencode/commands scripts; do
  if [ ! -d "$REPO_ROOT/$dir" ]; then
    echo "MISSING: $dir"
    WS_OK=0
  fi
done
if [ "$WS_OK" -eq 1 ]; then
  echo "workspace structure: OK"
else
  echo "workspace structure: INCOMPLETE"
fi

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "=== Drill Result ==="
echo "Duration: ${MINUTES}m ${SECONDS}s"

if [ "$LEDGER_OK" -eq 1 ] && [ "$WS_OK" -eq 1 ]; then
  echo "Result: PASS"
  RESULT="PASS"
else
  echo "Result: FAIL"
  RESULT="FAIL"
fi

OPERATOR="${USER:-unknown}"
printf "\n| %s | %s | %sm %ss | %s | %s | SE-258 Slice 2 drill |\n" \
  "$(date +%Y-%m-%d)" "$OPERATOR" "$MINUTES" "$SECONDS" "${MINUTES}m${SECONDS}s" "$RESULT" >> "$LOG"

echo ""
echo "Drill logged to $LOG"
exit 0
