# SPEC-SE-017 — Project Definition (SOW-as-Code)

> **Priority:** P1 · **Estimate (human):** 7d · **Estimate (agent):** 7h · **Category:** standard · **Type:** contract lifecycle + delivery traceability

## Objective

Give a 5000-person consultancy a **machine-readable, agent-queryable,
contract-grade Statement of Work** stored as `.md` inside the tenant's
own pm-workspace, with testable acceptance criteria, a YAML RACI matrix,
a deliverables ledger linked to the backlog, and a structured change
request mechanism that produces auditable amendments. Delivery work
that is not traceable to a SOW deliverable is refused by the workspace.

The business problem this solves is the **sales→delivery handoff gap**:
SOWs get written in Word, approved in DocuSign, parked in a SharePoint
folder, and instantly diverge from the reality of agile execution. SPI
Research benchmarks attribute 15–30% margin erosion in consulting to
this gap. The downstream cost is also legal: disputes over "was X in
scope" are resolved by whichever side has cleaner records, and today
neither side does.

Savia Enterprise turns the SOW into code — a versioned, auto-validated
artifact that travels with the delivery repo, where agents can check
"does this PBI trace to a contracted deliverable" in zero seconds.

## Principles affected

- **#1 Soberanía del dato** — the SOW lives as `.md` in the tenant repo,
  not as a PDF locked in a third-party SaaS. It is portable, diff-able,
  human-readable, and survives any vendor disappearing.
- **#2 Independencia del proveedor** — adapters to DocuSign / Adobe Sign
  / Ironclad / Icertis are opt-in; the canonical SOW is the `.md`. If a
  tenant never uses any eSignature provider, SOW-as-Code still works.
- **#5 El humano decide** — scope changes always require explicit human
  approval. Agents DRAFT change requests; they never issue amendments.

## Design

### SOW-as-Code — the canonical structure

```
tenants/{tenant-id}/projects/{project-id}/definition/
├── SOW.md                  # Master contract (YAML frontmatter + prose)
├── acceptance.md           # Testable Given/When/Then per deliverable
├── raci.yaml               # Responsibility matrix (queryable)
├── deliverables.yaml       # Deliverables ledger (scope items)
├── governance.md           # Meeting cadence, escalation path, reporting
├── change-requests/
│   ├── CR-0001-add-sso.md  # One file per change request
│   └── CR-0002-scope-cut.md
├── amendments/
│   ├── v1.0-signed.md      # Sealed amendment snapshots
│   └── v1.1-signed.md
└── .sow-sig                # Detached signature of the current SOW
```

The `SOW.md` frontmatter is the canonical source of truth:

```yaml
---
sow_id: "acme-erp-migration-2026"
tenant: "acme-banking"
project: "erp-migration"
engagement_type: "fixed-price"   # fixed-price | time-materials | outcome-based | retainer
contract_value_eur: 420000
start_date: "2026-05-01"
end_date: "2026-10-31"
parties:
  provider: "Savia Consulting"
  client: "Acme Banking"
  partners: []
governance_model: "standard-monthly"
compliance_profile: "dora-banking"   # reused from SE-014
deliverables:
  - id: "D-001"
    title: "Legacy ERP assessment report"
    owner: "engagement-manager"
    acceptance_ref: "acceptance.md#d-001"
    linked_pbis: []
  - id: "D-002"
    title: "Target architecture document"
    owner: "solution-architect"
    acceptance_ref: "acceptance.md#d-002"
    linked_pbis: []
  - id: "D-003"
    title: "Data migration run-books (30 entities)"
    owner: "delivery-manager"
    acceptance_ref: "acceptance.md#d-003"
    linked_pbis: []
change_control:
  materiality_threshold_pct: 5   # CR above this % triggers client signature
  auto_approve_below_eur: 5000
approvals_required:
  - role: "client_engagement_authority"
  - role: "provider_practice_leader"
  - role: "legal_counsel"
    conditions: ["engagement_type:fixed-price"]
---

# SOW — Acme Banking ERP Migration

## 1. Background
[prose context...]

## 2. Scope
[explicit inclusions + explicit exclusions]

## 3. Deliverables
[reference to deliverables.yaml]

## 4. Assumptions
[...]

## 5. Out of scope
[explicit list — this is where disputes are prevented]
```

### Acceptance criteria as testable Given/When/Then

`acceptance.md` is the bridge between contract language and tests:

```markdown
## D-001 — Legacy ERP assessment report

**Given** a completed assessment of the current SAP R/3 instance,
**when** the report is delivered to the client engagement authority,
**then** it SHALL include:
1. Inventory of ≥120 custom ABAP programs with criticality rating
2. Data model mapping with ≥95% table coverage
3. Integration map of all downstream systems
4. Risk-weighted sunset recommendation
5. Executive summary in Spanish AND English

**Acceptance evidence:**
- `deliverables/D-001-assessment-report.pdf` (sealed)
- `deliverables/D-001-raw-data.xlsx` (appendix)
- Sign-off from `roles.client_engagement_authority`
```

Every Given/When/Then is linked to one or more PBIs in the backlog. The
backlog grooming agent REFUSES to close a sprint where a deliverable's
acceptance criteria don't have at least one linked PBI.

### RACI as YAML (queryable)

```yaml
# raci.yaml
matrix:
  D-001:
    R: ["engagement-manager"]
    A: ["provider-practice-leader"]
    C: ["solution-architect", "business-analyst"]
    I: ["client-engagement-authority", "legal-counsel"]
  D-002:
    R: ["solution-architect"]
    A: ["provider-practice-leader"]
    C: ["engagement-manager", "security-officer"]
    I: ["client-engagement-authority"]
```

Agents query this with `bash scripts/raci-query.sh D-001 R` → returns
the list of responsibles. During sprint planning, the planner agent
uses RACI to assign work and flags deliverables where "R" is unassigned.

### Change requests as spec amendments

A change request is a `.md` file that proposes a diff against the
current SOW frontmatter:

```yaml
---
cr_id: "CR-0001"
sow_id: "acme-erp-migration-2026"
raised_by: "engagement-manager"
raised_on: "2026-06-15"
status: "draft"   # draft | review | approved | rejected | applied
materiality_pct: 7.2
impact_eur: 30000
impact_days: 15
justification: "Client added SSO integration after kickoff (ticket ACME-4532)"
patch:
  - op: "add"
    path: "deliverables"
    value:
      id: "D-004"
      title: "SSO integration with Acme IdP"
      owner: "security-officer"
      acceptance_ref: "acceptance.md#d-004"
  - op: "replace"
    path: "contract_value_eur"
    value: 450000
  - op: "replace"
    path: "end_date"
    value: "2026-11-15"
approvals:
  - role: "client_engagement_authority"
    decision: pending
  - role: "provider_practice_leader"
    decision: pending
---

# Rationale

[prose: why this CR, what changed, what's the business driver]
```

When all `approvals[].decision == "approved"`, a signed amendment
snapshot is generated: `amendments/v1.1-signed.md`. The frontmatter
patch is applied to `SOW.md`. The acceptance and deliverables files
are updated. A new `.sow-sig` is issued.

### Spec-driven PBI validation

A new hook (`sow-trace-validate.sh`) runs pre-commit on the delivery
repo. For every PBI in the backlog, it verifies:

1. The PBI has a `sow_deliverable: D-XXX` field in its frontmatter.
2. The referenced deliverable exists in `deliverables.yaml` OR in an
   approved change request.
3. The PBI's acceptance criteria cite at least one Given/When/Then from
   `acceptance.md#d-xxx`.

PBIs that fail validation are blocked from entering "Ready for Dev".
The hook can be bypassed with `--allow-orphan` only by a user in the
`engagement-manager` role AND only with a written justification that
goes into the audit log.

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `sow-writer` | L2 | Drafts `SOW.md` from discovery notes, RFP responses, and prior SOWs of similar engagement type. Never publishes without human review. |
| `cr-drafter` | L2 | Detects scope drift by comparing actual sprint work against `deliverables.yaml`. When materiality threshold is crossed, drafts a CR and routes to the engagement manager. |
| `raci-validator` | L1 | On sprint planning, verifies every deliverable has a live R owner who is not on leave, overallocated, or rolled off. |
| `acceptance-linker` | L1 | Maps PBIs to acceptance Given/When/Then entries and flags orphan PBIs. |

All four agents declare `permission_level` and `token_budget` in their
frontmatter, per SPEC-AGENT-METERING.

### New commands

| command | role | output |
|---------|------|--------|
| `/sow-init` | engagement-manager | Scaffolds the `definition/` tree from a template keyed by engagement_type. |
| `/sow-validate` | anyone | Runs the full validation (schema, RACI completeness, PBI traceability, materiality audit). Read-only. |
| `/sow-cr-draft "Add SSO"` | engagement-manager | Invokes `cr-drafter` to generate a change-request draft. |
| `/sow-amend CR-0001` | engagement-manager | After all approvals, seals the amendment and applies the patch. Requires a human confirmation step. |
| `/sow-query "who is R for D-002?"` | anyone | Queries the RACI matrix via natural language → `raci-query.sh`. |

### Schema and contracts

A JSON Schema for `SOW.md` frontmatter lives at
`.claude/schemas/sow-frontmatter.schema.json`. The validator is
`scripts/sow-validate.sh`, invoked by the pre-commit hook and by
`/sow-validate`.

**Event emitted on amendment signing:**
```json
{
  "event": "sow.amended",
  "tenant": "acme-banking",
  "sow_id": "acme-erp-migration-2026",
  "cr_id": "CR-0001",
  "new_version": "1.1",
  "materiality_pct": 7.2,
  "applied_at": "2026-06-18T14:20:00Z"
}
```
Consumed by SE-018 (billing) to trigger revenue recognition adjustment
and by SE-019 (evaluation) to update the baseline.

## Acceptance criteria

1. Regla `docs/rules/domain/sow-as-code.md` ≤150 lines documents the
   SOW schema, the 4 agents, the CR workflow, and the materiality rules.
2. JSON Schema `sow-frontmatter.schema.json` validates the 12 required
   frontmatter fields.
3. `scripts/sow-validate.sh` detects the 8 top failure modes (missing
   acceptance, orphan PBI, RACI gap, expired CR, over-materiality without
   signature, contradicting amendments, schema drift, non-unique D-IDs).
4. `sow-trace-validate.sh` hook blocks commits with orphan PBIs unless
   `--allow-orphan` is passed by an authorized role.
5. `/sow-init` scaffolds a working tenant directory in < 5 seconds from
   any of the 4 engagement-type templates.
6. `/sow-cr-draft` generates a CR file that passes `/sow-validate` on
   the first try for a realistic scope-add example.
7. `cr-drafter` agent detects scope drift by diffing the last sprint's
   closed PBIs against `deliverables.yaml` and flags items with no
   matching deliverable.
8. Amendment signing emits `sow.amended` event on the local bus and SE-018
   mock consumer logs it.
9. 20+ BATS tests, SPEC-055 score ≥ 80, coverage delta ≥ 0.
10. Air-gap: full flow works offline (no DocuSign adapter required).
11. `pr-plan` passes 11/11 gates.

## Out of scope

- Full eSignature adapter implementations (DocuSign / Adobe Sign /
  Ironclad) — SE-017 defines the contract surface, adapters ship later
  as part of SE-003 MCP catalog extensions.
- Legal clause library (standard T&C templates) — out of scope for v1;
  tenants supply their own prose.
- Multi-language SOW translation pipeline — later sprint.
- Integration with CLM platforms (Icertis, Ironclad) for the full
  contract lifecycle — v1 treats CLM as a write-once sink via adapter.
- Invoicing from SOW (that is SE-018's job).
- Risk register sync (SE-006 owns that).
- Gantt view / critical path rendering (out of scope for v1).

## Dependencies

- **Blocked by:** SE-001 (layer contract), SE-002 (multi-tenant isolation),
  SE-010 (migration path — SOW-as-Code must coexist with legacy PDFs).
- **Blocks:** SE-018 (billing amounts derive from SOW contract value and
  amendment history), SE-019 (evaluation baseline is SOW deliverables
  vs actually-shipped).
- **Soft deps:** SE-003 (MCP catalog — eventual eSignature adapters),
  SE-006 (governance — audit trail for amendments), SE-009 (observability
  for scope-drift detection).

## Migration path

- Reversible: feature-flag `SOW_AS_CODE_ENABLED=false` in the tenant
  manifest disables all validation hooks. Existing delivery work is
  not blocked.
- Import: `scripts/sow-import.sh` reads a DOCX or PDF SOW and drafts a
  `SOW.md` (the agent reviews, human approves). This is a one-time
  migration tool, not part of the runtime.
- Coexistence with legacy SOWs: projects without a `definition/`
  directory are in "legacy mode" and pre-commit validation is bypassed
  with a `legacy_sow: true` flag in the project manifest.
- Roll-forward: new projects in the tenant default to SOW-as-Code once
  the feature flag is on.

## Impact statement

A SOW that lives in the same repo as the delivery work eliminates the
single largest value leak in consulting: the invisible drift between
what was contracted and what is being built. For a consultancy with
200+ active client engagements, the marginal gain of catching one
scope-creep-driven dispute per month pays for the entire feature.

The agentic dimension adds a second layer: the `cr-drafter` agent
continuously compares burn against deliverables and surfaces drift
when it's still a two-line email conversation instead of a three-month
legal dispute. Humans still decide; Savia just makes sure they decide
while there's still time.

## Sources

- PMBOK 7th Edition — Planning and Delivery Performance Domains
- PRINCE2 2017 — Project Initiation Documentation (PID)
- ISO 21502:2020 — Project management guidance
- SPI Research Professional Services Maturity Benchmark 2024
- PMI Pulse of the Profession 2024 (scope creep statistics)
- INCOSE Systems Engineering Handbook — requirements traceability
- DORA (EU 2022/2554) — contract transparency obligations for ICT
  third-party risk, cross-referenced from SE-014
