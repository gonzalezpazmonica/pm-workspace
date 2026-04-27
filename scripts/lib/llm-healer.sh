#!/usr/bin/env bash
set -uo pipefail
# llm-healer.sh — SE-076 Slice 3
#
# Reusable wrapper: run a query, if it fails with a parseable error,
# feed the error back to an LLM with a corrector prompt and retry. Bounded
# by LLM_HEALER_MAX_ATTEMPTS (default 3). Records recovery rate metrics.
#
# Heredado el patrón del LLM-healing approach de QueryWeaver (FalkorDB) sin
# importar código (AGPL-3.0 incompatible). Re-implementación clean-room.
#
# Usage (programmatic — sourced by other scripts):
#   source scripts/lib/llm-healer.sh
#   heal_run "<query>" "<runner_cmd>" "<heal_prompt_template>"
#
# Usage (CLI):
#   bash scripts/lib/llm-healer.sh --query "<text>" \
#                                  --runner "<command-that-takes-stdin>" \
#                                  --prompt-template "<template-with-{error}>"
#
# Env:
#   LLM_HEALER_MAX_ATTEMPTS  default 3 (1 initial + 2 heal retries)
#   LLM_HEALER_LLM_CMD       default "claude -p" (or set to opencode CLI)
#   LLM_HEALER_STATS_FILE    default ${ROOT}/output/llm-healer-stats.jsonl
#   LLM_HEALER_DEBUG         set to 1 for verbose stderr trace
#
# Exit codes:
#   0 ok (initial success or recovered after healing)
#   1 unhealable — exhausted attempts, last error in stderr
#   2 usage error
#
# Reference: SE-076 (docs/propuestas/SE-076-queryweaver-patterns.md)
# Reference: FalkorDB/QueryWeaver pattern (AGPL — re-implementation only)

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LLM_HEALER_MAX_ATTEMPTS="${LLM_HEALER_MAX_ATTEMPTS:-3}"
LLM_HEALER_LLM_CMD="${LLM_HEALER_LLM_CMD:-claude -p}"
LLM_HEALER_STATS_FILE="${LLM_HEALER_STATS_FILE:-${ROOT}/output/llm-healer-stats.jsonl}"
LLM_HEALER_DEBUG="${LLM_HEALER_DEBUG:-0}"

_dbg() { [[ "$LLM_HEALER_DEBUG" == "1" ]] && echo "llm-healer: $*" >&2 || true; }

_record_stat() {
  local healed="$1" attempts="$2" runner="$3"
  mkdir -p "$(dirname "$LLM_HEALER_STATS_FILE")" 2>/dev/null || true
  local ts; ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '{"ts":"%s","healed":%s,"attempts":%s,"runner":"%s"}\n' \
    "$ts" "$healed" "$attempts" "$runner" \
    >> "$LLM_HEALER_STATS_FILE" 2>/dev/null || true
}

# Public: heal_run <query> <runner_cmd> <heal_prompt_template>
#   - <runner_cmd> is the shell command that consumes the query on stdin
#     and returns 0 on success / non-zero on failure with error to stderr
#   - <heal_prompt_template> contains placeholders:
#       {original_query} → original input
#       {error}          → captured stderr from last failed attempt
#       {attempt}        → 1-based attempt number
heal_run() {
  local query="$1" runner="$2" tpl="${3:-}"
  [[ -z "$query"  ]] && { echo "ERROR: heal_run requires <query>" >&2; return 2; }
  [[ -z "$runner" ]] && { echo "ERROR: heal_run requires <runner_cmd>" >&2; return 2; }
  if [[ -z "$tpl" ]]; then
    tpl='The previous attempt failed with this error:
{error}

Original input was:
{original_query}

This is attempt {attempt}. Produce a corrected version that addresses the error. Return ONLY the corrected query/code, no commentary.'
  fi

  local current="$query"
  local last_stderr=""
  local attempt=0
  while (( attempt < LLM_HEALER_MAX_ATTEMPTS )); do
    attempt=$((attempt + 1))
    _dbg "attempt ${attempt}/${LLM_HEALER_MAX_ATTEMPTS}"
    local stdout stderr_file rc
    stderr_file=$(mktemp)
    stdout=$(printf '%s' "$current" | bash -c "$runner" 2>"$stderr_file")
    rc=$?
    last_stderr=$(cat "$stderr_file" 2>/dev/null || true)
    rm -f "$stderr_file"
    if (( rc == 0 )); then
      printf '%s' "$stdout"
      _record_stat "true" "$attempt" "${runner%% *}"
      return 0
    fi
    _dbg "attempt ${attempt} failed rc=${rc} err=${last_stderr:0:200}"
    if (( attempt >= LLM_HEALER_MAX_ATTEMPTS )); then
      break
    fi
    # Build heal prompt and ask the LLM for a corrected query
    local heal_prompt
    heal_prompt="${tpl//\{error\}/$last_stderr}"
    heal_prompt="${heal_prompt//\{original_query\}/$query}"
    heal_prompt="${heal_prompt//\{attempt\}/$((attempt+1))}"
    local healed
    healed=$(printf '%s' "$heal_prompt" | bash -c "$LLM_HEALER_LLM_CMD" 2>/dev/null || true)
    if [[ -z "$healed" ]]; then
      _dbg "LLM produced empty heal — aborting"
      break
    fi
    current="$healed"
  done
  echo "$last_stderr" >&2
  _record_stat "false" "$attempt" "${runner%% *}"
  return 1
}

# Public: heal_stats — print recovery rate from stats file
heal_stats() {
  if [[ ! -f "$LLM_HEALER_STATS_FILE" ]]; then
    echo "no stats yet"
    return 0
  fi
  python3 - "$LLM_HEALER_STATS_FILE" <<'PY'
import json, sys
from collections import Counter
c = Counter()
total = 0
with open(sys.argv[1]) as f:
    for line in f:
        try:
            d = json.loads(line)
            total += 1
            if d.get("healed") is True or d.get("healed") == "true":
                c["healed"] += 1
            else:
                c["failed"] += 1
        except Exception:
            continue
healed = c["healed"]
failed = c["failed"]
if total == 0:
    print("no parseable stats")
else:
    rate = (healed / total) * 100
    print(f"total={total} healed={healed} failed={failed} recovery={rate:.1f}%")
PY
}

# CLI entrypoint when invoked directly (not sourced)
# `${BASH_SOURCE[0]}` equals `$0` when this script is the entrypoint.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  CMD="${1:-}"
  shift || true
  case "$CMD" in
    --help|-h|help)
      sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    stats) heal_stats; exit 0 ;;
    run|"")
      QUERY=""; RUNNER=""; TPL=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --query)            QUERY="${2:?}"; shift 2 ;;
          --runner)           RUNNER="${2:?}"; shift 2 ;;
          --prompt-template)  TPL="${2:?}"; shift 2 ;;
          *) echo "Unknown flag: $1" >&2; exit 2 ;;
        esac
      done
      [[ -z "$QUERY"  ]] && { echo "ERROR: --query required" >&2; exit 2; }
      [[ -z "$RUNNER" ]] && { echo "ERROR: --runner required" >&2; exit 2; }
      heal_run "$QUERY" "$RUNNER" "$TPL"
      exit $?
      ;;
    *) echo "Unknown subcommand: $CMD" >&2; exit 2 ;;
  esac
fi
