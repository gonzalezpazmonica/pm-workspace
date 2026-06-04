#!/usr/bin/env bash
# decide-architecture-corpus-test.sh — SPEC-158
# Curated 20-task corpus to validate classifier accuracy AC: >=85%.
# Each line: EXPECTED|TASK_DESCRIPTION

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/decide-architecture.sh"

# 20 curated tasks (10 WORKFLOW, 10 AGENT)
read -r -d '' CORPUS <<'EOF' || true
WORKFLOW|Generate a weekly sprint report from Azure DevOps queries and format as markdown
WORKFLOW|Implement SPEC-184 following the deterministic steps in the spec
WORKFLOW|Format and validate all yaml frontmatter in docs/propuestas
WORKFLOW|Extract entities from each markdown file and append to a CSV
WORKFLOW|Convert all em-dash characters to double-hyphen across the docs directory
WORKFLOW|Compute the test coverage percentage and write to coverage.txt
WORKFLOW|Run the BATS suite for tests/test-write-time-validation.bats and report pass count
WORKFLOW|For every PBI in the sprint, generate a status row in the dashboard
WORKFLOW|Parse the changelog and list all SPEC ids referenced
WORKFLOW|Build the agents-md index from .opencode/agents/*.md frontmatter
AGENT|Investigate why the auth test fails intermittently and figure out the root cause
AGENT|Research best practices for context optimization and recommend an approach
AGENT|Debug the slow query in production and triage possible causes
AGENT|Explore alternatives to Entity Framework and decide which fits best
AGENT|Loop until the build passes by self-correcting any errors that appear
AGENT|Find the best refactoring strategy for this legacy module
AGENT|Iterate until the prompt produces consistent output for these examples
AGENT|Compare three competing OSS libraries and recommend one
AGENT|Triage 50 GitHub issues and decide which are duplicates
AGENT|Discover which configurations cause memory leaks under load
EOF

PASS=0
FAIL=0
TOTAL=0
declare -a FAILURES

while IFS='|' read -r expected task; do
  [[ -z "$expected" || -z "$task" ]] && continue
  TOTAL=$((TOTAL+1))
  actual=$(bash "$SCRIPT" "$task" | grep '^DECISION:' | awk '{print $2}')
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    FAILURES+=("[$expected got $actual] $task")
  fi
done <<< "$CORPUS"

ACCURACY=$(( PASS * 100 / TOTAL ))
echo "Corpus accuracy: $PASS/$TOTAL = $ACCURACY%"
echo "Target (AC): 85%+"
if [[ $ACCURACY -ge 85 ]]; then
  echo "PASS"
else
  echo "FAIL — needs tuning"
  echo
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "  $f"
  done
  exit 1
fi
