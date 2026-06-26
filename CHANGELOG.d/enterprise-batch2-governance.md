# Enterprise Batch 2 — Governance, Licensing and Compliance Evidence

**Date:** 2026-06-24
**Specs:** SE-006, SE-008, SE-026
**Status:** IMPLEMENTED

## SPEC-SE-006 — Governance and Compliance Pack

New scripts:
- scripts/enterprise/governance-audit-trail.sh
  Subcommands: append, verify, export, chain-status
  Append-only JSONL audit trail per tenant with sha256 chain hash
  Tamper detection: verify checks chain integrity, exits 1 on mismatch
- scripts/enterprise/model-card-generator.sh
  Generates AI Act model cards for all registered agents
  Auto-classifies Annex III risk (HIGH/MEDIUM/LOW)
  Output: .claude/enterprise/model-cards/{agent}.md
- scripts/enterprise/compliance-check.sh
  Validates workspace against EU AI Act, GDPR, NIS2, DORA (or all)
  Output JSON: {framework, score, checks: [{rule, passed, evidence, gap}]}

New docs:
- docs/rules/domain/enterprise-governance-protocol.md

Tests: tests/enterprise/test-se-006-governance.bats — 9/9 passing

## SPEC-SE-008 — Licensing and Distribution Strategy

New scripts:
- scripts/enterprise/license-generator.sh
  Generates MIT LICENSE.md + NOTICE.md for any component
- scripts/enterprise/commercial-terms-check.sh
  Verifies MIT present, attribution documented, no GPL/AGPL/SSPL
  Output JSON: {compliant, license_type, critical_issues, issues, checks}

New docs:
- docs/rules/domain/enterprise-licensing-policy.md
  MIT unified for all components, rejected models with rationale
  Permitted monetization (services only), dependency compatibility matrix

Tests: tests/enterprise/test-se-008-licensing.bats — 7/7 passing

## SPEC-SE-026 — Compliance Evidence Automation

New scripts:
- scripts/enterprise/compliance-evidence-collector.sh
  Harvests compliance artifacts for eu-ai-act, iso-9001, dora, nis2
  Output: output/compliance-evidence/{date}/{framework}/evidence-bundle/
  Index: output/compliance-evidence/{date}/index.json
- scripts/enterprise/compliance-report-generator.sh
  Generates auditor-ready Markdown report per framework
  Sections: Executive Summary, Findings, Evidence References, Gaps, Remediation

New docs:
- docs/rules/domain/enterprise-compliance-evidence.md
- docs/enterprise/templates/compliance-report.md

Tests: tests/enterprise/test-se-026-compliance-evidence.bats — 7/7 passing

## Summary

| Spec  | Scripts | Docs | Tests  | Status      |
|-------|---------|------|--------|-------------|
| SE-006| 3       | 1    | 9/9    | IMPLEMENTED |
| SE-008| 2       | 1    | 7/7    | IMPLEMENTED |
| SE-026| 2       | 2    | 7/7    | IMPLEMENTED |

Total: 7 scripts, 4 docs, 23 tests passing.
