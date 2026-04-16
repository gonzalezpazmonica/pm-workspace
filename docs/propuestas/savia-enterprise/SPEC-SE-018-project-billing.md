# SPEC-SE-018 — Project Billing (Revenue-as-Code)

> **Priority:** P1 · **Estimate (human):** 8d · **Estimate (agent):** 8h · **Category:** complex · **Type:** billing lifecycle + IFRS 15 revenue recognition + chargeback

## Objective

Give a 5000-person consultancy a **tenant-isolated, auditable billing engine** where contract financial models live as `.md` in each project's pm-workspace, WIP is auto-computed from local time logs, IFRS 15 percentage-of-completion (POC) is calculated by agents with every input traceable in git, and invoice drafts are generated as human-reviewed `.md` before pushing to any ERP. Revenue recognition decisions are always human-gated. The audit trail is immutable in git — SOX-ready by construction.

SPI Research benchmarks show 10–20% revenue leakage in consulting from late billing, contested timesheets, and untracked scope changes. DSO (Days Sales Outstanding) runs 60–90 days. The root cause: ERPs book revenue, but the delivery data that should drive those bookings lives in disconnected tools. IFRS 15 POC calculations are retrofitted at month-end from stale spreadsheets instead of computed continuously from actual burn.

Savia Enterprise makes the financial model live code: a `.md` that agents recompute on every meaningful delivery commit, flagging variance before the CFO asks why revenue is off.

## Principles affected

- **#1 Soberanía del dato** — billing models and WIP registers live as `.md`/`.yaml` in the tenant repo. No SaaS billing intermediary owns the data.
- **#2 Independencia del proveedor** — adapters to SAP FI/CO, Oracle Financials, NetSuite, Workday are opt-in. The canonical financial model is the `.md`.
- **#4 Privacidad absoluta** — financial data (rates, margins, revenue) stays N4-isolated per client project. Cross-tenant aggregation for portfolio view is computed locally, never sent externally.
- **#5 El humano decide** — invoice issuance and revenue recognition are always human-gated. Agents compute; humans approve.

## Design

### Financial model structure

```
tenants/{tenant-id}/projects/{project-id}/billing/
├── financial-model.md        # Master (YAML frontmatter: contract type, rates, POC method)
├── rate-card.yaml             # Blended and role-specific rates
├── wip-register.yaml          # Work-in-progress, auto-computed from time logs
├── poc-calculations/
│   ├── 2026-04.yaml           # Monthly POC snapshot (auditable)
│   ├── 2026-05.yaml
│   └── ...
├── invoices/
│   ├── INV-2026-001.md        # Invoice draft (human reviews before ERP push)
│   ├── INV-2026-002.md
│   └── ...
├── change-orders/
│   ├── CO-001.md              # Links to SE-017 change requests
│   └── ...
├── disputes/
│   └── DISP-001.md            # Invoice dispute record
└── audit-trail.jsonl          # Immutable append-only log (SOX-ready)
```

### Financial model frontmatter

```yaml
---
model_id: "FM-2026-001"
tenant: "acme-consulting"
project: "erp-migration"
sow_id: "acme-erp-migration-2026"    # link to SE-017
case_id: "BC-2026-001"               # link to SE-016
contract_type: "fixed-price"          # fixed-price | time-materials | outcome-based | retainer | hybrid
contract_value_eur: 420000
currency: "EUR"
poc_method: "input-cost"              # input-cost | input-hours | output-deliverables | milestone
billing_schedule: "monthly"           # monthly | milestone | on-completion | custom
payment_terms_days: 30
tax_treatment: "reverse-charge-eu"    # domestic | reverse-charge-eu | oss-eu | exempt | us-nexus
withholding_tax_pct: 0
margin_target_pct: 35
budget_hours: 2800
budget_cost_eur: 273000
revenue_recognized_eur: 0
revenue_billed_eur: 0
revenue_collected_eur: 0
wip_eur: 0
variance_alerts:
  cost: { threshold_pct: 15, current_pct: 0, status: "green" }
  margin: { threshold_pct: 5, current_pct: 0, status: "green" }
last_poc_date: null
---
```

### IFRS 15 POC calculation (agentic, monthly)

The `poc-calculator` agent runs monthly (or on-demand) and produces a POC snapshot:

```yaml
# poc-calculations/2026-06.yaml
---
period: "2026-06"
model_id: "FM-2026-001"
poc_method: "input-cost"
inputs:
  total_estimated_cost_eur: 273000
  cost_incurred_to_date_eur: 95000
  estimated_cost_at_completion_eur: 280000    # includes known overrun
poc_pct: 33.93     # = 95000 / 280000
revenue_to_recognize_eur: 142506    # = 420000 × 33.93%
previously_recognized_eur: 98000
current_period_revenue_eur: 44506
adjustments:
  - type: "estimate_revision"
    reason: "Data migration scope extended per CO-001"
    impact_eur: 7000
    change_order_ref: "CO-001"
computed_by: "poc-calculator"
computed_at: "2026-07-01T08:00:00Z"
approved_by: null                     # human fills this
---
```

The `approved_by` field is null until a human (revenue accountant or CFO) reviews and signs off. Agents NEVER auto-approve revenue recognition.

### WIP register (auto-computed)

WIP = cost incurred - cost billed. The `wip-tracker` agent reads the project's time logs (or SE-019's timesheet integration) and computes:

```yaml
wip_register:
  as_of: "2026-06-30"
  total_hours_logged: 633
  total_cost_eur: 95000
  total_billed_eur: 84000
  wip_eur: 11000
  wip_age_days: 22
  stale_entries:
    - period: "2026-05"
      hours: 48
      cost_eur: 7200
      reason: "Client dispute on scope — DISP-001"
```

WIP aging > 60 days triggers an alert to the engagement manager.

### Invoice generation

The `invoice-drafter` agent generates an invoice from the financial model:

```yaml
---
invoice_id: "INV-2026-003"
model_id: "FM-2026-001"
tenant: "acme-consulting"
client: "acme-banking"
period: "2026-06"
type: "progress"           # progress | milestone | final | credit-note
line_items:
  - description: "Professional services — June 2026"
    quantity: 210
    unit: "hours"
    rate_eur: 150
    amount_eur: 31500
  - description: "Data migration tooling license"
    quantity: 1
    unit: "lump-sum"
    rate_eur: 5000
    amount_eur: 5000
subtotal_eur: 36500
tax_treatment: "reverse-charge-eu"
tax_eur: 0
total_eur: 36500
payment_terms: "Net 30"
due_date: "2026-07-31"
status: "draft"             # draft | approved | sent | paid | disputed | cancelled
approved_by: null
sent_at: null
---
```

The `approved_by` → `sent` transition is ALWAYS human-gated. Agents draft; humans send.

### Chargeback per tenant (multi-project)

For consultancies running multiple projects for the same client-tenant, the `chargeback-allocator` agent computes cross-project cost allocation:

```yaml
chargeback:
  tenant: "acme-banking"
  period: "2026-06"
  projects:
    - project: "erp-migration"
      direct_cost_eur: 31500
      shared_infra_pct: 60
      shared_infra_eur: 3000
      total_eur: 34500
    - project: "sso-integration"
      direct_cost_eur: 12000
      shared_infra_pct: 40
      shared_infra_eur: 2000
      total_eur: 14000
  shared_infra_total_eur: 5000
  allocation_method: "direct-cost-weighted"
```

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `poc-calculator` | L1 | Runs IFRS 15 POC calculation monthly. Never approves — produces draft for human sign-off. |
| `wip-tracker` | L1 | Reads time logs, computes WIP register, flags stale entries. |
| `invoice-drafter` | L2 | Generates invoice .md from financial model. Draft only — human approves. |
| `chargeback-allocator` | L1 | Computes cross-project cost allocation per tenant. |
| `billing-sentinel` | L1 | Monitors margin erosion, cost variance, WIP aging. Emits alerts. |

### Events

```json
{"event": "poc.computed", "model_id": "...", "poc_pct": 33.93, "revenue_eur": 44506}
{"event": "invoice.drafted", "invoice_id": "...", "total_eur": 36500}
{"event": "invoice.approved", "invoice_id": "...", "approved_by": "@revenue-accountant"}
{"event": "billing.variance_alert", "model_id": "...", "dimension": "margin", "current_pct": 28}
{"event": "wip.stale_alert", "model_id": "...", "stale_eur": 7200, "age_days": 62}
```

`release.completed` from SE-014 triggers POC recomputation.
`sow.amended` from SE-017 triggers financial model update.

## Acceptance criteria

1. Regla `docs/rules/domain/revenue-as-code.md` ≤150 lines.
2. JSON Schema for financial-model.md validates 20+ fields.
3. `poc-calculator` computes correct POC for 3 contract types (T&M, fixed-price, milestone) with test vectors.
4. POC snapshots are append-only in `poc-calculations/` — never overwritten.
5. `invoice-drafter` produces invoice.md that passes schema validation.
6. Invoice `approved_by` transition is human-gated — agent NEVER sets it.
7. `billing-sentinel` emits variance alert when margin drops below threshold.
8. WIP aging > 60 days triggers alert with dispute record reference.
9. Chargeback allocation across 3+ projects produces consistent totals.
10. `audit-trail.jsonl` is append-only, one line per action, timestamp + actor + action + before/after values.
11. 20+ BATS tests, SPEC-055 score ≥ 80.
12. Air-gap capable. `pr-plan` 11/11 gates.

## Out of scope

- Full tax engine (Avalara / Vertex integration) — v1 has `tax_treatment` field but no automated tax computation.
- Dunning / collections automation — out of scope for v1.
- ERP adapter implementations — SE-003 MCP catalog extension; SE-018 defines the contract surface.
- Transfer pricing for intercompany billing — acknowledged, not implemented.
- Multi-currency with real-time FX rates — v1 assumes single currency per model.
- Outcome-based pricing revenue model (variable consideration under IFRS 15) — placeholder, needs dedicated research.
- Bank payment integration — invoices are generated, not transmitted.

## Dependencies

- **Blocked by:** SE-001, SE-002, SE-014 (consumes `release.completed`), SE-017 (consumes `sow.amended` and SOW contract value).
- **Blocks:** SE-019 (evaluation compares billing actuals to business case), SE-020 (portfolio billing aggregation).
- **Soft deps:** SE-015 (opportunity pricing feeds initial rate card), SE-016 (business case provides cost structure).

## Migration path

- Reversible: `BILLING_ENABLED=false` in tenant manifest.
- Import: `scripts/billing-import.sh` reads CSV export from ERP.
- Coexistence: projects without `billing/` skip all financial logic.

## Impact statement

Revenue recognition is the highest-stakes compliance area in consulting. A POC calculation done wrong triggers restatement, audit findings, and regulatory exposure. A billing system where every input is traceable in git and every approval has a timestamp eliminates the manual-spreadsheet risk that keeps CFOs awake. For a consultancy with EUR 30M+ annual revenue, preventing one restatement pays for years of tooling.

## Sources

- IFRS 15 Revenue from Contracts with Customers (IASB)
- ASC 606 (FASB, US equivalent)
- SPI Research Professional Services Maturity Benchmark 2024
- SOX Section 404 (internal controls over financial reporting)
- PwC IFRS 15 Implementation Guide
- EU VAT OSS (One-Stop Shop) for cross-border services
- Sarbanes-Oxley Act Section 302/404 for US-listed consultancies
