#!/usr/bin/env bash
# truth-tribunal.sh — Orchestrate 7-judge reliability evaluation of reports.
# SPEC-106 Phase 1 MVP: structural scaffolding + aggregation logic.
#
# Judge invocation is delegated to truth-tribunal-orchestrator agent (Task).
# This script provides:
#   - detection of report_type from path
#   - detection of destination_tier from path
#   - weight lookup by report_type
#   - aggregation of per-judge YAML outputs into .truth.crc
#   - verdict computation (PUBLISHABLE / CONDITIONAL / ITERATE / ESCALATE)
#   - cache lookup by SHA256 (24h TTL)
#
# Usage:
#   truth-tribunal.sh detect-type <report-path>
#   truth-tribunal.sh detect-tier <report-path>
#   truth-tribunal.sh weights <report-type>
#   truth-tribunal.sh aggregate <report-path> <judges-yaml-dir>
#   truth-tribunal.sh verdict <report-path>
#   truth-tribunal.sh cache-check <report-path>
#   truth-tribunal.sh cache-store <report-path> <verdict>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEIGHTS_FILE="$ROOT/.claude/rules/domain/truth-tribunal-weights.md"
CACHE_DIR="${TRUTH_TRIBUNAL_CACHE:-$HOME/.savia/truth-tribunal/cache}"
CACHE_TTL_SEC="${TRUTH_TRIBUNAL_CACHE_TTL:-86400}"

mkdir -p "$CACHE_DIR" 2>/dev/null || true

# ── Detect report type from path or frontmatter ────────────────────────────
detect_type() {
  local path="$1"
  [[ ! -f "$path" ]] && { echo "default"; return; }

  # 1. Frontmatter override
  local fm_type
  fm_type=$(awk '/^---$/{c++;next} c==1 && /^report_type[[:space:]]*:/ {gsub(/^.*:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$path")
  [[ -n "$fm_type" ]] && { echo "$fm_type"; return; }

  # 2. Heuristic from filename
  local base
  base=$(basename "$path")
  case "$base" in
    ceo-report*|stakeholder-report*|report-executive*|executive-report*) echo "executive" ;;
    compliance-*|governance-*|aepd-*|legal-audit*|legal-compliance*) echo "compliance" ;;
    project-audit*|security-review*|drift-check*|arch-health*|governance-audit*|*-audit-*) echo "audit" ;;
    *-digest*|meeting-digest*|pdf-digest*|word-digest*|excel-digest*|pptx-digest*) echo "digest" ;;
    sprint-retro*|team-sentiment*|burnout-radar*|wellbeing-*) echo "subjective" ;;
    *) echo "default" ;;
  esac
}

# ── Detect destination tier from path ──────────────────────────────────────
detect_tier() {
  local path="$1"
  case "$path" in
    */projects/*)            echo "N4" ;;
    */projects/team-*)       echo "N4b" ;;
    *private-agent-memory*)  echo "N2" ;;
    */output/*)              echo "N1" ;;  # output/ is tracked in public repo
    *.local.*|*config.local*|*CLAUDE.local*) echo "N2" ;;
    *)                       echo "N1" ;;  # default to strictest
  esac
}

# ── Weight lookup: prints 7 numbers (factuality src_trace halluc coh cal comp compliance) ──
weights() {
  local type="${1:-default}"
  # Hardcoded weights synced with truth-tribunal-weights.md
  case "$type" in
    executive)  echo "0.25 0.05 0.15 0.10 0.15 0.25 0.05" ;;
    compliance) echo "0.25 0.15 0.15 0.05 0.05 0.05 0.30" ;;
    audit)      echo "0.30 0.25 0.10 0.10 0.05 0.15 0.05" ;;
    digest)     echo "0.25 0.20 0.25 0.03 0.02 0.15 0.10" ;;
    subjective) echo "0.05 0.05 0.10 0.20 0.30 0.15 0.15" ;;
    default|*)  echo "0.20 0.15 0.20 0.10 0.10 0.10 0.15" ;;
  esac
}

# ── SHA256 of a report (stable identifier for cache) ──────────────────────
report_hash() {
  local path="$1"
  [[ ! -f "$path" ]] && { echo "none"; return; }
  sha256sum "$path" | awk '{print $1}'
}

# ── Cache lookup: prints verdict if fresh, else empty ─────────────────────
cache_check() {
  local path="$1"
  local hash
  hash=$(report_hash "$path")
  local cache_file="$CACHE_DIR/$hash.truth.crc"
  [[ ! -f "$cache_file" ]] && return 1

  local age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null) ))
  [[ $age -gt $CACHE_TTL_SEC ]] && return 1
  cat "$cache_file"
}

cache_store() {
  local path="$1" verdict_file="$2"
  local hash
  hash=$(report_hash "$path")
  [[ "$hash" == "none" ]] && return 1
  cp "$verdict_file" "$CACHE_DIR/$hash.truth.crc"
}

# ── Aggregate 7 per-judge YAML outputs into a single .truth.crc ───────────
# Input: directory with factuality.yaml, source-traceability.yaml, etc.
# Computes weighted score and final verdict.
aggregate() {
  local report_path="$1"
  local judges_dir="$2"
  [[ ! -d "$judges_dir" ]] && { echo "ERROR: judges dir not found: $judges_dir" >&2; return 1; }

  local type tier
  type=$(detect_type "$report_path")
  tier=$(detect_tier "$report_path")

  # Read scores from each judge
  local -A scores
  local -A verdicts
  local -A confidence
  local vetos=""
  local abstentions=0

  for judge in factuality source-traceability hallucination coherence calibration completeness compliance; do
    local file="$judges_dir/$judge.yaml"
    if [[ ! -f "$file" ]]; then
      abstentions=$((abstentions + 1))
      scores[$judge]=0
      verdicts[$judge]="missing"
      continue
    fi
    scores[$judge]=$(awk '/^score:[[:space:]]*[0-9]/ {gsub(/^.*:[[:space:]]*/,""); print; exit}' "$file")
    verdicts[$judge]=$(awk '/^verdict:[[:space:]]*/ {gsub(/^.*:[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$file")
    confidence[$judge]=$(awk '/^confidence:[[:space:]]*/ {gsub(/^.*:[[:space:]]*/,""); print; exit}' "$file")
    [[ "${verdicts[$judge]}" == "abstain" ]] && abstentions=$((abstentions + 1))
    if grep -qE '^(veto|VETO):\s*(true|yes)' "$file"; then
      vetos+="${judge}:$(awk '/^veto_reason:/{gsub(/^.*:[[:space:]]*/,""); print; exit}' "$file")\n"
    fi
  done

  # Compute weighted score
  read -r w_f w_s w_h w_coh w_cal w_cmp w_comp <<< "$(weights "$type")"
  local weighted
  weighted=$(python3 -c "
print(round(
  ${scores[factuality]:-0} * $w_f +
  ${scores[source-traceability]:-0} * $w_s +
  ${scores[hallucination]:-0} * $w_h +
  ${scores[coherence]:-0} * $w_coh +
  ${scores[calibration]:-0} * $w_cal +
  ${scores[completeness]:-0} * $w_cmp +
  ${scores[compliance]:-0} * $w_comp,
  1))
")

  # Determine verdict
  local final_verdict
  if [[ $abstentions -ge 4 ]]; then
    final_verdict="NOT_EVALUABLE"
  elif [[ -n "$vetos" ]]; then
    final_verdict="ITERATE"
  elif (( $(echo "$weighted >= 90" | bc -l 2>/dev/null || echo 0) )); then
    final_verdict="PUBLISHABLE"
  elif (( $(echo "$weighted >= 70" | bc -l 2>/dev/null || echo 0) )); then
    final_verdict="CONDITIONAL"
  else
    final_verdict="ITERATE"
  fi

  # Compliance gate (override) for compliance/audit
  if [[ "$type" == "compliance" || "$type" == "audit" ]]; then
    local cs="${scores[compliance]:-0}"
    if (( $(echo "$cs < 95" | bc -l 2>/dev/null || echo 0) )); then
      final_verdict="ITERATE"
    fi
  fi

  # Emit .truth.crc
  local crc_file="${report_path}.truth.crc"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  {
    echo "---"
    echo "tribunal_id: TT-$(date -u +%Y%m%d-%H%M%S)"
    echo "report_path: $report_path"
    echo "report_type: $type"
    echo "destination_tier: $tier"
    echo "reviewed_at: $ts"
    echo "weighted_score: $weighted"
    echo "verdict: $final_verdict"
    echo "abstentions: $abstentions"
    echo "vetos:"
    if [[ -n "$vetos" ]]; then
      echo -e "$vetos" | sed '/^$/d; s/^/  - /'
    else
      echo "  []"
    fi
    echo "judges:"
    for judge in factuality source-traceability hallucination coherence calibration completeness compliance; do
      local name="${judge//-/_}"
      echo "  ${name}:"
      echo "    score: ${scores[$judge]:-0}"
      echo "    verdict: ${verdicts[$judge]:-missing}"
      echo "    confidence: ${confidence[$judge]:-0}"
    done
    echo "---"
  } > "$crc_file"

  echo "$crc_file"
  [[ "$final_verdict" == "PUBLISHABLE" ]] && return 0
  return 1
}

verdict_of() {
  local crc_file="${1}.truth.crc"
  [[ -f "$crc_file" ]] || { echo "no-verdict"; return 1; }
  awk '/^verdict:/ {gsub(/^.*:[[:space:]]*/,""); print; exit}' "$crc_file"
}

usage() {
  cat <<EOF
truth-tribunal.sh — SPEC-106 Phase 1 orchestration helper

Usage:
  truth-tribunal.sh detect-type <report-path>       → executive|compliance|audit|digest|subjective|default
  truth-tribunal.sh detect-tier <report-path>       → N1|N2|N3|N4|N4b
  truth-tribunal.sh weights <report-type>           → 7 space-separated weights
  truth-tribunal.sh aggregate <report> <judges-dir> → writes .truth.crc, exits 0 if PUBLISHABLE
  truth-tribunal.sh verdict <report>                → reads .truth.crc
  truth-tribunal.sh cache-check <report>            → prints cached .truth.crc if fresh
  truth-tribunal.sh cache-store <report> <crc-file> → stores verdict in cache
EOF
}

case "${1:-}" in
  detect-type) shift; detect_type "$@" ;;
  detect-tier) shift; detect_tier "$@" ;;
  weights)     shift; weights "$@" ;;
  aggregate)   shift; aggregate "$@" ;;
  verdict)     shift; verdict_of "$@" ;;
  cache-check) shift; cache_check "$@" ;;
  cache-store) shift; cache_store "$@" ;;
  help|-h|--help|"") usage ;;
  *) echo "Unknown subcommand: $1" >&2; usage >&2; exit 2 ;;
esac
