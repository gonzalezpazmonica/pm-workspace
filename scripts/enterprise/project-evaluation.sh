#!/usr/bin/env bash
set -uo pipefail
# project-evaluation.sh — SE-019 Project Evaluation (Lessons-as-Code)
#
# Genera evaluación post-entrega de un proyecto.
#
# Usage:
#   bash scripts/enterprise/project-evaluation.sh --project SLUG --tenant SLUG
#
# Lee: billing.jsonl, sow.md, y genera evaluation.md
# Secciones: objectives_met, velocity, lessons_learned, nps_score
# Output: tenants/{tenant}/projects/{slug}/evaluation.md
#
# Exit codes: 0 ok | 1 error | 2 usage error
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-019-project-evaluation.md

PROJECT=""
TENANT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --tenant)  TENANT="$2";  shift 2 ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$PROJECT" || -z "$TENANT" ]]; then
  echo "ERROR: --project and --tenant are required" >&2
  exit 2
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PROJECT_DIR="${REPO_ROOT}/tenants/${TENANT}/projects/${PROJECT}"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: Project directory not found: ${PROJECT_DIR}" >&2
  exit 1
fi

EVAL_DIR="${PROJECT_DIR}/evaluation"
mkdir -p "$EVAL_DIR"
EVAL_FILE="${EVAL_DIR}/evaluation.md"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Read billing data ────────────────────────────────────────────────────────
BILLING_FILE="${PROJECT_DIR}/billing.jsonl"
total_billed=0
total_paid=0
milestone_count=0

if [[ -f "$BILLING_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    amt=$(echo "$line" | grep -o '"amount_eur":[0-9.]*' | cut -d: -f2 || echo "0")
    stat=$(echo "$line" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "pending")
    total_billed=$(awk -v a="$total_billed" -v b="${amt:-0}" 'BEGIN{printf "%.2f", a+b}')
    [[ "$stat" == "paid" ]] && total_paid=$(awk -v a="$total_paid" -v b="${amt:-0}" 'BEGIN{printf "%.2f", a+b}')
    milestone_count=$((milestone_count + 1))
  done < "$BILLING_FILE"
fi

# ── Read SOW data ────────────────────────────────────────────────────────────
SOW_FILE="${PROJECT_DIR}/sow.md"
sow_status="not_found"
deliverables_count=0
contract_value=0

if [[ -f "$SOW_FILE" ]]; then
  sow_status="found"
  deliverables_count=$(grep -c "^| D-" "$SOW_FILE" 2>/dev/null || echo "0")
  cv=$(grep "^contract_value_eur:" "$SOW_FILE" | head -1 | awk '{print $2}' || echo "0")
  contract_value="${cv:-0}"
fi

# ── Compute budget performance ───────────────────────────────────────────────
budget_variance="N/A"
if [[ "$contract_value" != "0" && "$total_billed" != "0" ]]; then
  budget_variance=$(awk -v billed="$total_billed" -v planned="$contract_value" '
    BEGIN {
      if (planned > 0)
        printf "%.1f%%", (billed - planned) / planned * 100
      else
        print "N/A"
    }')
fi

# ── Write evaluation.md ──────────────────────────────────────────────────────
cat > "$EVAL_FILE" <<EOF
---
eval_id: "EVAL-${PROJECT}"
project: "${PROJECT}"
tenant: "${TENANT}"
generated_at: "${GENERATED_AT}"
status: in-progress
sow_present: ${sow_status}
milestone_count: ${milestone_count}
total_billed_eur: ${total_billed}
total_paid_eur: ${total_paid}
contract_value_eur: ${contract_value}
---

# Project Evaluation — ${PROJECT}

**Generated:** ${GENERATED_AT}
**Tenant:** ${TENANT}

## Objectives Met

SOW status: ${sow_status}
Deliverables defined in SOW: ${deliverables_count}

[Review each SOW deliverable and mark as met/partial/not-met.]

| Deliverable | Status | Notes |
|-------------|--------|-------|
| [from sow.md] | pending | |

## Velocity: Actual vs Estimated

| Metric              | Planned            | Actual             | Variance         |
|---------------------|--------------------|--------------------|------------------|
| Contract value (EUR) | ${contract_value}  | ${total_billed}    | ${budget_variance} |
| Milestones invoiced  | —                  | ${milestone_count} | —                |
| Total paid (EUR)     | —                  | ${total_paid}      | —                |

## Lessons Learned

[Document key lessons from this project. Use lessons-learned/ directory for structured entries.]

### What Went Well

- [Lesson 1]

### What Could Be Improved

- [Area 1]

### Recommendations for Future Projects

- [Recommendation 1]

## NPS Score

NPS survey not yet completed.

**Survey template:**
- Overall satisfaction (0-10): ___
- Technical quality (1-5): ___
- Communication (1-5): ___
- Timeliness (1-5): ___
- Value for money (1-5): ___
- Open feedback: ___

## Summary

This evaluation was auto-generated from available project data.
Complete the sections above before closing the project.
EOF

echo "Evaluation generated: ${EVAL_FILE}"
echo "  project:        ${PROJECT}"
echo "  tenant:         ${TENANT}"
echo "  milestones:     ${milestone_count}"
echo "  total_billed:   ${total_billed} EUR"
echo "  sow_present:    ${sow_status}"
