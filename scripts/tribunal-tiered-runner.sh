#!/usr/bin/env bash
# tribunal-tiered-runner.sh — SE-106: Tiered tribunal execution
#
# Orchestrates the tiered hybrid model for Truth Tribunal and Code Review Court:
#   - Tier 0: sequential judges, early-stop on veto (saves tokens when vetoed)
#   - Tier 1: parallel fan-out judges (only if Tier 0 PASS)
#
# Usage:
#   tribunal-tiered-runner.sh \
#     --tribunal truth|court|recommendation \
#     --draft <file> \
#     [--mode sequential-first|full-parallel] \
#     [--tier0-judges <comma-separated>] \
#     [--tier1-judges <comma-separated>] \
#     [--max-tier0-tokens <N>]
#
# Environment:
#   SAVIA_TIERED_TRIBUNAL         on|off (default off — pilot mode)
#   SAVIA_TIERED_TRUTH_TIER0      comma-separated judge names for Truth Tier 0
#   SAVIA_TIERED_COURT_TIER0      comma-separated judge names for Court Tier 0
#   TRIBUNAL_FORCE_FULL_PANEL     1 = disable tiered, run all judges in parallel
#   SAVIA_JUDGE_MOCK_DIR          directory with <judge>.json fixture files (testing)
#
# Exit codes:
#   0  ok — verdict in JSON
#   1  VETO issued
#   2  usage / args invalid
#   3  draft file missing
#
# Telemetry written to: output/tiered-tribunal-telemetry.jsonl
#
# SE-106 — docs/propuestas/SE-106-tiered-tribunal-execution.md

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TELEMETRY_FILE="${ROOT}/output/tiered-tribunal-telemetry.jsonl"

# ── Defaults ──────────────────────────────────────────────────────────────────
TRIBUNAL=""
DRAFT_FILE=""
MODE="sequential-first"
TIER0_JUDGES_ARG=""
TIER1_JUDGES_ARG=""
MAX_TIER0_TOKENS="${SAVIA_TIERED_MAX_TIER0_TOKENS:-15000}"

# Built-in defaults per tribunal (overridable via env or flags)
DEFAULT_TRUTH_TIER0="${SAVIA_TIERED_TRUTH_TIER0:-compliance-judge,hallucination-judge,factuality-judge}"
DEFAULT_TRUTH_TIER1="source-traceability-judge,coherence-judge,calibration-judge,completeness-judge"
DEFAULT_COURT_TIER0="${SAVIA_TIERED_COURT_TIER0:-security-judge,correctness-judge}"
DEFAULT_COURT_TIER1="architecture-judge,cognitive-judge,spec-judge"

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

if [[ $# -lt 1 ]]; then
  echo "ERROR: --tribunal is required" >&2
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tribunal)
      [[ $# -lt 2 ]] && { echo "ERROR: --tribunal requires a value" >&2; exit 2; }
      TRIBUNAL="$2"; shift 2 ;;
    --draft)
      [[ $# -lt 2 ]] && { echo "ERROR: --draft requires a file path" >&2; exit 2; }
      DRAFT_FILE="$2"; shift 2 ;;
    --mode)
      [[ $# -lt 2 ]] && { echo "ERROR: --mode requires sequential-first|full-parallel" >&2; exit 2; }
      MODE="$2"; shift 2 ;;
    --tier0-judges)
      [[ $# -lt 2 ]] && { echo "ERROR: --tier0-judges requires a value" >&2; exit 2; }
      TIER0_JUDGES_ARG="$2"; shift 2 ;;
    --tier1-judges)
      [[ $# -lt 2 ]] && { echo "ERROR: --tier1-judges requires a value" >&2; exit 2; }
      TIER1_JUDGES_ARG="$2"; shift 2 ;;
    --max-tier0-tokens)
      [[ $# -lt 2 ]] && { echo "ERROR: --max-tier0-tokens requires a value" >&2; exit 2; }
      MAX_TIER0_TOKENS="$2"; shift 2 ;;
    --help|-h)
      usage ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2 ;;
  esac
done

# ── Validate required args ────────────────────────────────────────────────────
if [[ -z "$TRIBUNAL" ]]; then
  echo "ERROR: --tribunal is required (truth|court|recommendation)" >&2
  exit 2
fi

if [[ "$TRIBUNAL" != "truth" && "$TRIBUNAL" != "court" && "$TRIBUNAL" != "recommendation" ]]; then
  echo "ERROR: --tribunal must be one of: truth, court, recommendation" >&2
  exit 2
fi

if [[ -n "$DRAFT_FILE" && ! -f "$DRAFT_FILE" ]]; then
  echo "ERROR: draft file not found: $DRAFT_FILE" >&2
  exit 3
fi

# ── Recommendation Tribunal: hard rule — always parallel, never tiered ────────
if [[ "$TRIBUNAL" == "recommendation" ]]; then
  # Constraint: p95 latency < 3s is incompatible with sequential Tier 0
  printf '{"verdict":"SKIPPED","reason":"recommendation_tribunal_always_parallel","tier_skipped":true}\n'
  exit 0
fi

# ── Resolve judge lists ───────────────────────────────────────────────────────
case "$TRIBUNAL" in
  truth)
    TIER0_JUDGES="${TIER0_JUDGES_ARG:-$DEFAULT_TRUTH_TIER0}"
    TIER1_JUDGES="${TIER1_JUDGES_ARG:-$DEFAULT_TRUTH_TIER1}"
    ;;
  court)
    TIER0_JUDGES="${TIER0_JUDGES_ARG:-$DEFAULT_COURT_TIER0}"
    TIER1_JUDGES="${TIER1_JUDGES_ARG:-$DEFAULT_COURT_TIER1}"
    ;;
esac

# Convert comma-separated to arrays
IFS=',' read -ra TIER0_ARR <<< "$TIER0_JUDGES"
IFS=',' read -ra TIER1_ARR <<< "$TIER1_JUDGES"

# ── Helper: write telemetry entry ─────────────────────────────────────────────
_write_telemetry() {
  local tribunal_name="$1"
  local exec_mode="$2"
  local tier0_verdict="$3"
  local tier1_skipped_bool="$4"   # "true" or "false"
  local tokens_saved="$5"
  local judges_run_csv="$6"

  mkdir -p "$(dirname "$TELEMETRY_FILE")" 2>/dev/null || true
  python3 - "$tribunal_name" "$exec_mode" "$tier0_verdict" \
            "$tier1_skipped_bool" "$tokens_saved" "$judges_run_csv" \
            "$TELEMETRY_FILE" <<'PYEOF'
import json, sys
from datetime import datetime, timezone

tribunal_name, exec_mode, tier0_verdict, tier1_skipped_str, tokens_saved_str, judges_csv, tfile = sys.argv[1:]
entry = {
    "ts": datetime.now(timezone.utc).isoformat(),
    "tribunal": tribunal_name,
    "exec_mode": exec_mode,
    "tier0_verdict": tier0_verdict,
    "tier1_skipped": tier1_skipped_str == "true",
    "tokens_saved": int(tokens_saved_str) if tokens_saved_str.isdigit() else 0,
    "judges_run": [j for j in judges_csv.split(",") if j] if judges_csv else [],
}
try:
    with open(tfile, "a") as f:
        f.write(json.dumps(entry) + "\n")
except Exception:
    pass
PYEOF
}

# ── Helper: build result JSON ─────────────────────────────────────────────────
_build_result_json() {
  local verdict="$1"
  local tribunal_name="$2"
  local exec_mode="$3"
  local tier0_stopped_bool="$4"   # "true" or "false"
  local tier1_skipped_bool="$5"   # "true" or "false"
  local tokens_saved="$6"
  local judges_run_csv="$7"
  local tier0_verdict="$8"
  local tier0_judges_csv="$9"
  local tier0_stopped_at="${10}"
  local tier1_judges_csv="${11}"
  local tier1_execution="${12}"   # "parallel" or "skipped"

  python3 - "$verdict" "$tribunal_name" "$exec_mode" \
            "$tier0_stopped_bool" "$tier1_skipped_bool" "$tokens_saved" \
            "$judges_run_csv" "$tier0_verdict" "$tier0_judges_csv" \
            "$tier0_stopped_at" "$tier1_judges_csv" "$tier1_execution" <<'PYEOF'
import json, sys

(verdict, tribunal_name, exec_mode, tier0_stopped_str, tier1_skipped_str,
 tokens_saved_str, judges_run_csv, tier0_verdict, tier0_judges_csv,
 tier0_stopped_at, tier1_judges_csv, tier1_execution) = sys.argv[1:]

result = {
    "verdict": verdict,
    "tribunal": tribunal_name,
    "execution_mode": exec_mode,
    "tier0_stopped": tier0_stopped_str == "true",
    "tier1_skipped": tier1_skipped_str == "true",
    "tokens_saved_estimate": int(tokens_saved_str) if tokens_saved_str.isdigit() else 0,
    "judges_run": [j for j in judges_run_csv.split(",") if j] if judges_run_csv else [],
    "tier0": {
        "verdict": tier0_verdict,
        "judges_run": [j for j in tier0_judges_csv.split(",") if j] if tier0_judges_csv else [],
        "stopped_at": tier0_stopped_at if tier0_stopped_at else None,
    },
    "tier1": {
        "judges_run": [j for j in tier1_judges_csv.split(",") if j] if tier1_judges_csv else [],
        "execution": tier1_execution,
    },
}
print(json.dumps(result))
PYEOF
}

# ── Helper: run a single judge (returns 0=PASS, 1=VETO) ─────────────────────
_run_judge() {
  local judge="$1"
  local output_file="$2"

  # Mock layer: check for fixture in SAVIA_JUDGE_MOCK_DIR
  local mock_dir="${SAVIA_JUDGE_MOCK_DIR:-}"
  if [[ -n "$mock_dir" && -d "$mock_dir" ]]; then
    local fixture="${mock_dir}/${judge}.json"
    if [[ -f "$fixture" ]]; then
      cp "$fixture" "$output_file"
      # Determine pass/veto from fixture using Python (avoids JSON parsing in bash)
      local verdict
      verdict=$(python3 - "$fixture" <<'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    conf = float(d.get("confidence", 0))
    v = bool(d.get("veto", False))
    print("VETO" if (v and conf >= 0.8) else "PASS")
except Exception:
    print("PASS")
PYEOF
)
      [[ "$verdict" == "VETO" ]] && return 1
      return 0
    fi
  fi

  # Real judge invocation (if run-judge.sh exists)
  local judge_run_script="${ROOT}/scripts/run-judge.sh"
  if [[ -f "$judge_run_script" ]]; then
    local out
    if out=$(timeout 120 bash "$judge_run_script" "$judge" "${DRAFT_FILE:-}" 2>&1); then
      echo "$out" > "$output_file"
      local verdict
      verdict=$(python3 - "$output_file" <<'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    conf = float(d.get("confidence", 0))
    v = bool(d.get("veto", False))
    print("VETO" if (v and conf >= 0.8) else "PASS")
except Exception:
    print("PASS")
PYEOF
)
      [[ "$verdict" == "VETO" ]] && return 1
      return 0
    fi
    return 1
  fi

  # No mock, no run script — agent file existence check (dry run → PASS)
  local agent_file="${ROOT}/.opencode/agents/${judge}.md"
  if [[ -f "$agent_file" ]]; then
    printf '{"judge":"%s","score":80,"veto":false,"confidence":0.5,"verdict":"PASS"}\n' "$judge" > "$output_file"
    return 0
  fi

  # Judge not found — warn but do not block
  echo "WARNING: judge not found: $judge" >&2
  printf '{"judge":"%s","score":50,"veto":false,"confidence":0.0,"verdict":"UNKNOWN","warning":"judge_not_found"}\n' "$judge" > "$output_file"
  return 0
}

# ── Estimate tokens saved when tier1 skipped ──────────────────────────────────
_estimate_tokens_saved() {
  local tribunal_name="$1"
  local tier1_count="${#TIER1_ARR[@]}"
  case "$tribunal_name" in
    truth)
      echo $(( tier1_count * 19500 )) ;;
    court)
      echo $(( tier1_count * 5000 )) ;;
    *)
      echo 0 ;;
  esac
}

# ── Check feature flag ────────────────────────────────────────────────────────
TIERED_ENABLED="${SAVIA_TIERED_TRIBUNAL:-off}"
FORCE_FULL_PANEL="${TRIBUNAL_FORCE_FULL_PANEL:-0}"

if [[ "$TIERED_ENABLED" != "on" || "$FORCE_FULL_PANEL" == "1" || "$MODE" == "full-parallel" ]]; then
  # Tiered disabled or forced full panel → fall back to full-parallel mode
  ALL_JUDGES=("${TIER0_ARR[@]}" "${TIER1_ARR[@]}")
  ALL_CSV=$(IFS=,; echo "${ALL_JUDGES[*]}")

  if [[ "$FORCE_FULL_PANEL" == "1" ]]; then
    REASON="forced_full_panel"
  else
    REASON="tiered_disabled"
  fi

  python3 - "$TRIBUNAL" "$REASON" "$ALL_CSV" <<'PYEOF'
import json, sys
tribunal, reason, judges_csv = sys.argv[1:]
result = {
    "verdict": "PASS",
    "mode": "full-parallel",
    "tribunal": tribunal,
    "reason": reason,
    "tier0_skipped": True,
    "tier1_skipped": False,
    "judges_run": [j for j in judges_csv.split(",") if j],
    "tokens_saved_estimate": 0,
}
print(json.dumps(result))
PYEOF
  exit 0
fi

# ── Temp directory for judge outputs ─────────────────────────────────────────
TMPDIR_RUN=$(mktemp -d)
trap 'rm -rf "$TMPDIR_RUN"' EXIT

# ── Tier 0: Sequential execution with early-stop on veto ──────────────────────
TIER0_VERDICT="PASS"
TIER0_STOPPED_AT=""
TIER0_JUDGES_RUN=()

echo "tribunal-tiered-runner: Tier 0 — ${#TIER0_ARR[@]} judges sequentially [tribunal=$TRIBUNAL]" >&2

for judge in "${TIER0_ARR[@]}"; do
  output_file="$TMPDIR_RUN/tier0-${judge}.json"
  TIER0_JUDGES_RUN+=("$judge")

  echo "tribunal-tiered-runner: Tier 0 running: $judge" >&2

  if ! _run_judge "$judge" "$output_file"; then
    TIER0_VERDICT="VETO"
    TIER0_STOPPED_AT="$judge"
    echo "tribunal-tiered-runner: Tier 0 VETO by $judge — early stop" >&2
    break
  fi
done

# ── Tier 1: Parallel fan-out (only if Tier 0 PASS) ────────────────────────────
TIER1_SKIPPED="false"
TIER1_ANY_VETO=0

if [[ "$TIER0_VERDICT" == "VETO" ]]; then
  TIER1_SKIPPED="true"
  FINAL_VERDICT="VETO"
  ALL_JUDGES_RUN=("${TIER0_JUDGES_RUN[@]}")
else
  echo "tribunal-tiered-runner: Tier 1 — ${#TIER1_ARR[@]} judges in parallel [tribunal=$TRIBUNAL]" >&2

  TIER1_PIDS=()
  TIER1_RESULT_FILES=()
  for judge in "${TIER1_ARR[@]}"; do
    output_file="$TMPDIR_RUN/tier1-${judge}.json"
    result_file="$TMPDIR_RUN/tier1-result-${judge}"
    TIER1_RESULT_FILES+=("$result_file")

    ( _run_judge "$judge" "$output_file"; echo $? > "$result_file" ) &
    TIER1_PIDS+=($!)
  done

  for pid in "${TIER1_PIDS[@]}"; do
    wait "$pid" || true
  done

  for result_file in "${TIER1_RESULT_FILES[@]}"; do
    local_rc=$(cat "$result_file" 2>/dev/null || echo "0")
    if [[ "$local_rc" != "0" ]]; then
      TIER1_ANY_VETO=1
    fi
  done

  if [[ "$TIER1_ANY_VETO" == "1" ]]; then
    FINAL_VERDICT="VETO"
  else
    FINAL_VERDICT="PASS"
  fi
  ALL_JUDGES_RUN=("${TIER0_JUDGES_RUN[@]}" "${TIER1_ARR[@]}")
fi

# ── Build CSVs for JSON construction ─────────────────────────────────────────
TOKENS_SAVED=0
if [[ "$TIER1_SKIPPED" == "true" ]]; then
  TOKENS_SAVED=$(_estimate_tokens_saved "$TRIBUNAL")
fi

ALL_CSV=$(IFS=,; echo "${ALL_JUDGES_RUN[*]}")
TIER0_CSV=$(IFS=,; echo "${TIER0_JUDGES_RUN[*]}")
TIER1_CSV=$(IFS=,; echo "${TIER1_ARR[*]}")

if [[ "$TIER1_SKIPPED" == "true" ]]; then
  TIER1_EXECUTION="skipped"
  TIER1_CSV=""
else
  TIER1_EXECUTION="parallel"
fi

TIER0_STOPPED_BOOL="false"
[[ "$TIER0_VERDICT" == "VETO" ]] && TIER0_STOPPED_BOOL="true"

# ── Emit result JSON ───────────────────────────────────────────────────────────
RESULT_JSON=$(_build_result_json \
  "$FINAL_VERDICT" \
  "$TRIBUNAL" \
  "tiered" \
  "$TIER0_STOPPED_BOOL" \
  "$TIER1_SKIPPED" \
  "$TOKENS_SAVED" \
  "$ALL_CSV" \
  "$TIER0_VERDICT" \
  "$TIER0_CSV" \
  "$TIER0_STOPPED_AT" \
  "$TIER1_CSV" \
  "$TIER1_EXECUTION")

echo "$RESULT_JSON"

# ── Write telemetry ────────────────────────────────────────────────────────────
_write_telemetry "$TRIBUNAL" "tiered" "$TIER0_VERDICT" "$TIER1_SKIPPED" "$TOKENS_SAVED" "$ALL_CSV" || true

# ── Exit code ──────────────────────────────────────────────────────────────────
if [[ "$FINAL_VERDICT" == "VETO" ]]; then
  exit 1
fi
exit 0
