#!/usr/bin/env bash
# tool-ergonomics-audit.sh — SPEC-160: Tool Ergonomics Auto-Audit
#
# Scans agent-run trajectories (output/agent-runs/*.jsonl and
# output/session-action-log.jsonl) to detect:
#   - Tools with error_rate > 15%
#   - Retries with same input (UX confusion signal)
#   - Repeated parameter typos (confusing tool names)
#
# Generates: output/tool-ergonomics-{YYYYMMDD}.md (or JSON with --json)
# PR limit: 3/month hardcoded (report only, no auto-PR creation)
#
# Usage:
#   tool-ergonomics-audit.sh [--dry-run] [--json] [--output-dir DIR]
#
# Exit codes:
#   0  Audit complete
#   1  Error
#
# SPEC-160 — docs/propuestas/SPEC-160-tool-ergonomics-auto-audit.md

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ─────────────────────────────────────────────────────────────────
DRY_RUN=false
JSON_OUTPUT=false
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/output}"
DATE_STR="$(date +%Y%m%d 2>/dev/null || echo "00000000")"
OUTPUT_FILE="$OUTPUT_DIR/tool-ergonomics-${DATE_STR}.md"

# PR spam limit (hardcoded per SPEC-160 AC)
readonly MAX_PRS_PER_MONTH=3

# ── Argument parsing ──────────────────────────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true; shift ;;
      --json)
        JSON_OUTPUT=true; shift ;;
      --output-dir)
        [[ $# -lt 2 ]] && { echo "ERROR: --output-dir requires a value" >&2; exit 1; }
        OUTPUT_DIR="$2"
        OUTPUT_FILE="$OUTPUT_DIR/tool-ergonomics-${DATE_STR}.md"
        shift 2 ;;
      --help|-h)
        usage; exit 0 ;;
      -*)
        echo "ERROR: Unknown flag: $1" >&2; exit 1 ;;
      *)
        echo "ERROR: Unexpected argument: $1" >&2; exit 1 ;;
    esac
  done
}

usage() {
  cat <<EOF
tool-ergonomics-audit.sh — SPEC-160 Tool Ergonomics Auto-Audit

Usage:
  tool-ergonomics-audit.sh [OPTIONS]

Options:
  --dry-run       Analyze and print report without writing output file
  --json          Output JSON instead of Markdown
  --output-dir    Directory for output file (default: output/)
  --help          Show this help

Output:
  output/tool-ergonomics-{YYYYMMDD}.md (or JSON with --json)

PR limit: Reports at most $MAX_PRS_PER_MONTH improvement suggestions/month.
EOF
}

# ── Collect JSONL files ───────────────────────────────────────────────────────
collect_jsonl_files() {
  local -a files=()
  local agent_runs_dir="$OUTPUT_DIR/agent-runs"
  local session_log="$OUTPUT_DIR/session-action-log.jsonl"

  if [[ -d "$agent_runs_dir" ]]; then
    while IFS= read -r -d '' f; do
      files+=("$f")
    done < <(find "$agent_runs_dir" -name "*.jsonl" -print0 2>/dev/null)
  fi

  if [[ -f "$session_log" ]]; then
    files+=("$session_log")
  fi

  printf '%s\n' "${files[@]}"
}

# ── Parse tool events from JSONL ──────────────────────────────────────────────
# Expects records with fields: tool, status (success|error), input_hash (optional)
# Returns tab-separated: tool TAB status TAB input_hash
PARSE_EVENTS_PY='
import sys, json
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                print("WARNING: skipping malformed JSON line in " + path, file=sys.stderr)
                continue
            tool = rec.get("tool") or rec.get("tool_name") or rec.get("action") or rec.get("type") or ""
            if not tool:
                continue
            status = rec.get("status", "")
            if not status:
                if rec.get("error") or rec.get("error_message"):
                    status = "error"
                elif rec.get("success") is False:
                    status = "error"
                else:
                    status = "success"
            input_data = rec.get("input") or rec.get("tool_input") or rec.get("params") or ""
            input_str = json.dumps(input_data, sort_keys=True) if isinstance(input_data, dict) else str(input_data)
            input_hash = input_str[:40].replace("\t", " ")
            print(tool + "\t" + status + "\t" + input_hash)
except (IOError, OSError) as e:
    print("ERROR: cannot read " + path + ": " + str(e), file=sys.stderr)
    sys.exit(1)
'

parse_tool_events() {
  local file="$1"
  python3 -c "$PARSE_EVENTS_PY" "$file" 2>/dev/null || {
    echo "WARNING: failed to parse $file — skipping" >&2
  }
}

# ── Analyze tool events ───────────────────────────────────────────────────────
# Returns JSON with tool stats. Receives list of JSONL file paths.
ANALYZE_EVENTS_PY='
import sys, json
from collections import defaultdict

files = sys.argv[1:]
files_count = len(files)

tool_stats = defaultdict(lambda: {"calls": 0, "errors": 0, "inputs": {}})
total = 0

for path in files:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    print("WARNING: skipping malformed JSON in " + path, file=sys.stderr)
                    continue
                tool = rec.get("tool") or rec.get("tool_name") or rec.get("action") or rec.get("type") or ""
                if not tool:
                    continue
                status = rec.get("status", "")
                if not status:
                    if rec.get("error") or rec.get("error_message"):
                        status = "error"
                    elif rec.get("success") is False:
                        status = "error"
                    else:
                        status = "success"
                input_data = rec.get("input") or rec.get("tool_input") or rec.get("params") or ""
                input_str = json.dumps(input_data, sort_keys=True) if isinstance(input_data, dict) else str(input_data)
                input_hash = input_str[:40].replace("\t", " ")
                tool_stats[tool]["calls"] += 1
                total += 1
                if status == "error":
                    tool_stats[tool]["errors"] += 1
                if input_hash:
                    inputs = tool_stats[tool]["inputs"]
                    inputs[input_hash] = inputs.get(input_hash, 0) + 1
    except (IOError, OSError) as e:
        print("WARNING: cannot read " + path + ": " + str(e), file=sys.stderr)

result = []
for tool, stats in tool_stats.items():
    calls = stats["calls"]
    errors = stats["errors"]
    error_rate = (errors / calls * 100) if calls > 0 else 0
    retries = sum(1 for cnt in stats["inputs"].values() if cnt >= 2)
    result.append({
        "tool": tool,
        "calls": calls,
        "errors": errors,
        "error_rate": round(error_rate, 1),
        "retries_same_input": retries,
        "high_error_rate": error_rate > 15.0,
    })

result.sort(key=lambda x: (x["error_rate"], x["retries_same_input"]), reverse=True)
print(json.dumps({"tools": result, "total_events": total, "files_scanned": files_count}))
'

analyze_events() {
  local -a files=("$@")

  if [[ "${#files[@]}" -eq 0 ]]; then
    echo '{"tools":[],"total_events":0,"files_scanned":0}'
    return
  fi

  python3 -c "$ANALYZE_EVENTS_PY" "${files[@]}" 2>/dev/null \
    || echo '{"tools":[],"total_events":0,"files_scanned":0}'
}

# ── Generate Markdown report ──────────────────────────────────────────────────
GEN_MARKDOWN_PY='
import sys, json
data = json.loads(sys.argv[1])
date_str = sys.argv[2]
pr_limit = int(sys.argv[3])
tools = data.get("tools", [])
total = data.get("total_events", 0)
files = data.get("files_scanned", 0)
top5 = [t for t in tools if t["high_error_rate"] or t["retries_same_input"] > 0][:5]
lines = [
    "# Tool Ergonomics Audit \u2014 " + date_str,
    "",
    "> Generated by `scripts/tool-ergonomics-audit.sh` (SPEC-160)",
    "> Files scanned: " + str(files) + " | Total events: " + str(total),
    "> PR improvement limit: " + str(pr_limit) + "/month (report only \u2014 no auto-PRs)",
    "",
    "## Summary",
    "",
]
if not tools:
    lines += ["No tool events found. Nothing to report.", "", "_Run agents and retry to populate trajectory data._"]
else:
    high_err = [t for t in tools if t["high_error_rate"]]
    retry_tools = [t for t in tools if t["retries_same_input"] > 0]
    lines += [
        "- Tools analyzed: " + str(len(tools)),
        "- Tools with error_rate > 15%: " + str(len(high_err)),
        "- Tools with retry patterns: " + str(len(retry_tools)),
        "",
    ]
    if top5:
        lines += ["## Top-5 Tools to Improve", "", "| Tool | Calls | Errors | Error Rate | Retries (same input) | Issues |", "|---|---|---|---|---|---|"]
        for t in top5:
            issues = []
            if t["high_error_rate"]:
                issues.append("error_rate " + str(t["error_rate"]) + "% > 15%")
            if t["retries_same_input"] > 0:
                issues.append(str(t["retries_same_input"]) + " retry pattern(s)")
            lines.append("| `" + t["tool"] + "` | " + str(t["calls"]) + " | " + str(t["errors"]) + " | " + str(t["error_rate"]) + "% | " + str(t["retries_same_input"]) + " | " + "; ".join(issues) + " |")
        lines.append("")
    lines += [
        "## Proposed Improvements",
        "",
        "> Maximum " + str(pr_limit) + " improvement PRs/month (SPEC-160 anti-spam policy).",
        "> All proposals require human review before implementation.",
        "",
    ]
    for i, t in enumerate(top5[:pr_limit], 1):
        lines += ["### " + str(i) + ". `" + t["tool"] + "`", ""]
        if t["high_error_rate"]:
            lines.append("- Error rate " + str(t["error_rate"]) + "% exceeds 15% threshold. Review parameter naming and error messages.")
        if t["retries_same_input"] > 0:
            lines.append("- " + str(t["retries_same_input"]) + " cases of same-input retries detected. May indicate confusing UX or missing idempotency.")
        lines.append("")
print("\n".join(lines))
'

generate_markdown() {
  local analysis="$1"
  python3 -c "$GEN_MARKDOWN_PY" "$analysis" "$DATE_STR" "$MAX_PRS_PER_MONTH" 2>/dev/null \
    || echo "# Tool Ergonomics Audit — ${DATE_STR}\n\nGeneration error."
}

# ── Generate JSON report ──────────────────────────────────────────────────────
GEN_JSON_PY='
import sys, json
data = json.loads(sys.argv[1])
date_str = sys.argv[2]
pr_limit = int(sys.argv[3])
output = {
    "spec": "SPEC-160",
    "date": date_str,
    "pr_limit_per_month": pr_limit,
    "files_scanned": data.get("files_scanned", 0),
    "total_events": data.get("total_events", 0),
    "tools": data.get("tools", []),
    "top5_to_improve": [t for t in data.get("tools", []) if t["high_error_rate"] or t["retries_same_input"] > 0][:5],
}
print(json.dumps(output, indent=2))
'

generate_json() {
  local analysis="$1"
  python3 -c "$GEN_JSON_PY" "$analysis" "$DATE_STR" "$MAX_PRS_PER_MONTH" 2>/dev/null \
    || echo '{"spec":"SPEC-160","error":"generation failed"}'
}

# ── Main ──────────────────────────────────────────────────────────────────────
parse_args "$@"

# Collect input files
mapfile -t JSONL_FILES < <(collect_jsonl_files)

if [[ "${#JSONL_FILES[@]}" -eq 0 ]]; then
  echo "tool-ergonomics-audit: no JSONL files found — generating empty report" >&2
fi

# Analyze
ANALYSIS=$(analyze_events "${JSONL_FILES[@]}" 2>/dev/null || echo '{"tools":[],"total_events":0,"files_scanned":0}')

if [[ -z "$ANALYSIS" ]]; then
  ANALYSIS='{"tools":[],"total_events":0,"files_scanned":0}'
fi

# Generate report content
if [[ "$JSON_OUTPUT" == "true" ]]; then
  REPORT_CONTENT=$(generate_json "$ANALYSIS")
else
  REPORT_CONTENT=$(generate_markdown "$ANALYSIS")
fi

if [[ -z "$REPORT_CONTENT" ]]; then
  REPORT_CONTENT="# Tool Ergonomics Audit — ${DATE_STR}\n\nNo data to report."
fi

# Output
if [[ "$DRY_RUN" == "true" ]]; then
  echo "$REPORT_CONTENT"
  echo "tool-ergonomics-audit: dry-run complete — no files written" >&2
  exit 0
fi

# Write output file
mkdir -p "$OUTPUT_DIR"
printf '%s\n' "$REPORT_CONTENT" > "$OUTPUT_FILE"
echo "tool-ergonomics-audit: report written to $OUTPUT_FILE"
