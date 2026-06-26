---
context_tier: L3
spec: SE-006
status: IMPLEMENTED
token_budget: 900
---

# Enterprise Governance Protocol

> Reference: SPEC-SE-006 Governance and Compliance Pack
> Frameworks: EU AI Act, NIS2, DORA, GDPR, CRA, ISO 42001

## Purpose

This document defines the operational governance protocol for Savia Enterprise
deployments subject to European regulatory frameworks. It specifies the minimum
compliance artefacts, the toolchain that generates them, and the human review
gates that must not be bypassed.

## Regulatory Framework Coverage

| Framework | Risk Level | Key Artefacts | Script |
|-----------|-----------|---------------|--------|
| EU AI Act | HIGH | Model cards, audit trail, EIPD | model-card-generator.sh, governance-audit-trail.sh |
| NIS2 | HIGH | Security posture, incident log | compliance-check.sh --framework nis2 |
| DORA | HIGH | ICT risk register, outsourcing | compliance-check.sh --framework dora |
| GDPR | MEDIUM | DPIA, data retention, N1-N4 classification | compliance-check.sh --framework gdpr |
| CRA | MEDIUM | SBOM, vulnerability disclosure | manual, SBOM tooling TBD |
| ISO 42001 | OPTIONAL | AI governance policy | This document |

## Audit Trail

Each enterprise action generates a signed JSONL entry with chain hash:

    sha256(ts + tenant + actor + action + prev_hash)

Storage: .claude/enterprise/audit/{tenant}/audit-trail.jsonl (append-only)

Operations:
  append      -- add entry: governance-audit-trail.sh append --tenant T --actor A --action X
  verify      -- check chain: governance-audit-trail.sh verify --file PATH
  export      -- auditor export: governance-audit-trail.sh export --tenant T --format md
  chain-status -- status: governance-audit-trail.sh chain-status --tenant T

## Model Cards (EU AI Act)

Required for every agent in a production tenant.
HIGH-risk (Annex III): human reviewer must countersign before production use.

Generation: scripts/enterprise/model-card-generator.sh
Storage: .claude/enterprise/model-cards/{agent}.md

## Compliance Scoring

scripts/enterprise/compliance-check.sh --framework eu-ai-act|nis2|gdpr|dora|all
Output: JSON with score 0-100 and gap list per check.

## Human Oversight Gates (Rule 8 - INVARIANT)

| Gate | Trigger | Required Action |
|------|---------|----------------|
| E1 Code Review | Any PR | Human approval before merge |
| E2 Compliance Sign-off | Annex III deployment | Human countersigns model card |
| E3 Audit Export | External auditor request | Human reviews before sending |
| E4 Data Purge | audit-purge.sh | Human provides --confirm and justification |

## Compliance Check Cadence

| Check | Frequency | Owner |
|-------|-----------|-------|
| Full compliance-check.sh | Weekly CI | Platform team |
| Audit trail verify | Daily CI | Automated |
| Model card review | Per agent change | Architect |
| Framework update review | Quarterly | Compliance officer |

## Limitations

Per .well-known/governance-layer-manifest.json (GLM claims boundary):
- Savia does not certify legal validity of compliance outputs
- Savia does not substitute for human judgment at E1-E4 gates
- External regulatory certification requires a qualified human auditor

## Related Documents

- docs/rules/domain/autonomous-safety.md
- docs/rules/domain/savia-ethical-principles.md
- .well-known/governance-layer-manifest.json
- scripts/enterprise/governance-audit-trail.sh
- scripts/enterprise/model-card-generator.sh
- scripts/enterprise/compliance-check.sh
