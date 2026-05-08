#!/usr/bin/env bash
# workspace-health.sh — Comprehensive health dashboard for pm-workspace
# Aggregates all quality signals into a single health score.
#
# Usage: bash scripts/workspace-health.sh [--summary | --json | --ci]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:---summary}"

# ── Helper functions ──
count_glob() {
  local n=0
  for f in $1; do [ -e "$f" ] && n=$((n + 1)); done
  echo "$n"
}

pct() {
  local num=$1 den=$2
  if [ "$den" -eq 0 ]; then echo 0; return; fi
  echo $(( (num * 100) / den ))
}

grade() {
  local score=$1
  if [ "$score" -ge 90 ]; then echo "A"
  elif [ "$score" -ge 80 ]; then echo "B"
  elif [ "$score" -ge 70 ]; then echo "C"
  elif [ "$score" -ge 60 ]; then echo "D"
  else echo "F"
  fi
}

# ── Gather metrics ──

# 1. Component completeness
TOTAL_SKILLS=$(count_glob "$ROOT/.opencode/skills/*/")
SKILLS_WITH_MD=$(count_glob "$ROOT/.opencode/skills/*/SKILL.md")
SKILL_COMPLETENESS=$(pct "$SKILLS_WITH_MD" "$TOTAL_SKILLS")

TOTAL_COMMANDS=$(count_glob "$ROOT/.opencode/commands/*.md")
CMD_WITH_FM=0
for f in "$ROOT/.opencode/commands/"*.md; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -q "^---$" && CMD_WITH_FM=$((CMD_WITH_FM + 1))
done
CMD_COMPLETENESS=$(pct "$CMD_WITH_FM" "$TOTAL_COMMANDS")

# 2. Maturity distribution
STABLE=$(grep -rl "^maturity: stable" "$ROOT/.opencode/skills/"*/SKILL.md 2>/dev/null | wc -l)
BETA=$(grep -rl "^maturity: beta" "$ROOT/.opencode/skills/"*/SKILL.md 2>/dev/null | wc -l)
ALPHA=$(grep -rl "^maturity: alpha" "$ROOT/.opencode/skills/"*/SKILL.md 2>/dev/null | wc -l)
MATURITY_SCORE=$(pct "$((STABLE * 3 + BETA * 2 + ALPHA * 1))" "$((TOTAL_SKILLS * 3))")

# 3. Test coverage
TOTAL_HOOKS=$(count_glob "$ROOT/.opencode/hooks/*.sh")
TESTED_HOOKS=0
for h in "$ROOT/.opencode/hooks/"*.sh; do
  [ -f "$h" ] || continue
  name=$(basename "$h" .sh)
  ls "$ROOT"/tests/hooks/test-"$name"*.bats 2>/dev/null | grep -q . && TESTED_HOOKS=$((TESTED_HOOKS + 1))
done
TEST_COVERAGE=$(pct "$TESTED_HOOKS" "$TOTAL_HOOKS")

# 4. Security posture
SEC_FINDINGS=0
SEC_OUTPUT=$(bash "$ROOT/scripts/security-scan.sh" --ci 2>&1)
echo "$SEC_OUTPUT" | grep -q "FAIL" && SEC_FINDINGS=1
VULN_FINDINGS=0
VULN_OUTPUT=$(bash "$ROOT/scripts/vuln-scan.sh" --ci 2>&1)
echo "$VULN_OUTPUT" | grep -q "FAIL" && VULN_FINDINGS=1
SECURITY_SCORE=$( [ "$SEC_FINDINGS" -eq 0 ] && [ "$VULN_FINDINGS" -eq 0 ] && echo 100 || echo 50 )

# 5. Documentation
DOCS_REQUIRED=("LICENSE" "README.md" "CHANGELOG.md" "CONTRIBUTING.md" "SECURITY.md" "docs/QUICK-START.md" "docs/ROADMAP.md")
DOCS_PRESENT=0
for d in "${DOCS_REQUIRED[@]}"; do
  [ -f "$ROOT/$d" ] && DOCS_PRESENT=$((DOCS_PRESENT + 1))
done
DOC_SCORE=$(pct "$DOCS_PRESENT" "${#DOCS_REQUIRED[@]}")

# 6. CI coverage
CI_FILES=$(count_glob "$ROOT/.github/workflows/*.yml")
CI_SCORE=$( [ "$CI_FILES" -ge 1 ] && echo 100 || echo 0 )

# ── Calculate overall health ──
# Weighted average: skills 20%, commands 15%, maturity 15%, tests 20%, security 20%, docs 10%
OVERALL=$(( (SKILL_COMPLETENESS * 20 + CMD_COMPLETENESS * 15 + MATURITY_SCORE * 15 + TEST_COVERAGE * 20 + SECURITY_SCORE * 20 + DOC_SCORE * 10) / 100 ))

# ── Output ──
if [ "$MODE" = "--json" ]; then
  cat <<JSON
{
  "generated": "$(date -Iseconds)",
  "overall": { "score": $OVERALL, "grade": "$(grade $OVERALL)" },
  "dimensions": {
    "skill_completeness": { "score": $SKILL_COMPLETENESS, "detail": "$SKILLS_WITH_MD/$TOTAL_SKILLS skills have SKILL.md" },
    "command_completeness": { "score": $CMD_COMPLETENESS, "detail": "$CMD_WITH_FM/$TOTAL_COMMANDS commands have frontmatter" },
    "maturity": { "score": $MATURITY_SCORE, "stable": $STABLE, "beta": $BETA, "alpha": $ALPHA },
    "test_coverage": { "score": $TEST_COVERAGE, "tested": $TESTED_HOOKS, "total": $TOTAL_HOOKS },
    "security": { "score": $SECURITY_SCORE, "findings": $SEC_FINDINGS, "vulns": $VULN_FINDINGS },
    "documentation": { "score": $DOC_SCORE, "present": $DOCS_PRESENT, "required": ${#DOCS_REQUIRED[@]} }
  }
}
JSON

elif [ "$MODE" = "--ci" ]; then
  echo "Workspace Health: $OVERALL% ($(grade $OVERALL))"
  if [ "$OVERALL" -lt 60 ]; then
    echo "FAIL: Health score below 60%"
    exit 1
  fi
  echo "PASS: Health score $OVERALL% >= 60%"

else
  echo "═══════════════════════════════════════════════════"
  echo "  🏥 Workspace Health Dashboard — pm-workspace"
  echo "═══════════════════════════════════════════════════"
  echo ""
  echo "  Overall Health: $OVERALL% ($(grade $OVERALL))"
  echo ""
  echo "  ┌──────────────────────────┬───────┬───────┐"
  echo "  │ Dimension                │ Score │ Grade │"
  echo "  ├──────────────────────────┼───────┼───────┤"
  printf "  │ %-24s │ %4d%% │   %s   │\n" "Skill completeness" "$SKILL_COMPLETENESS" "$(grade $SKILL_COMPLETENESS)"
  printf "  │ %-24s │ %4d%% │   %s   │\n" "Command completeness" "$CMD_COMPLETENESS" "$(grade $CMD_COMPLETENESS)"
  printf "  │ %-24s │ %4d%% │   %s   │\n" "Maturity distribution" "$MATURITY_SCORE" "$(grade $MATURITY_SCORE)"
  printf "  │ %-24s │ %4d%% │   %s   │\n" "Test coverage" "$TEST_COVERAGE" "$(grade $TEST_COVERAGE)"
  printf "  │ %-24s │ %4d%% │   %s   │\n" "Security posture" "$SECURITY_SCORE" "$(grade $SECURITY_SCORE)"
  printf "  │ %-24s │ %4d%% │   %s   │\n" "Documentation" "$DOC_SCORE" "$(grade $DOC_SCORE)"
  echo "  └──────────────────────────┴───────┴───────┘"
  echo ""
  echo "  Components: $TOTAL_COMMANDS commands, $TOTAL_SKILLS skills,"
  echo "              $(count_glob "$ROOT/.opencode/agents/*.md") agents, $TOTAL_HOOKS hooks"
  echo ""
  echo "═══════════════════════════════════════════════════"
fi
