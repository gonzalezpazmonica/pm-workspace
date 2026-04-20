---
status: PROPOSED
---

# SPEC-SE-026 — Compliance Evidence Automation

> **Priority:** P0 · **Estimate (human):** 8d · **Estimate (agent):** 8h · **Category:** complex · **Type:** automated audit trail + regulatory evidence + continuous compliance

## Objective

Give a 5000-person consultancy **automated compliance evidence generation**
for ISO 9001, CMMI, SOC 2, SOX, DORA, NIS2, AI Act, and CRA — harvested
from the work artifacts that Savia already produces (git history, approval
chains, `.review.crc`, allocation decisions, release plans). The auditor
gets a pre-built evidence package; the consultancy spends zero manual hours
on evidence collection.

The 2025-2027 regulatory convergence (NIS2 + DORA + AI Act + CRA) creates
a compliance burden that grows faster than headcount. Vanta and Drata
automate 90% of SaaS compliance evidence, but their model (API connectors
to cloud services) doesn't work for sovereign-first consultancies that
keep data local. Savia's git-native `.md` architecture inherently
satisfies change tracking, approval workflows, and immutable history —
the three things every auditor asks for.

## Principles affected

- **#1 Soberanía del dato** — evidence packages live as `.md` in the tenant repo, not in a GRC SaaS.
- **#3 Honestidad radical** — if a control is not satisfied, the evidence report says so. No theater.
- **#5 El humano decide** — control remediation is human-decided. Agents flag gaps, not fix them.

## Design

### Compliance framework mapping

```yaml
# .claude/compliance/frameworks.yaml
frameworks:
  iso-9001:
    controls: 36                # clauses relevant to software delivery
    evidence_sources:
      - git_history             # change management
      - review_crc              # code review evidence
      - release_plans           # SE-014 release documentation
      - test_results            # CI/CD evidence
      - retro_actions           # continuous improvement
  dora:
    controls: 24
    evidence_sources:
      - release_plans           # ICT change management
      - incident_postmortems    # ICT incident reporting
      - allocation_decisions    # third-party risk (AI provider)
      - transparency_log        # SE-025 AI disclosure
  ai-act:
    controls: 18
    evidence_sources:
      - allocation_decisions    # SE-022 (high-risk HR)
      - transparency_log        # SE-025 (Article 52)
      - court_verdicts          # SE-021 (human oversight)
      - equality_shield_checks  # bias testing evidence
```

### Evidence package structure

```
tenants/{tenant-id}/compliance/
├── frameworks.yaml             # Which frameworks apply
├── evidence/
│   ├── iso-9001/
│   │   ├── 2026-Q2-evidence.md       # Quarterly evidence package
│   │   └── controls-status.yaml      # Per-control pass/fail/partial
│   ├── dora/
│   │   ├── 2026-Q2-evidence.md
│   │   └── controls-status.yaml
│   └── ai-act/
│       ├── 2026-Q2-evidence.md
│       └── controls-status.yaml
├── gaps/
│   ├── GAP-001-missing-incident-runbook.md
│   └── ...
└── audit-ready/
    └── 2026-Q2-audit-package.md      # Consolidated for auditor
```

### Control evidence mapping (example: ISO 9001 clause 8.5.1)

```yaml
control: "ISO-9001-8.5.1"
title: "Control of production and service provision"
requirement: "Documented procedures for service delivery"
evidence:
  - type: "git_history"
    description: "All delivery specs versioned in git with approval trails"
    query: "git log --oneline --since 2026-01-01 -- 'docs/propuestas/*/SPEC-*'"
    result: "47 specs created, all with Co-Authored-By trails"
    status: "satisfied"
  - type: "review_crc"
    description: "Code review verdicts with per-file SHA-256"
    query: "find . -name '*.review.crc' -newer 2026-01-01"
    result: "23 court verdicts, avg score 81"
    status: "satisfied"
  - type: "release_plans"
    description: "Release plans with compliance profiles and approval chains"
    query: "find tenants/*/releases/ -name 'release-plan.md'"
    result: "8 release plans with DORA compliance profile"
    status: "satisfied"
overall_status: "satisfied"
last_assessed: "2026-04-12"
assessed_by: "compliance-evidence-agent"
```

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `compliance-harvester` | L1 | Collects evidence from git, CRC files, allocation decisions, logs |
| `gap-detector` | L1 | Compares collected evidence against framework controls, flags gaps |
| `audit-packager` | L2 | Generates the auditor-ready evidence package as consolidated `.md` |

### New commands

| command | output |
|---------|--------|
| `/compliance-evidence ISO-9001 [--period Q2]` | Generate evidence package |
| `/compliance-gaps [--framework DORA]` | List unsatisfied controls |
| `/compliance-audit-pack [--period Q2]` | Consolidated audit-ready package |
| `/compliance-status` | Dashboard of all frameworks with pass/fail/partial |

### Events

```json
{"event": "compliance.evidence_harvested", "framework": "iso-9001", "controls_satisfied": 34, "total": 36}
{"event": "compliance.gap_detected", "control": "ISO-9001-8.7.1", "gap": "No incident runbook found"}
{"event": "compliance.audit_pack_generated", "period": "2026-Q2", "frameworks": 3}
```

## Acceptance criteria

1. Framework mapping covers ISO 9001, DORA, AI Act with ≥80% of relevant controls.
2. Evidence harvester queries git history, `.review.crc`, allocation decisions, release plans.
3. Gap detector flags controls without sufficient evidence.
4. Audit package is a single `.md` readable by a non-technical auditor.
5. Controls status shows pass/fail/partial with evidence citations.
6. Evidence queries are deterministic (same input → same output).
7. 20+ BATS tests, SPEC-055 ≥ 80. Air-gap capable.

## Dependencies

- **Blocked by:** SE-001, SE-006 (governance framework), SE-014 (releases), SE-021 (Court verdicts), SE-022 (allocation decisions), SE-025 (AI transparency).
- **Integrates with:** every spec that produces auditable artifacts.

## Impact statement

For a consultancy subject to DORA + ISO 9001 + AI Act, annual compliance
audit preparation costs EUR 200-500K in manual evidence collection. Savia
already produces 90% of the evidence as a byproduct of normal work —
the compliance harvester just packages it. The git-native architecture
is the differentiator: every change is immutably timestamped, every
approval has a commit SHA, every review has a `.review.crc`. No
database-backed GRC tool can match this level of inherent auditability.

## Sources

- ISO 9001:2015 (Quality Management Systems — Requirements)
- EU DORA (2022/2554) — Digital Operational Resilience Act
- EU AI Act (2024) — High-risk AI systems requirements
- EU NIS2 Directive (2022/2555) — Network and Information Security
- EU Cyber Resilience Act (CRA, 2024)
- Vanta, Drata, Sprinto — automated compliance platforms (pricing/feature analysis)
- SOC 2 Type II evidence requirements (AICPA Trust Services Criteria)
