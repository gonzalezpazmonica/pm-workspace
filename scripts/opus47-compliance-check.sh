#!/usr/bin/env bash
# opus47-compliance-check.sh — Verifies Savia compliance with Opus 4.7 migration batches.
#
# Scope: SE-066 (finding vs filtering), SE-067 (fan-out + adaptive),
# SE-068 (XML tags), SE-069 (context-rot skill), SE-070 (scorecard scaffold).
#
# Usage:
#   opus47-compliance-check.sh                       # run all checks
#   opus47-compliance-check.sh --finding-vs-filtering
#   opus47-compliance-check.sh --fan-out
#   opus47-compliance-check.sh --adaptive-thinking
#   opus47-compliance-check.sh --xml-tags
#   opus47-compliance-check.sh --context-rot-skill
#   opus47-compliance-check.sh --json
#
# Exit codes:
#   0 — PASS
#   1 — FAIL (drift detected)
#   2 — usage error
#
# Ref: docs/propuestas/SE-066..SE-070

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$PROJECT_ROOT/.claude/agents"
SKILLS_DIR="$PROJECT_ROOT/.claude/skills"

JSON=0
FLAGS=()

REVIEW_AGENTS=(
  code-reviewer pr-agent-judge security-judge correctness-judge spec-judge
  cognitive-judge architecture-judge calibration-judge coherence-judge
  completeness-judge compliance-judge factuality-judge hallucination-judge
  source-traceability-judge security-auditor confidentiality-auditor
  drift-auditor court-orchestrator truth-tribunal-orchestrator
)

ORCHESTRATORS=(dev-orchestrator court-orchestrator truth-tribunal-orchestrator)

XML_AGENTS=(architect dev-orchestrator court-orchestrator truth-tribunal-orchestrator code-reviewer)

usage() {
  cat <<EOF
Usage: $0 [flags]
Flags:
  --finding-vs-filtering   Check 19 review agents have SE-066 Reporting Policy
  --fan-out                Check 3 orchestrators have SE-067 Subagent Fan-Out Policy
  --adaptive-thinking      Check feasibility-probe migrated from budget_tokens
  --xml-tags               Check 5 top-tier agents have SE-068 XML tags
  --context-rot-skill      Check SE-069 skill exists
  --json                   JSON output
  (no flag)                Run all checks
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --finding-vs-filtering|--fan-out|--adaptive-thinking|--xml-tags|--context-rot-skill) FLAGS+=("$1"); shift ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown flag '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

# Default to all checks
[[ ${#FLAGS[@]} -eq 0 ]] && FLAGS=(--finding-vs-filtering --fan-out --adaptive-thinking --xml-tags --context-rot-skill)

FAILURES=()
add_fail() { FAILURES+=("$1"); }

check_finding_vs_filtering() {
  for a in "${REVIEW_AGENTS[@]}"; do
    f="$AGENTS_DIR/$a.md"
    [[ ! -f "$f" ]] && { add_fail "SE-066: missing agent $a"; continue; }
    grep -q "SE-066" "$f" || add_fail "SE-066: $a missing Reporting Policy block"
  done
}

check_fan_out() {
  for a in "${ORCHESTRATORS[@]}"; do
    f="$AGENTS_DIR/$a.md"
    [[ ! -f "$f" ]] && { add_fail "SE-067: missing orchestrator $a"; continue; }
    grep -q "SE-067" "$f" || add_fail "SE-067: $a missing Subagent Fan-Out Policy block"
  done
}

check_adaptive_thinking() {
  f="$SKILLS_DIR/feasibility-probe/SKILL.md"
  [[ ! -f "$f" ]] && { add_fail "SE-067: feasibility-probe SKILL.md missing"; return; }
  if grep -qE '^\| budget_tokens' "$f"; then
    add_fail "SE-067: feasibility-probe still declares fixed budget_tokens parameter"
  fi
  grep -q "SE-067" "$f" || add_fail "SE-067: feasibility-probe missing migration reference"
}

check_xml_tags() {
  local required_tags=("<instructions>" "<context_usage>" "<constraints>" "<output_format>")
  for a in "${XML_AGENTS[@]}"; do
    f="$AGENTS_DIR/$a.md"
    [[ ! -f "$f" ]] && { add_fail "SE-068: missing agent $a"; continue; }
    grep -q "SE-068" "$f" || { add_fail "SE-068: $a missing SE-068 tag marker"; continue; }
    local missing=""
    for tag in "${required_tags[@]}"; do
      grep -qF "$tag" "$f" || missing="$missing $tag"
    done
    [[ -n "$missing" ]] && add_fail "SE-068: $a missing tags:$missing"
  done
}

check_context_rot_skill() {
  local d="$SKILLS_DIR/context-rot-strategy"
  [[ ! -d "$d" ]] && { add_fail "SE-069: context-rot-strategy skill dir missing"; return; }
  [[ ! -f "$d/SKILL.md" ]] && add_fail "SE-069: SKILL.md missing"
  [[ ! -f "$d/DOMAIN.md" ]] && add_fail "SE-069: DOMAIN.md missing"
  [[ -f "$d/SKILL.md" ]] && ! grep -q "5 opciones" "$d/SKILL.md" && add_fail "SE-069: SKILL.md missing 5-option model"
}

for flag in "${FLAGS[@]}"; do
  case "$flag" in
    --finding-vs-filtering) check_finding_vs_filtering ;;
    --fan-out) check_fan_out ;;
    --adaptive-thinking) check_adaptive_thinking ;;
    --xml-tags) check_xml_tags ;;
    --context-rot-skill) check_context_rot_skill ;;
  esac
done

EXIT=0
[[ ${#FAILURES[@]} -gt 0 ]] && EXIT=1

if [[ "$JSON" -eq 1 ]]; then
  printf '{"verdict":"%s","failures_count":%d,"failures":[' "$([ $EXIT -eq 0 ] && echo PASS || echo FAIL)" "${#FAILURES[@]}"
  local_sep=""
  for msg in "${FAILURES[@]}"; do
    esc=$(echo "$msg" | sed 's/"/\\"/g')
    printf '%s"%s"' "$local_sep" "$esc"
    local_sep=","
  done
  printf ']}\n'
else
  echo "=== Opus 4.7 Compliance Check (SE-066..SE-070) ==="
  echo ""
  echo "Flags checked: ${FLAGS[*]}"
  echo "Failures:      ${#FAILURES[@]}"
  echo ""
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    for msg in "${FAILURES[@]}"; do
      echo "  FAIL: $msg"
    done
    echo ""
  fi
  echo "VERDICT: $([ $EXIT -eq 0 ] && echo PASS || echo FAIL)"
fi

exit $EXIT
