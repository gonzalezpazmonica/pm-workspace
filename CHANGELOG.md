# Changelog — pm-workspace

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.48.0] — 2026-03-07

### Added — Era 77: Postmortem Training Template

Postmortem process focused on reasoning heuristics, not just root cause. Trains engineers to diagnose faster by documenting the journey to diagnosis.

- **`/postmortem-create {incident}`** — Guided postmortem: timeline, diagnosis journey, heuristic extraction, comprehension gap analysis. Plantilla obligatoria con 7 secciones.
- **`/postmortem-review [incident-id]`** — Review postmortems, extract patterns and recurring gaps. Análisis de patrones históricos.
- **`/postmortem-heuristics [module]`** — Compile "if X, check Y" debugging playbook from all postmortems. Deduplicación automática.
- **`postmortem-training` skill** — 7-section template, integration with comprehension reports, heuristic database. Enfoque en viaje diagnóstico vs solo causa raíz.
- **`postmortem-policy` rule** — Mandatory for MTTR>30min. Template required. Heuristic extraction required. Comprehension gap analysis required.

### Changed

- Énfasis en Diagnosis Journey (paso a paso del razonamiento) en lugar de resumen ejecutivo.

## [2.47.0] — 2026-03-07

### Added — Era 76: Templates for Non-Engineers

Guided interfaces for POs, stakeholders, and QA. Simplified wizards, plain language, no technical jargon required.

- **`/po-wizard {action}`** — PO interface: plan-sprint, prioritize, acceptance-criteria, review.
- **`/stakeholder-view {view}`** — Executive dashboard: summary, milestones, risks, budget.
- **`/qa-wizard {action}`** — QA interface: test-plan, bug-report, validate, regression.
- **`non-engineer-templates` skill** — 3 personas, 6 templates, step-by-step guided flows.

## [2.46.0] — 2026-03-07

### Added — Era 75: Semantic Memory Layer

Vector-based similarity search over project memory. Three memory layers: session (ephemeral), project (JSONL), semantic (vector index).

- **`/memory-search {query}`** — Natural language search over indexed memories. Top-5 results with relevance scores.
- **`/memory-index {project}`** — Build/rebuild semantic vector index from agent-notes, lessons, decisions, postmortems.
- **`/memory-stats {project}`** — Index statistics: entry count, last updated, coverage per source.
- **`semantic-memory` skill** — Lightweight JSON vector store, embedding-based search, incremental updates.

## [2.44.0] — 2026-03-07

### Added — Era 73: PM-Workspace as MCP Server

Expose project state as MCP server. External tools can query projects, tasks, metrics and trigger PM operations.

- **`/mcp-server-start {mode}`** — Start MCP server: local (stdio) or remote (SSE). Optional `--read-only`.
- **`/mcp-server-status`** — Server status: connections, requests, uptime.
- **`/mcp-server-config`** — Configure exposed resources, tools, and prompts.
- **`pm-mcp-server` skill** — 6 resources, 4 tools, 3 prompts. Token auth for remote, read-only mode.

## [2.35.0] — 2026-03-07

### Added — Era 64: Verification Lattice

5-layer verification pipeline: deterministic → semantic → security → agentic → human. Each layer informs the next, culminating in a human review enriched by automated analysis.

- **`/verify-full {task-id}`** — Run all 5 verification layers. Progressive results, stop on critical failure.
- **`/verify-layer {N} {task-id}`** — Run specific layer for debugging.
- **`verification-lattice` skill** — 5 layers with dedicated agents: scripts (L1), code-reviewer (L2), security-reviewer (L3), architect (L4), human (L5).
- **`verification-policy` rule** — Layers 1-3 mandatory, L4 for risk>50, L5 always except risk<25. Auto-retry for automated layers.

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

[2.48.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.47.0...v2.48.0
[2.47.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.46.0...v2.47.0
[2.46.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.44.0...v2.46.0
[2.44.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.35.0...v2.44.0
[2.35.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.34.0...v2.35.0
[2.34.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.33.0...v2.34.0
[2.33.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.32.0...v2.33.0
