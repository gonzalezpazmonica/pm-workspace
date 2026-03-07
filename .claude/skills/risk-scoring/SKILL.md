---
name: risk-scoring
description: Calculate risk score for tasks and route to appropriate review level
context: fork
agent: architect
---

# Risk Scoring for Intelligent Escalation

Automated 4-phase pipeline to assess task complexity and route code reviews to appropriate escalation levels based on risk factors, replacing fixed Code Review rules with intelligent, data-driven routing.

## Phase 1: Collect Risk Signals

Extract risk indicators from task metadata: files touched, modules affected, external dependencies, security tags, compliance tags, data migration, production impact, change history.

## Phase 2: Calculate Risk Score (0-100)

Weighted scoring system across 8 dimensions: file count, module criticality, external dependencies, security, compliance, data impact, historical signals.

## Phase 3: Route to Review Level

Four-tier escalation based on score:
- Low (0-25): Auto-merge + spot-check
- Medium (26-50): Standard Code Review E1
- High (51-75): Enhanced Review with 2 reviewers
- Critical (76-100): Full Review with security + PM approval

## Phase 4: Generate Risk Report

Comprehensive breakdown with score, factor breakdown, review requirements, suggested reviewers, timeline, and mitigations.

## Integration Points

- Code Review E1: Risk score displayed in request
- Escalation Rule: Automatic routing based on thresholds
- Audit Trail: All decisions logged
- PM Override: Can manually adjust escalation level
