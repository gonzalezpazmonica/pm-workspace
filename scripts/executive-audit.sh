#!/usr/bin/env bash
# executive-audit.sh — Executive Audit for PM Workspace
# Evaluates reliability, trustworthiness, and maturity for leadership review
# Usage: bash scripts/executive-audit.sh [--json | --markdown | --ci]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:---json}"
AUDIT_DATE="$(date -u +'%Y-%m-%d')"

count_glob() { local n=0; for f in $1; do [ -e "$f" ] && n=$((n + 1)); done; echo "$n"; }
pct() { [ "$2" -eq 0 ] && echo 0 || echo $(( ($1 * 100) / $2 )); }
get_version() { head -20 "$ROOT/CHANGELOG.md" | grep "^## \[" | head -1 | sed 's/.*\[\(.*\)\].*/\1/'; }

# Gather Metrics
SKILLS_COUNT=$(count_glob "$ROOT/.claude/skills/*/SKILL.md")
COMMANDS_COUNT=$(count_glob "$ROOT/.claude/commands/*.md")
AGENTS_COUNT=$(count_glob "$ROOT/.claude/agents/*.md")
HOOKS_COUNT=$(count_glob "$ROOT/.claude/hooks/*.sh")
RULES_COUNT=$(find "$ROOT/.claude/rules" -name "*.md" -type f 2>/dev/null | wc -l)
DOCS_COUNT=$(find "$ROOT/docs" -name "*.md" -type f 2>/dev/null | wc -l)
TESTS_BATS=$(find "$ROOT/tests" -name "*.bats" -type f 2>/dev/null | wc -l)
TESTS_SCRIPTS=$(find "$ROOT/scripts" -name "test-*.sh" -type f 2>/dev/null | wc -l)
SH_LINES=$(find "$ROOT/scripts" -name "*.sh" -type f -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')

HEALTH_SCORE=$(bash "$ROOT/scripts/workspace-health.sh" --json 2>/dev/null | grep -o '"score": *[0-9]*' | head -1 | grep -o '[0-9]*' || echo 0)
COVERAGE_PCT=$(bash "$ROOT/scripts/coverage-report.sh" --ci 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%' || echo 0)
BATS_COUNT=$(grep -r "^@test" "$ROOT/tests" 2>/dev/null | wc -l)

SEC_FINDINGS=$(bash "$ROOT/scripts/security-scan.sh" 2>/dev/null | grep -oE '[0-9]+ findings' | grep -o '[0-9]*' || echo 0)
VULN_FINDINGS=$(bash "$ROOT/scripts/vuln-scan.sh" 2>/dev/null | grep -oE '[0-9]+ vulnerabilit' | grep -o '[0-9]*' || echo 0)

HOOKS_SAFE=0
for h in "$ROOT/.claude/hooks"/*.sh; do
  [ -f "$h" ] || continue
  head -10 "$h" | grep -q "set -uo pipefail" && HOOKS_SAFE=$((HOOKS_SAFE + 1))
done
CRED_HOOKS=$(find "$ROOT/.claude/hooks" -name "*pii*" -o -name "*credential*" -o -name "*secret*" 2>/dev/null | wc -l)

STABLE=$(grep -rl "^maturity: stable" "$ROOT/.claude/skills"/*/SKILL.md 2>/dev/null | wc -l)
BETA=$(grep -rl "^maturity: beta" "$ROOT/.claude/skills"/*/SKILL.md 2>/dev/null | wc -l)
ALPHA=$(grep -rl "^maturity: alpha" "$ROOT/.claude/skills"/*/SKILL.md 2>/dev/null | wc -l)
MATURITY_PCT=$([ "$SKILLS_COUNT" -gt 0 ] && [ "$STABLE" -gt 0 ] && echo $(( (STABLE * 100) / SKILLS_COUNT )) || echo 0)

CI_JOBS=0
if [ -f "$ROOT/.github/workflows/ci.yml" ]; then
  CI_JOBS=$(grep -c "^\s*- name:" "$ROOT/.github/workflows/ci.yml" 2>/dev/null)
  [ -z "$CI_JOBS" ] && CI_JOBS=0
fi

REQUIRED_DOCS=("LICENSE" "README.md" "CHANGELOG.md" "CONTRIBUTING.md" "SECURITY.md")
DOCS_PRESENT=0
for d in "${REQUIRED_DOCS[@]}"; do [ -f "$ROOT/$d" ] && DOCS_PRESENT=$((DOCS_PRESENT + 1)); done
CHANGELOG_ENTRIES=$(grep -c "^## \[" "$ROOT/CHANGELOG.md" 2>/dev/null || echo 0)

# Calculate Trust Score
HEALTH_CONTRIB=$(( (HEALTH_SCORE * 20) / 100 ))
COVERAGE_CONTRIB=$(( (COVERAGE_PCT * 20) / 100 ))
SEC_CONTRIB=0; [ "$SEC_FINDINGS" -eq 0 ] && SEC_CONTRIB=20
MATURITY_CONTRIB=$(( (MATURITY_PCT * 15) / 100 ))
DOCS_CONTRIB=$(( DOCS_PRESENT * 3 ))
CI_CONTRIB=0; [ "$CI_JOBS" -gt 0 ] && CI_CONTRIB=10
TRUST_SCORE=$(( HEALTH_CONTRIB + COVERAGE_CONTRIB + SEC_CONTRIB + MATURITY_CONTRIB + DOCS_CONTRIB + CI_CONTRIB ))

if [ "$TRUST_SCORE" -ge 90 ]; then
  CONFIDENCE_LEVEL="Production Ready"; CONFIDENCE_CODE="PROD"
elif [ "$TRUST_SCORE" -ge 80 ]; then
  CONFIDENCE_LEVEL="High Confidence"; CONFIDENCE_CODE="HIGH"
elif [ "$TRUST_SCORE" -ge 70 ]; then
  CONFIDENCE_LEVEL="Moderate Confidence"; CONFIDENCE_CODE="MOD"
else
  CONFIDENCE_LEVEL="Needs Improvement"; CONFIDENCE_CODE="LOW"
fi

# Output
case "$MODE" in
  --json)
    cat <<EOF
{"audit":{"date":"$AUDIT_DATE","auditor":"Savia Automated Audit","version":"$(get_version)","workspace":"PM-Workspace"},"composition":{"skills":$SKILLS_COUNT,"commands":$COMMANDS_COUNT,"agents":$AGENTS_COUNT,"hooks":$HOOKS_COUNT,"rules":$RULES_COUNT,"docs":$DOCS_COUNT,"test_files":$((TESTS_BATS + TESTS_SCRIPTS)),"total_lines_sh":$SH_LINES},"quality":{"health_score":$HEALTH_SCORE,"test_coverage":$COVERAGE_PCT,"bats_tests":$BATS_COUNT,"test_scripts":$TESTS_SCRIPTS},"security":{"security_findings":$SEC_FINDINGS,"vulnerabilities":$VULN_FINDINGS,"hooks_with_safety":$HOOKS_SAFE,"credential_hooks":$CRED_HOOKS},"maturity":{"stable_skills":$STABLE,"beta_skills":$BETA,"alpha_skills":$ALPHA,"maturity_percentage":$MATURITY_PCT},"ci_cd":{"workflow_jobs":$CI_JOBS},"documentation":{"required_docs_present":$DOCS_PRESENT,"changelog_entries":$CHANGELOG_ENTRIES},"trust_score":{"overall_score":$TRUST_SCORE,"confidence_level":"$CONFIDENCE_LEVEL","status":"$CONFIDENCE_CODE"}}
EOF
    ;;
  --markdown)
    OUT="$ROOT/output/audit-report-$AUDIT_DATE.md"
    mkdir -p "$(dirname "$OUT")"
    cat > "$OUT" <<EOF
# Executive Audit Report
**Workspace:** PM-Workspace | **Date:** $AUDIT_DATE | **Auditor:** Savia Automated Audit | **Version:** $(get_version)
---
## Composition & Scale
| Metric | Count | Metric | Count |
|--------|-------|--------|-------|
| Skills | $SKILLS_COUNT | Rules | $RULES_COUNT |
| Commands | $COMMANDS_COUNT | Docs | $DOCS_COUNT |
| Agents | $AGENTS_COUNT | Test Files | $((TESTS_BATS + TESTS_SCRIPTS)) |
| Hooks | $HOOKS_COUNT | SH Lines | $SH_LINES |

## Quality & Security
| Dimension | Score | Status |
|-----------|-------|--------|
| Health | $HEALTH_SCORE/100 | $([ "$HEALTH_SCORE" -ge 70 ] && echo "✅" || echo "⚠️") |
| Coverage | $COVERAGE_PCT% | $([ "$COVERAGE_PCT" -ge 80 ] && echo "✅" || echo "⚠️") |
| Security | $([ "$SEC_FINDINGS" -eq 0 ] && echo "Clean" || echo "Findings") | $([ "$SEC_FINDINGS" -eq 0 ] && echo "✅" || echo "🔴") |
| Maturity | $MATURITY_PCT% stable | $([ "$MATURITY_PCT" -ge 70 ] && echo "✅" || echo "⚠️") |
| Docs | $DOCS_PRESENT/5 required | $([ "$DOCS_PRESENT" -eq 5 ] && echo "✅" || echo "⚠️") |
| CI/CD | $CI_JOBS jobs | $([ "$CI_JOBS" -gt 0 ] && echo "✅" || echo "⚠️") |

## Trust Score: $TRUST_SCORE/100
**Confidence:** $CONFIDENCE_LEVEL | **Details:** Health $HEALTH_CONTRIB + Coverage $COVERAGE_CONTRIB + Security $SEC_CONTRIB + Maturity $MATURITY_CONTRIB + Docs $DOCS_CONTRIB + CI/CD $CI_CONTRIB

---
*Generated by Savia Executive Audit - Automated Quality Assessment*
EOF
    echo "✅ Report saved to: $OUT"
    ;;
  --ci)
    [ "$TRUST_SCORE" -lt 70 ] && { echo "❌ Trust score below threshold: $TRUST_SCORE < 70"; exit 1; }
    echo "✅ Trust score acceptable: $TRUST_SCORE >= 70"
    ;;
  *) echo "Usage: bash scripts/executive-audit.sh [--json | --markdown | --ci]"; exit 1 ;;
esac
