# Changelog — pm-workspace

## [2.46.0] — 2026-03-07

### Added — Era 75: Semantic Memory Layer

Vector-based similarity search over project memory. Three memory layers: session (ephemeral), project (JSONL), semantic (vector index).

- **`/memory-search {query}`** — Natural language search over indexed memories. Top-5 results with relevance scores.
- **`/memory-index {project}`** — Build/rebuild semantic vector index from agent-notes, lessons, decisions, postmortems.
- **`/memory-stats {project}`** — Index statistics: entry count, last updated, coverage per source.
- **`semantic-memory` skill** — Lightweight JSON vector store, embedding-based search, incremental updates.

---



> Seguimiento de releases, features, fixes y documentación.
> Formato: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## [2.47.0] — 2026-03-07

### Added — Era 76: Templates for Non-Engineers

Guided interfaces for POs, stakeholders, and QA. Simplified wizards, plain language, no technical jargon required.

- **`/po-wizard {action}`** — PO interface: plan-sprint, prioritize, acceptance-criteria, review.
- **`/stakeholder-view {view}`** — Executive dashboard: summary, milestones, risks, budget.
- **`/qa-wizard {action}`** — QA interface: test-plan, bug-report, validate, regression.
- **`non-engineer-templates` skill** — 3 personas, 6 templates, step-by-step guided flows.

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

## [2.44.0] — 2026-03-07

### Added — Era 73: PM-Workspace as MCP Server

Expose project state as MCP server. External tools can query projects, tasks, metrics and trigger PM operations.

- **`/mcp-server-start {mode}`** — Start MCP server: local (stdio) or remote (SSE). Optional `--read-only`.
- **`/mcp-server-status`** — Server status: connections, requests, uptime.
- **`/mcp-server-config`** — Configure exposed resources, tools, and prompts.
- **`pm-mcp-server` skill** — 6 resources, 4 tools, 3 prompts. Token auth for remote, read-only mode.
