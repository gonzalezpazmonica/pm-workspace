#!/usr/bin/env bash
# labs-self-audit.sh — Comprobaciones de disciplina en Savia Labs
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABS="$ROOT/labs"
echo "=== Savia Labs — Self-Audit ==="

# Check: hypotheses without preregistration
echo "1. Hypotheses without preregistration:"
find "$LABS/hypotheses" -name "*.md" -exec grep -L "status: preregistered" {} \; 2>/dev/null | while read f; do
  echo "  FAIL: $(basename $f) — no preregistered status"
done

# Check: preregistered hypotheses with no activity in 30 days
echo "2. Stale hypotheses (>30 days since preregistration):"
find "$LABS/hypotheses" -name "*.md" -newer "$LABS/hypotheses" -mtime +30 2>/dev/null | while read f; do
  echo "  WARN: $(basename $f) — no activity in 30+ days"
done

# Check: results not published
echo "3. Unpublished results:"
find "$LABS/results" -name "*.md" -exec grep -L "published: true" {} \; 2>/dev/null | while read f; do
  echo "  INFO: $(basename $f) — result not yet published"
done

# Check: budget exceeded
echo "4. Budget status:"
echo "  (review hypotheses/ for budget_tokens and budget_hours)"

echo "=== Audit complete ==="
