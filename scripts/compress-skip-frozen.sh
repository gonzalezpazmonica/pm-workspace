#!/usr/bin/env bash
# compress-skip-frozen.sh — SE-029 Slice 3 frozen-core advisory.
#
# Decides whether a given turn/text should be SKIPPED from compression
# because its task-class (from Slice 2 classifier) is declared "frozen".
# Frozen classes: decision, spec, code (partial) — see SE-029 §4.
#
# Advisory-only in this slice: the script emits a verdict but does NOT
# block any compression itself. Intended integration (Slice 4): wrap
# PreToolUse on `context-compress` / `semantic-compact` skills to enforce.
#
# Usage:
#   compress-skip-frozen.sh --input turn.txt
#   echo "text" | compress-skip-frozen.sh --stdin
#   compress-skip-frozen.sh --input t.txt --json    # JSON output
#   compress-skip-frozen.sh --input t.txt --strict  # exit 1 on SKIP (blocking)
#
# Exit codes:
#   0 — COMPRESS allowed (class not frozen) OR advisory mode (default)
#   1 — SKIP requested (frozen class) AND --strict flag given
#   2 — usage error
#
# Ref: SE-029 §4 (SE-029-F), ROADMAP §Tier 4.1
# Dep: scripts/context-task-classify.sh (SE-029 Slice 2)
# Safety: read-only, set -uo pipefail.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CLASSIFIER="$REPO_ROOT/scripts/context-task-classify.sh"

INPUT=""
STDIN=0
JSON=0
STRICT=0

usage() {
  cat <<EOF
Usage:
  $0 --input FILE                Advisory decision (always exit 0)
  $0 --stdin                     Classify stdin
  $0 --input FILE --json         Emit JSON verdict
  $0 --input FILE --strict       Exit 1 if SKIP (blocking mode, advisory→hard)

Verdicts:
  SKIP     — frozen class (decision, spec, or code+frozen) — do not compress
  COMPRESS — non-frozen class (review, context, chitchat, code-partial) — allowed

Ref: SE-029 §4 (SE-029-F). Uses scripts/context-task-classify.sh as dep.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --stdin) STDIN=1; shift ;;
    --json) JSON=1; shift ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

if [[ ! -x "$CLASSIFIER" ]]; then
  echo "ERROR: classifier not found or not executable: $CLASSIFIER" >&2
  exit 2
fi

if [[ "$STDIN" -eq 1 ]]; then
  TEXT=$(cat)
elif [[ -n "$INPUT" ]]; then
  [[ ! -f "$INPUT" ]] && { echo "ERROR: input file not found: $INPUT" >&2; exit 2; }
  TEXT=$(cat "$INPUT")
else
  usage; exit 2
fi

# Delegate classification to Slice 2 classifier.
CLASSIFIER_JSON=$(echo "$TEXT" | bash "$CLASSIFIER" --stdin --json 2>/dev/null)
if [[ -z "$CLASSIFIER_JSON" ]]; then
  echo "ERROR: classifier produced empty output" >&2
  exit 2
fi

# Parse class and frozen flag from classifier JSON (no jq dep — simple extraction).
CLASS=$(echo "$CLASSIFIER_JSON" | sed -E 's/.*"class":"([^"]+)".*/\1/')
FROZEN=$(echo "$CLASSIFIER_JSON" | sed -E 's/.*"frozen":"([^"]+)".*/\1/')
MAX_RATIO=$(echo "$CLASSIFIER_JSON" | sed -E 's/.*"max_ratio":([0-9]+).*/\1/')

# Verdict logic: frozen=true → SKIP, frozen=false → COMPRESS, frozen=partial → COMPRESS_LIMITED.
verdict=""
reason=""
case "$FROZEN" in
  true)
    verdict="SKIP"
    reason="class '$CLASS' is fully frozen (decision/spec) — compression forbidden"
    ;;
  partial)
    verdict="COMPRESS_LIMITED"
    reason="class '$CLASS' allows compression up to ${MAX_RATIO}:1 (partial frozen)"
    ;;
  false)
    verdict="COMPRESS"
    reason="class '$CLASS' allows compression up to ${MAX_RATIO}:1"
    ;;
  *)
    verdict="UNKNOWN"
    reason="classifier returned unexpected frozen flag: '$FROZEN'"
    ;;
esac

if [[ "$JSON" -eq 1 ]]; then
  cat <<JSON
{"verdict":"$verdict","class":"$CLASS","frozen":"$FROZEN","max_ratio":$MAX_RATIO,"reason":"$reason"}
JSON
else
  echo "$verdict"
  echo "  class: $CLASS"
  echo "  frozen: $FROZEN"
  echo "  max_ratio: ${MAX_RATIO}:1"
  echo "  reason: $reason"
fi

# Strict mode: exit 1 on SKIP so callers can enforce.
if [[ "$STRICT" -eq 1 && "$verdict" == "SKIP" ]]; then
  exit 1
fi

exit 0
