#!/usr/bin/env bash
# agent-degradation-canary.sh — SE-040
# Executes 3 hardcoded canary probes against existing scripts and validates
# their output against known heuristics. Detects behavioral regressions.
#
# Canaries:
#   1. router-mode-classifier.py  "ver sprint" → mode1
#   2. semantic-fault-handlers.py "timeout after 30s" → TRANSIENT
#   3. glm-validate.sh            → PASS or WARN (exit code ≠ 2)
#
# Usage:
#   bash scripts/agent-degradation-canary.sh [--json] [--quiet]
#
# Output:
#   {total: 3, passed: N, failed: [...], degraded: bool}
#
# Exit codes:
#   0 = all canaries passed (not degraded)
#   1 = one or more canaries failed (degraded)
#   2 = usage error

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")}"

JSON_OUT=false
QUIET=false

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)   JSON_OUT=true; shift ;;
    --quiet)  QUIET=true; shift ;;
    -h|--help) usage ;;
    *) echo "Error: unknown flag '$1'" >&2; exit 2 ;;
  esac
done

# ── Canary definitions ────────────────────────────────────────────────────────
declare -a CANARY_NAMES CANARY_CMDS CANARY_EXPECTS CANARY_MATCH_TYPE failed_list
# match_type: contains | contains_any | exit_not

# Canary 1: router-mode-classifier → mode1 for "ver sprint"
CANARY_NAMES[0]="router-mode-classifier"
CANARY_CMDS[0]="echo '{\"intent\":\"ver sprint\",\"command\":\"sprint-status\",\"has_code_change\":false,\"estimated_tokens\":500}' | python3 '$REPO_ROOT/scripts/router-mode-classifier.py'"
CANARY_EXPECTS[0]="mode1"
CANARY_MATCH_TYPE[0]="contains"

# Canary 2: semantic-fault-handlers → TRANSIENT for timeout error
CANARY_NAMES[1]="semantic-fault-handlers"
CANARY_CMDS[1]="python3 '$REPO_ROOT/scripts/semantic-fault-handlers.py' --error 'timeout after 30s'"
CANARY_EXPECTS[1]="TRANSIENT"
CANARY_MATCH_TYPE[1]="contains"

# Canary 3: glm-validate → exit code 0 or 1 (not 2 = crash)
CANARY_NAMES[2]="glm-validate"
CANARY_CMDS[2]="bash '$REPO_ROOT/scripts/glm-validate.sh'"
CANARY_EXPECTS[2]="2"
CANARY_MATCH_TYPE[2]="exit_not"

# ── Execute canaries ──────────────────────────────────────────────────────────
total=3
passed=0


for i in 0 1 2; do
  name="${CANARY_NAMES[$i]}"
  cmd="${CANARY_CMDS[$i]}"
  expect="${CANARY_EXPECTS[$i]}"
  match="${CANARY_MATCH_TYPE[$i]}"

  actual_output=""
  actual_exit=0

  # Run canary with timeout
  actual_output=$(eval "$cmd" 2>&1) || actual_exit=$?

  canary_passed=false
  reason=""

  case "$match" in
    contains)
      if echo "$actual_output" | grep -q "$expect" 2>/dev/null; then
        canary_passed=true
        reason="output contains '$expect'"
      else
        reason="expected output to contain '$expect', got: $(echo "$actual_output" | head -1)"
      fi
      ;;
    contains_any)
      # expect is pipe-separated alternatives
      IFS='|' read -ra alts <<< "$expect"
      for alt in "${alts[@]}"; do
        if echo "$actual_output" | grep -q "$alt" 2>/dev/null; then
          canary_passed=true
          reason="output contains '$alt'"
          break
        fi
      done
      if [[ "$canary_passed" != true ]]; then
        reason="expected output to contain one of '${expect}', got: $(echo "$actual_output" | head -1)"
      fi
      ;;
    exit_not)
      if [[ "$actual_exit" -ne "$expect" ]]; then
        canary_passed=true
        reason="exit code $actual_exit (not $expect)"
      else
        reason="exit code was $actual_exit (should not be $expect)"
      fi
      ;;
  esac

  if [[ "$canary_passed" == true ]]; then
    ((passed++)) || true
    if [[ "$QUIET" != true ]] && [[ "$JSON_OUT" != true ]]; then
      echo "PASS  [$name] $reason"
    fi
  else
    failed_list+=("$name")
    if [[ "$QUIET" != true ]] && [[ "$JSON_OUT" != true ]]; then
      echo "FAIL  [$name] $reason"
    fi
  fi
done

degraded=false
if [[ "${#failed_list[*]}" -gt 0 ]] 2>/dev/null; then degraded=true; fi

# ── Output ────────────────────────────────────────────────────────────────────
if [[ "$JSON_OUT" == true ]]; then
  # Build JSON failed array
  failed_json="["
  first=true
  for f in "${failed_list[@]+"${failed_list[@]}"}"; do
    [[ "$first" == true ]] && first=false || failed_json+=","
    failed_json+="\"$f\""
  done
  failed_json+="]"

  echo "{\"total\":$total,\"passed\":$passed,\"failed\":$failed_json,\"degraded\":$degraded}"
else
  if [[ "$QUIET" != true ]]; then
    echo ""
    echo "=== Agent Degradation Canary (SE-040) ==="
  fi
  echo "{\"total\":$total,\"passed\":$passed,\"failed\":[$(
    first=true
    for f in "${failed_list[@]+"${failed_list[@]}"}"; do
      [[ "$first" == true ]] && first=false || printf ","
      printf '"%s"' "$f"
    done
  )],\"degraded\":$degraded}"
fi

[[ "$degraded" == true ]] && exit 1 || exit 0
