#!/usr/bin/env bash
set -uo pipefail
# sow-create.sh — SE-017 Project Definition (SOW-as-Code)
#
# Crea un Statement of Work como fichero versionado.
#
# Usage:
#   bash scripts/enterprise/sow-create.sh \
#     --project SLUG --tenant SLUG [--template basic|agile|fixed-price]
#
# Crea: tenants/{tenant}/projects/{slug}/sow.md
# Template sections: objective, scope, deliverables, timeline, acceptance_criteria, exclusions
#
# Exit codes: 0 ok | 1 error | 2 usage error
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-017-project-definition.md

PROJECT=""
TENANT=""
TEMPLATE="basic"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)  PROJECT="$2";  shift 2 ;;
    --tenant)   TENANT="$2";   shift 2 ;;
    --template) TEMPLATE="$2"; shift 2 ;;
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

case "$TEMPLATE" in
  basic|agile|fixed-price) ;;
  *) echo "ERROR: --template must be basic|agile|fixed-price" >&2; exit 2 ;;
esac

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PROJECT_DIR="${REPO_ROOT}/tenants/${TENANT}/projects/${PROJECT}"
SOW_FILE="${PROJECT_DIR}/sow.md"

if [[ -f "$SOW_FILE" ]]; then
  echo "ERROR: SOW already exists: ${SOW_FILE}" >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

generate_template() {
  local tmpl="$1"
  local proj="$2"
  local tenant="$3"
  local created="$4"

  case "$tmpl" in
    basic)
      cat <<EOF
---
sow_id: "${proj}-sow"
project: "${proj}"
tenant: "${tenant}"
template: basic
created_at: "${created}"
status: draft
engagement_type: time-materials
contract_value_eur: 0
start_date: ""
end_date: ""
---

# Statement of Work — ${proj}

## Objective

[Describe the primary goal and business objective of this engagement.]

## Scope

### In Scope

- [Item 1]
- [Item 2]

### Out of Scope

- [Explicitly excluded item 1]
- [Explicitly excluded item 2]

## Deliverables

| ID    | Deliverable                | Owner | Due Date |
|-------|---------------------------|-------|----------|
| D-001 | [Deliverable description] |       |          |

## Timeline

| Milestone | Date | Description |
|-----------|------|-------------|
|           |      |             |

## Acceptance Criteria

For each deliverable, the acceptance criteria are:

### D-001

**Given** [precondition],
**when** [action],
**then** [expected result].

## Exclusions

[List items explicitly excluded from this engagement to prevent scope creep.]
EOF
      ;;
    agile)
      cat <<EOF
---
sow_id: "${proj}-sow"
project: "${proj}"
tenant: "${tenant}"
template: agile
created_at: "${created}"
status: draft
engagement_type: time-materials
contract_value_eur: 0
start_date: ""
end_date: ""
sprint_cadence_weeks: 2
---

# Statement of Work — ${proj} (Agile)

## Objective

[Describe the primary goal and business objective of this engagement.]

## Scope

### In Scope

- [Epic 1]
- [Epic 2]

### Out of Scope

- [Explicitly excluded item 1]

## Deliverables

| ID    | Epic / Feature             | Priority | Estimated SP |
|-------|---------------------------|----------|--------------|
| D-001 | [Feature description]     | High     |              |

## Timeline

| Sprint | Start | End  | Goals |
|--------|-------|------|-------|
| S1     |       |      |       |

## Acceptance Criteria

### Definition of Done

- All acceptance tests pass
- Code reviewed and merged
- Documentation updated
- Deployed to staging

### D-001

**Given** [precondition],
**when** [action],
**then** [expected result].

## Exclusions

[List items explicitly excluded.]
EOF
      ;;
    fixed-price)
      cat <<EOF
---
sow_id: "${proj}-sow"
project: "${proj}"
tenant: "${tenant}"
template: fixed-price
created_at: "${created}"
status: draft
engagement_type: fixed-price
contract_value_eur: 0
start_date: ""
end_date: ""
payment_schedule: milestone
---

# Statement of Work — ${proj} (Fixed Price)

## Objective

[Describe the primary goal and business objective of this engagement.]

## Scope

### In Scope

- [Item 1]
- [Item 2]

### Out of Scope

- [Explicitly excluded item 1]

## Deliverables

| ID    | Deliverable                | Milestone | Value EUR |
|-------|---------------------------|-----------|-----------|
| D-001 | [Deliverable description] | M1        |           |

## Timeline

| Milestone | Date | Deliverables | Payment % |
|-----------|------|-------------|-----------|
| M1        |      | D-001       | 30%       |
| M2        |      |             | 40%       |
| Final     |      |             | 30%       |

## Acceptance Criteria

### D-001

**Given** [precondition],
**when** [action],
**then** [expected result].

**Acceptance evidence:**
- [ ] Document delivered and reviewed
- [ ] Sign-off from client engagement authority

## Exclusions

[List items explicitly excluded.]

## Change Control

Changes to scope, timeline, or budget require a written Change Request
approved by both parties before work begins.
EOF
      ;;
  esac
}

generate_template "$TEMPLATE" "$PROJECT" "$TENANT" "$CREATED_AT" > "$SOW_FILE"

echo "SOW created: ${SOW_FILE}"
echo "  project:  ${PROJECT}"
echo "  tenant:   ${TENANT}"
echo "  template: ${TEMPLATE}"
