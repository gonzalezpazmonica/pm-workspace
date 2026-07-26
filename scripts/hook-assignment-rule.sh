#!/usr/bin/env bash
# hook-assignment-rule.sh — SE-270 Slice 5: hook vs documentation assignment rule.
#
# Documents and enforces the rule: "minor annoyance → docs/skill, data loss → hook".
# Can be invoked with --check to validate a new hook proposal.
# Exits 0 always (advisory — never blocks).
#
# Usage:
#   hook-assignment-rule.sh                    # print the rule
#   hook-assignment-rule.sh --check "PROPOSAL" # validate a proposal
#   hook-assignment-rule.sh --json             # structured output
#
# Exit codes:
#   0 — always (advisory rule)
#   2 — usage error
#
# Ref: SE-270 §Slice 5, AC-5.5

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CHECK=""
JSON=0

# Thresholds for classification (heuristic keywords)
HOOK_KEYWORDS="data loss|data leak|corruption|security|credential|secret|pii|production outage|incident|privilege escalation|cve|exploit|breach|unauthorized|bypass|rm -rf|force-push|delete|destroy|irreversible"
DOC_KEYWORDS="style|lint|format|naming|comment|warning|info|hint|suggestion|convention|pattern|guideline|best practice|preference|recommend"

usage() {
  cat <<EOF
Usage: $0 [options]

Documents the hook assignment rule. With --check, validates a proposal
against the rule. Always exits 0 (advisory — does not block).

Options:
  --check "TEXT"  Validate a hook proposal against the assignment rule
  --json          Structured output
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

# ── Rule text ──────────────────────────────────────────────────────────────────
RULE_TEXT="RULE: minor annoyance → docs/skill, data loss → hook

If the consequence of the model ignoring the guardrail is a minor
annoyance (inconsistent naming, missing comment, style violation),
document it — put it in a skill, a guide, or CLAUDE.md.

If the consequence is a production incident or data loss (credential
leak, force-push, rm -rf without validation, PII exposure, infra
destruction), put it in a hook.

Tiebreaker: when in doubt, start as a hook with warn-only mode and
audit after 30 days. If it never fired a true positive, downgrade
to documentation."

# ── Scoring heuristic ──────────────────────────────────────────────────────────
score_proposal() {
  local text="$1"
  local hook_score=0 doc_score=0

  hook_score=$(echo "$text" | { grep -ciE "$HOOK_KEYWORDS" 2>/dev/null || true; } | tr -d '[:space:]')
  hook_score="${hook_score:-0}"

  doc_score=$(echo "$text" | { grep -ciE "$DOC_KEYWORDS" 2>/dev/null || true; } | tr -d '[:space:]')
  doc_score="${doc_score:-0}"

  local boost=0
  boost=$(echo "$text" | { grep -ciE '\b(always|never|must|critical|blocking|fatal|irreversible|permanent)\b' 2>/dev/null || true; } | tr -d '[:space:]')
  boost="${boost:-0}"
  hook_score=$((hook_score + boost))

  local verdict=""
  if [[ "$hook_score" -gt "$doc_score" ]]; then
    verdict="HOOK"
  elif [[ "$doc_score" -gt "$hook_score" ]]; then
    verdict="DOC"
  else
    verdict="UNCERTAIN"
  fi

  echo "${verdict}@${hook_score}@${doc_score}"
}

# ── Output ─────────────────────────────────────────────────────────────────────
if [[ -n "$CHECK" ]]; then
  result=$(score_proposal "$CHECK")
  IFS='@' read -r verdict hs ds <<< "$result"

  if [[ "$JSON" -eq 1 ]]; then
    esc_check=$(echo "$CHECK" | jq -Rsa .)
    cat <<JSON
{
  "proposal": $esc_check,
  "verdict": "$verdict",
  "hook_score": $hs,
  "doc_score": $ds,
  "rule": "minor annoyance → docs/skill, data loss → hook"
}
JSON
  else
    echo "=== Hook Assignment Check ==="
    echo ""
    echo "Proposal: $CHECK"
    echo ""
    echo "Scores: hook=$hs  doc=$ds"
    echo "Verdict: $verdict"
    case "$verdict" in
      HOOK)
        echo ""
        echo "Assignee: HOOK — consequence appears to be a data-loss or security risk."
        echo "Recommendation: implement as PreToolUse command hook with blocking mode."
        ;;
      DOC)
        echo ""
        echo "Assignee: DOC — consequence appears to be a minor annoyance."
        echo "Recommendation: document in a skill or CLAUDE.md."
        ;;
      UNCERTAIN)
        echo ""
        echo "Assignee: UNCERTAIN — tiebreaker needed."
        echo "Recommendation: start as warn-only hook, audit after 30 days. If no true positive, downgrade to documentation."
        ;;
    esac
    echo ""
    echo "Rule: minor annoyance → docs/skill, data loss → hook"
    echo "ALWAYS exit 0 (advisory — does not block)."
  fi
else
  if [[ "$JSON" -eq 1 ]]; then
    esc_rule=$(echo "$RULE_TEXT" | jq -Rsa .)
    cat <<JSON
{
  "rule": $esc_rule,
  "hook_keywords": "$HOOK_KEYWORDS",
  "doc_keywords": "$DOC_KEYWORDS",
  "tiebreaker": "start as hook (warn-only) + audit at 30 days"
}
JSON
  else
    echo "=== SE-270 Slice 5: Hook Assignment Rule ==="
    echo ""
    echo "$RULE_TEXT"
    echo ""
    echo "Always exit 0 — this is an advisory rule."
  fi
fi

exit 0
