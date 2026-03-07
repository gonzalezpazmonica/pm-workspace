# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.34.0] — 2026-03-07

### Added — Era 63: Risk Scoring & Intelligent Escalation

Risk-based review routing replaces fixed Code Review rules. Automatic score calculation (0-100) with 4 review levels: auto-merge, standard, enhanced, and full review.

- **`/risk-assess {task-id}`** — Calculate risk score with factor breakdown. Recommends review level and suggests reviewers.
- **`/risk-policy`** — View and update risk scoring thresholds per project.
- **`risk-scoring` skill** — 4-phase pipeline: collect signals → calculate score → route review → generate report.
- **`risk-escalation` rule** — Configurable thresholds, PM override, audit trail, Code Review E1 integration.

### Skills
- **risk-scoring** (4-phase risk assessment pipeline with 8 weighted factors)
- **risk-scoring/DOMAIN.md** (business rules and domain concepts)

### Commands
- **risk-assess** (calculate and display risk score with breakdown)
- **risk-policy** (view and manage risk thresholds)

### Rules
- **risk-escalation** (4-tier review routing based on score)

### Technical Details
- File count weighting (1-3: 0pts, 4-8: +10, 9+: +25)
- Module criticality (auth/payment/data: +30, core business: +20, UI/docs: +5)
- External dependencies (new service: +20, API change: +10)
- Security factors (OWASP patterns: +25, PII handling: +20)
- Compliance factors (GDPR/AEPD: +15, regulatory: +20)
- Data impact (schema migration: +20, prod data touch: +25)
- Historical signals (incidents: +15, first-time contributor: +10)
- SLA by level: auto-merge 24h, standard 24h, enhanced 48h, critical 72h

---

## [2.33.0] — 2026-02-28

### Added

- Placeholder for previous release notes

[2.34.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.33.0...v2.34.0
[2.33.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.32.0...v2.33.0
