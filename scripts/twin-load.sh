#!/usr/bin/env bash
# twin-load.sh — Carga y muestra el twin de un proyecto (SPEC-169 AC-2, AC-5)
# Usage: bash scripts/twin-load.sh {slug} [--summary]
# Exit: 0 OK | 1 STALE | 2 ERROR | 3 N4_IN_N1_BLOCKED
# AC-2: token output ≤ token_budget declared in twin.md
# AC-5: refuses N4 content in N1 context
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${TWIN_ROOT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LINTER="$SCRIPT_DIR/twin-linter.sh"
TELEMETRY_DIR="${ROOT_DIR}/output/twin-runs"
LOADS_LOG="${TELEMETRY_DIR}/loads.jsonl"

SLUG="${1:-}"
MODE="${2:-}"

[[ -z "$SLUG" ]] && { echo "Usage: twin-load.sh {slug} [--summary]" >&2; exit 2; }

TWIN_FILE="${ROOT_DIR}/projects/${SLUG}/twin.md"
[[ ! -f "$TWIN_FILE" ]] && { echo "ERROR: twin not found for project '${SLUG}': ${TWIN_FILE}" >&2; exit 2; }

# ── AC-5: N4 context guard ────────────────────────────────────────────────────
# If TWIN_CONTEXT env var is N1 (public), refuse N4 twin content (projects/ is N2).
# Projects/ twins are N2 by default; anonymized twins in docs/case-studies/ are N1.
CONTEXT_LAYER="${TWIN_CONTEXT:-N2}"
if [[ "$CONTEXT_LAYER" == "N1" ]]; then
  echo "BLOCKED: N4 content (projects/${SLUG}/twin.md) refused in N1 context." >&2
  echo "Use /twin-anonymize to get the public-safe version." >&2
  exit 3
fi

# ── Validate (calls linter) ───────────────────────────────────────────────────
lint_exit=0
bash "$LINTER" "$TWIN_FILE" >/dev/null 2>&1 || lint_exit=$?

if [[ "$lint_exit" -eq 2 ]]; then
  echo "ERROR: ${SLUG}/twin.md failed schema validation. Run twin-linter.sh for details." >&2
  exit 2
fi

if [[ "$lint_exit" -eq 1 ]]; then
  echo "WARN: ${SLUG}/twin.md is STALE — refresh recommended before loading." >&2
fi

# ── Estimate token count ──────────────────────────────────────────────────────
TWIN_CONTENT=$(cat "$TWIN_FILE")
CHAR_COUNT=${#TWIN_CONTENT}
TOKEN_EST=$(( CHAR_COUNT / 4 ))

# Read budget from frontmatter
TOKEN_BUDGET=$(grep -E "^token_budget:" "$TWIN_FILE" | head -1 | grep -oE "[0-9]+" || echo "2000")

if [[ "$TOKEN_EST" -gt "$TOKEN_BUDGET" ]]; then
  echo "WARN: estimated tokens ${TOKEN_EST} exceeds budget ${TOKEN_BUDGET}. Content will be truncated." >&2
  TWIN_CONTENT="${TWIN_CONTENT:0:$(( TOKEN_BUDGET * 4 ))}"
fi

# ── Summary mode ─────────────────────────────────────────────────────────────
if [[ "$MODE" == "--summary" ]]; then
  HEALTH=$(grep -E "^health:" "$TWIN_FILE" | head -1 | sed 's/.*: *//' | tr -d '"')
  LAST_REFRESH=$(grep -E "^last_refresh:" "$TWIN_FILE" | head -1 | sed 's/.*: *//' | tr -d '"')
  echo "=== Twin: ${SLUG} ==="
  echo "Health:       ${HEALTH}"
  echo "Last refresh: ${LAST_REFRESH}"
  echo "Tokens (est): ${TOKEN_EST}/${TOKEN_BUDGET}"
  if [[ "$lint_exit" -eq 1 ]]; then echo "Status:       STALE"; else echo "Status:       OK"; fi
  # Print only Estado section
  awk '/^## Estado/{found=1} found{print} /^## [^E]/{if(found) exit}' "$TWIN_FILE"
else
  echo "$TWIN_CONTENT"
fi

# ── Telemetry (AC-8) ─────────────────────────────────────────────────────────
mkdir -p "$TELEMETRY_DIR"
printf '{"ts":"%s","slug":"%s","mode":"%s","tokens_est":%d,"budget":%d,"lint_exit":%d}\n' \
  "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$SLUG" "${MODE:---load}" \
  "$TOKEN_EST" "$TOKEN_BUDGET" "$lint_exit" >> "$LOADS_LOG" 2>/dev/null || true

[[ "$lint_exit" -eq 1 ]] && exit 1
exit 0
