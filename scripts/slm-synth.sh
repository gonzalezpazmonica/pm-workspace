#!/usr/bin/env bash
# slm-synth.sh — SE-028 slice 1
# Wrapper over `oumi synth` for per-project synthetic data generation.
# Falls back gracefully if oumi not installed.
# Ref: docs/rules/domain/slm-pipeline-protocol.md
#
# Usage:
#   bash scripts/slm-synth.sh --project NAME --recipe PATH [--dry-run] [--json]
#
# Exit codes:
#   0 = synth ran (or dry-run succeeded)
#   1 = SKIPPED (oumi not installed or dry-run)
#   2 = input error / zero-egress violation

set -uo pipefail

PROJECT=""
RECIPE=""
DRY_RUN=false
JSON_OUT=false

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --recipe) RECIPE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --json) JSON_OUT=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: unknown flag $1" >&2; exit 2 ;;
  esac
done

[[ -z "$PROJECT" ]] && { echo "Error: --project required" >&2; exit 2; }

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}" || REPO_ROOT="."

# ── Default recipe path ──────────────────────────────────────────────────────
if [[ -z "$RECIPE" ]]; then
  RECIPE="$REPO_ROOT/projects/$PROJECT/.slm/recipes/fine-tune.yaml"
fi

[[ ! -f "$RECIPE" ]] && { echo "Error: recipe not found: $RECIPE" >&2; exit 2; }

# ── Zero-egress check ────────────────────────────────────────────────────────
# Reject recipes with cloud deploy targets
if grep -qE '^\s*deploy:\s*"?(fireworks|openrouter|bedrock|anthropic|openai)' "$RECIPE" 2>/dev/null; then
  echo "Error: zero-egress violation — recipe references cloud deploy target" >&2
  echo "       Only 'deploy: ollama' or 'deploy: local' allowed" >&2
  exit 2
fi

# ── Graceful fallback if oumi not installed ──────────────────────────────────
OUMI_AVAILABLE=false
if command -v oumi >/dev/null 2>&1 || python3 -c "import oumi" 2>/dev/null; then
  OUMI_AVAILABLE=true
fi

# ── Dry-run mode ─────────────────────────────────────────────────────────────
if $DRY_RUN; then
  if $JSON_OUT; then
    printf '{"project":"%s","recipe":"%s","dry_run":true,"oumi_available":%s,"status":"SKIPPED"}\n' \
      "$PROJECT" "$RECIPE" "$OUMI_AVAILABLE"
  else
    echo "=== slm-synth dry-run ==="
    echo "  project:        $PROJECT"
    echo "  recipe:         $RECIPE"
    echo "  oumi installed: $OUMI_AVAILABLE"
    echo "  would run:      oumi synth --config $RECIPE"
  fi
  exit 1
fi

# ── If oumi missing, fail graceful ───────────────────────────────────────────
if ! $OUMI_AVAILABLE; then
  if $JSON_OUT; then
    printf '{"project":"%s","status":"SKIPPED","reason":"oumi_not_installed","install":"pip install oumi==0.7"}\n' "$PROJECT"
  else
    echo "SKIPPED: oumi not installed"
    echo "        Install with: pip install oumi==0.7"
    echo "        Or use --dry-run to validate recipe"
  fi
  exit 1
fi

# ── Actual oumi invocation (real path) ───────────────────────────────────────
# Extract config from recipe and forward
if $JSON_OUT; then
  printf '{"project":"%s","recipe":"%s","status":"RUNNING"}\n' "$PROJECT" "$RECIPE"
else
  echo "=== slm-synth running ==="
  echo "  project: $PROJECT"
  echo "  recipe:  $RECIPE"
fi

# Delegated to oumi (stub — full integration TODO in slice 2)
oumi synth --config "$RECIPE" 2>&1 || {
  echo "Error: oumi synth failed" >&2
  exit 2
}

exit 0
