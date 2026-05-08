#!/usr/bin/env bash
set -uo pipefail
# skill-detect.sh — SE-030: Skill Self-Improvement Pipeline
#
# Detects repeated patterns in skill invocations, proposes new skills,
# and suggests refinements to existing ones. All proposals require
# human approval (Rule #5: the human decides).
#
# Usage:
#   bash scripts/skill-detect.sh scan     # Detect repeated patterns
#   bash scripts/skill-detect.sh propose  # Generate skill scaffold from top pattern
#   bash scripts/skill-detect.sh refine   # Suggest improvements to existing skills
#   bash scripts/skill-detect.sh status   # Show pending proposals

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INVOCATIONS_LOG="${INVOCATIONS_LOG:-$REPO_ROOT/data/skill-invocations.jsonl}"
PROPOSALS_DIR="${PROPOSALS_DIR:-$REPO_ROOT/output/skill-proposals}"
REFINEMENTS_LOG="$REPO_ROOT/data/skill-refinements.jsonl"
SKILLS_DIR="$REPO_ROOT/.claude/skills"
MIN_REPETITIONS=3
MIN_CONFIDENCE=50
TODAY=$(date +%Y-%m-%d)

log() { echo "[skill-detect] $*" >&2; }

# ── Scan: detect repeated command sequences ──────────────────────────────────

cmd_scan() {
  if [[ ! -f "$INVOCATIONS_LOG" ]]; then
    echo "No invocation data found at $INVOCATIONS_LOG"
    echo "Skills must be used first. Data is logged by skill-feedback-log.sh."
    return 0
  fi

  local line_count
  line_count=$(wc -l < "$INVOCATIONS_LOG" 2>/dev/null || echo 0)
  if (( line_count < MIN_REPETITIONS )); then
    echo "Insufficient data ($line_count invocations, need $MIN_REPETITIONS+)"
    return 0
  fi

  mkdir -p "$PROPOSALS_DIR"

  echo "Skill Pattern Scan"
  echo "━━━━━━━━━━━━━━━━━━"
  echo "Invocations analyzed: $line_count"
  echo ""

  # Pattern 1: Skills invoked together (co-occurrence)
  echo "## Co-occurring Skills (always used together)"
  local co_patterns=0

  # Extract skill names, find pairs that appear in close succession
  local skills_list
  skills_list=$(grep -oP '"skill"\s*:\s*"[^"]*"' "$INVOCATIONS_LOG" 2>/dev/null | sed 's/"skill"\s*:\s*"//;s/"//' | sort | uniq -c | sort -rn | head -20)

  if [[ -n "$skills_list" ]]; then
    echo "$skills_list" | while read -r count skill; do
      if (( count >= MIN_REPETITIONS )); then
        echo "  $skill: ${count}x invocations"
        (( co_patterns++ )) || true
      fi
    done
  fi

  # Pattern 2: Skills with high failure rate (candidates for refinement)
  echo ""
  echo "## Skills with High Failure Rate (refinement candidates)"
  grep -oP '"skill"\s*:\s*"[^"]*".*"outcome"\s*:\s*"[^"]*"' "$INVOCATIONS_LOG" 2>/dev/null | \
    sed 's/"skill"\s*:\s*"//;s/".*"outcome"\s*:\s*"/|/;s/"//' | \
    awk -F'|' '{
      total[$1]++;
      if ($2 == "failure") fail[$1]++
    }
    END {
      for (s in total) {
        if (total[s] >= 3) {
          rate = (fail[s]+0) / total[s] * 100;
          if (rate >= 30) printf "  %s: %.0f%% failure (%d/%d)\n", s, rate, fail[s]+0, total[s]
        }
      }
    }' | sort -t':' -k2 -rn

  # Pattern 3: Command sequences not covered by any skill
  echo ""
  echo "## Unmatched NL Patterns (no skill coverage)"
  if [[ -f "$REPO_ROOT/data/confidence-log.jsonl" ]]; then
    local low_confidence
    low_confidence=$(grep -c '"band":"low"' "$REPO_ROOT/data/confidence-log.jsonl" 2>/dev/null || echo 0)
    echo "  Low-confidence NL resolutions: $low_confidence"
  else
    echo "  No confidence log found."
  fi

  # Save scan results
  local scan_file="$PROPOSALS_DIR/${TODAY}-scan.json"
  {
    echo "{"
    echo "  \"date\": \"$TODAY\","
    echo "  \"invocations_analyzed\": $line_count,"
    echo "  \"min_repetitions\": $MIN_REPETITIONS"
    echo "}"
  } > "$scan_file"

  echo ""
  echo "Scan saved: $scan_file"
}

# ── Propose: generate skill scaffold ─────────────────────────────────────────

cmd_propose() {
  local name="${1:-}"
  local description="${2:-}"
  local domain="${3:-pm-operations}"

  if [[ -z "$name" ]]; then
    echo "Usage: skill-detect.sh propose <name> [description] [domain]" >&2
    echo "  Generates SKILL.md + DOMAIN.md scaffold for a new skill." >&2
    echo "  Name must be kebab-case." >&2
    return 1
  fi

  # Validate kebab-case
  if ! echo "$name" | grep -qE '^[a-z][a-z0-9-]+$'; then
    echo "Error: name must be kebab-case (e.g., my-new-skill)" >&2
    return 1
  fi

  mkdir -p "$PROPOSALS_DIR/$name"

  # Generate SKILL.md
  cat > "$PROPOSALS_DIR/$name/SKILL.md" <<SKILL
---
name: $name
description: "${description:-Auto-detected skill pending review}"
category: $domain
maturity: experimental
confidence: $MIN_CONFIDENCE
auto_detected: true
detected_date: $TODAY
---

# $name

> Auto-proposed by SE-030 Skill Self-Improvement Pipeline.
> Status: PENDING REVIEW — requires PM approval before activation.

## What it does

${description:-Describe the workflow this skill automates.}

## When to use

Detected pattern: this sequence of actions was repeated $MIN_REPETITIONS+ times.

## Flow

1. Step 1
2. Step 2
3. Step 3

## Example

\`\`\`
/$name
\`\`\`
SKILL

  # Generate DOMAIN.md (Clara Philosophy)
  cat > "$PROPOSALS_DIR/$name/DOMAIN.md" <<DOMAIN
---
name: $name
type: domain
---

## Por que existe esta skill

Patron detectado automaticamente por el pipeline SE-030.
Requiere validacion humana antes de activarse.

## Conceptos de dominio

- **Patron detectado**: secuencia de acciones repetida
- **Confianza**: ${MIN_CONFIDENCE}% (experimental)
- **Fuente**: skill-invocations.jsonl

## Relacion con otras skills

- **Upstream**: deteccion automatica via skill-detect.sh
- **Downstream**: pendiente de definir tras aprobacion

## Decisiones clave

- Auto-propuesta, no auto-activada (Rule #5)
- Confianza inicial conservadora (${MIN_CONFIDENCE}%)
DOMAIN

  # Check line counts
  local skill_lines domain_lines
  skill_lines=$(wc -l < "$PROPOSALS_DIR/$name/SKILL.md")
  domain_lines=$(wc -l < "$PROPOSALS_DIR/$name/DOMAIN.md")

  log "Proposal generated: $PROPOSALS_DIR/$name/"
  echo "Skill proposal created:"
  echo "  SKILL.md:  $skill_lines lines"
  echo "  DOMAIN.md: $domain_lines lines"
  echo "  Confidence: ${MIN_CONFIDENCE}%"
  echo "  Maturity: experimental"
  echo ""
  echo "Review and approve: move to .opencode/skills/$name/ to activate."
}

# ── Refine: suggest improvements to existing skills ──────────────────────────

cmd_refine() {
  if [[ ! -f "$INVOCATIONS_LOG" ]]; then
    echo "No invocation data — nothing to refine."
    return 0
  fi

  echo "Skill Refinement Suggestions"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local suggestions=0

  # Find skills with declining success rate
  grep -oP '"skill"\s*:\s*"[^"]*".*"outcome"\s*:\s*"[^"]*"' "$INVOCATIONS_LOG" 2>/dev/null | \
    sed 's/"skill"\s*:\s*"//;s/".*"outcome"\s*:\s*"/|/;s/"//' | \
    awk -F'|' '{
      total[$1]++;
      if ($2 == "failure") fail[$1]++
    }
    END {
      for (s in total) {
        if (total[s] >= 5) {
          rate = (fail[s]+0) / total[s] * 100;
          if (rate >= 20) printf "%s|%.0f|%d|%d\n", s, rate, fail[s]+0, total[s]
        }
      }
    }' | sort -t'|' -k2 -rn | while IFS='|' read -r skill fail_rate fails total; do
      echo "  $skill: ${fail_rate}% failure rate ($fails/$total)"
      echo "    Suggestion: review SKILL.md flow, check if pattern changed"
      echo ""
      (( suggestions++ )) || true

      # Log refinement suggestion
      if [[ -n "$skill" ]]; then
        printf '{"date":"%s","skill":"%s","failure_rate":%s,"total":%s,"suggestion":"review_flow"}\n' \
          "$TODAY" "$skill" "$fail_rate" "$total" >> "$REFINEMENTS_LOG"
      fi
    done

  echo "Total suggestions: $suggestions"
}

# ── Status: show pending proposals ───────────────────────────────────────────

cmd_status() {
  local proposal_count=0
  local scan_count=0

  if [[ -d "$PROPOSALS_DIR" ]]; then
    proposal_count=$(find "$PROPOSALS_DIR" -name "SKILL.md" 2>/dev/null | wc -l)
    scan_count=$(find "$PROPOSALS_DIR" -name "*-scan.json" 2>/dev/null | wc -l)
  fi

  local invocation_count=0
  [[ -f "$INVOCATIONS_LOG" ]] && invocation_count=$(wc -l < "$INVOCATIONS_LOG" 2>/dev/null || echo 0)

  local active_skills=0
  [[ -d "$SKILLS_DIR" ]] && active_skills=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)

  cat <<EOS
Skill Self-Improvement Status (SE-030)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Active skills:       $active_skills
Invocations logged:  $invocation_count
Pending proposals:   $proposal_count
Scans completed:     $scan_count
Proposals dir:       $PROPOSALS_DIR
EOS
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "${1:-status}" in
  scan)    cmd_scan ;;
  propose) shift; cmd_propose "$@" ;;
  refine)  cmd_refine ;;
  status)  cmd_status ;;
  *)       echo "Usage: skill-detect.sh {scan|propose|refine|status}" >&2; exit 1 ;;
esac
