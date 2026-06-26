---
context_tier: L3
spec: SE-026
status: IMPLEMENTED
token_budget: 850
---

# Enterprise Compliance Evidence Automation

> Reference: SPEC-SE-026 — Compliance Evidence Automation

## Purpose

Automated generation of compliance evidence packages for ISO 9001, DORA, AI Act,
and NIS2. Evidence is harvested from workspace artefacts already produced by
normal work — git history, approval chains, model cards, audit trails, and specs.

Auditors receive a pre-built evidence package. Zero manual collection effort.

## Covered Frameworks

| Framework | Controls | Evidence Sources |
|-----------|---------|-----------------|
| EU AI Act | 18 | Model cards, audit trail, GLM manifest, oversight gates |
| ISO 9001 | 36 | Specs (change mgmt), review logs, release plans, retros |
| DORA | 24 | ICT manifest, AI outsourcing disclosure, incident log |
| NIS2 | 20 | Security posture, incident log, patch policy |

## Evidence Package Structure

Collected to: output/compliance-evidence/{date}/{framework}/evidence-bundle/
Index file:   output/compliance-evidence/{date}/index.json

Index fields: framework, artifacts, generated_at

## Collection

```
scripts/enterprise/compliance-evidence-collector.sh [--framework FRAMEWORK] [--tenant SLUG]
```

Supported frameworks: eu-ai-act, iso-9001, dora, nis2, all

## Report Generation

```
scripts/enterprise/compliance-report-generator.sh --framework FRAMEWORK [--tenant SLUG] [--since DATE]
```

Report sections:
1. Executive Summary — metrics, coverage, disclaimer
2. Findings — per-control assessment (satisfied/partial/gap)
3. Evidence References — collected artifacts with timestamps
4. Gaps — missing controls or artifacts
5. Remediation Plan — gap-to-PBI workflow

## Deterministic Evidence Queries

Evidence queries use deterministic inputs:
- File existence checks (same input always produces same result)
- git log with fixed date range (reproducible)
- No probabilistic or LLM-generated content in evidence itself

Same workspace state always produces the same evidence package (SPEC-SE-026 AC-6).

## Disclaimer

Evidence packages are operational documents. They are NOT:
- Legal certifications
- Regulatory attestations
- Substitutes for human review at E2 gate

An external auditor human review is required for formal certification.

## Integration with Compliance Check

1. Run compliance-check.sh to identify gaps (scripts/enterprise/compliance-check.sh)
2. Run compliance-evidence-collector.sh to gather artifacts
3. Run compliance-report-generator.sh to create auditor-ready report
4. Human reviews and signs off before sending to external auditor

## Related Documents

- docs/rules/domain/enterprise-governance-protocol.md
- docs/enterprise/templates/compliance-report.md
- scripts/enterprise/compliance-evidence-collector.sh
- scripts/enterprise/compliance-report-generator.sh
- scripts/enterprise/compliance-check.sh
