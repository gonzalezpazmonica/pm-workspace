#!/usr/bin/env bash
# test-auditor.sh — Score, validate, and certify BATS test files
# SPEC-055: 9-criteria deterministic scoring (0-100), no LLM calls
#
# Usage:
#   bash scripts/test-auditor.sh <test-file.bats>
#   bash scripts/test-auditor.sh --all [--json]
#   bash scripts/test-auditor.sh <test-file.bats> --embed
#
# Output: JSON with per-criterion scores and certification status
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="single"
EMBED=false
JSON_ALL=false
TARGET=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --all) MODE="all"; shift ;;
    --embed) EMBED=true; shift ;;
    --json) JSON_ALL=true; shift ;;
    --help|-h)
      echo "Usage: test-auditor.sh <file.bats> [--embed] | --all [--json]"
      exit 0 ;;
    *) TARGET="$1"; shift ;;
  esac
done

audit_one() {
  local test_file="$1"
  if [[ ! -f "$test_file" ]]; then
    echo "{\"error\":\"File not found: $test_file\"}"
    return 1
  fi
  python3 "$SCRIPT_DIR/test-auditor-engine.py" "$test_file" "$PROJECT_ROOT"
}

embed_hash() {
  local test_file="$1"
  local score="$2"
  local today
  today=$(date +%Y-%m-%d)
  local raw="${test_file}${score}${today}"
  local hash
  hash=$(echo -n "$raw" | sha256sum | cut -c1-8)
  local audit_line="# audit: score=${score} hash=${hash} date=${today}"

  # Remove existing audit line if present
  if head -3 "$test_file" | grep -q '^# audit:'; then
    local line_num
    line_num=$(grep -n '^# audit:' "$test_file" | head -1 | cut -d: -f1)
    sed -i "${line_num}d" "$test_file"
  fi

  # Insert after shebang (line 1)
  sed -i "1a\\${audit_line}" "$test_file"
}

if [[ "$MODE" == "all" ]]; then
  RESULTS="["
  FIRST=true
  FAIL_COUNT=0
  TOTAL=0

  while IFS= read -r -d '' bats_file; do
    ((TOTAL++))
    result=$(audit_one "$bats_file")
    score=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo "0")

    if [[ "$FIRST" == "true" ]]; then
      FIRST=false
    else
      RESULTS+=","
    fi
    RESULTS+="$result"

    if [[ "$score" -lt 80 ]]; then
      ((FAIL_COUNT++))
    fi
  done < <(find "$PROJECT_ROOT/tests" -name "*.bats" -type f -print0 | sort -z)

  RESULTS+="]"

  if [[ "$JSON_ALL" == "true" ]]; then
    echo "{\"total_files\":$TOTAL,\"failed\":$FAIL_COUNT,\"results\":$RESULTS}"
  else
    echo "Test Auditor: $TOTAL files, $FAIL_COUNT below threshold (80)"
    if [[ $FAIL_COUNT -gt 0 ]]; then
      echo "$RESULTS" | python3 -c "
import json,sys
results=json.load(sys.stdin)
for r in results:
    if r.get('total',0)<80:
        print(f'  FAILED: {r[\"file\"]} — score {r[\"total\"]}/100')
"
    fi
  fi
  exit "$( [[ $FAIL_COUNT -gt 0 ]] && echo 1 || echo 0 )"
fi

# Single file mode
if [[ -z "$TARGET" ]]; then
  echo "ERROR: Provide a .bats file or use --all"
  exit 1
fi

result=$(audit_one "$TARGET")
echo "$result"

score=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo "0")

if [[ "$EMBED" == "true" && "$score" -ge 80 ]]; then
  embed_hash "$TARGET" "$score"
  echo "Embedded certification hash in $TARGET (score=$score)"
elif [[ "$EMBED" == "true" ]]; then
  echo "Score $score < 80: not certified, hash NOT embedded"
fi

exit "$( [[ "$score" -lt 80 ]] && echo 1 || echo 0 )"
