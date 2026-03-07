# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.39.0] — 2026-03-07

### Added — Era 68: Google Sheets Tracker

Google Sheets as lightweight task database for POs and stakeholders. Bidirectional sync with Azure DevOps, sprint metrics, risk tracking.

- **`/sheets-setup {project}`** — Create tracking spreadsheet with Tasks, Metrics, and Risks sheets.
- **`/sheets-sync {project} push|pull|both`** — Bidirectional sync between Azure DevOps and Sheets.
- **`/sheets-report {project}`** — Generate sprint metrics from task data.
- **`google-sheets-tracker` skill** — 3-sheet structure, bidirectional sync, MCP integration.

---

## [2.38.0] — 2026-03-07

### Added — Era 67: Resource References (@)

Referenciable resources with @ notation for automatic context inclusion. Lazy resolution, session caching, 6 resource types.

- **`/ref-list {project}`** — List available resource references with patterns and examples.
- **`/ref-resolve {reference}`** — Manually resolve and preview a resource reference.
- **`resource-references` skill** — 6 resource types: @azure:workitem, @project, @spec, @team, @rules, @memory. Lazy loading.
- **`resource-resolution` rule** — Lazy resolution, session cache, max 5 simultaneous, approved sources only.

---

## [2.37.0] — 2026-03-07

### Added — Era 66: Headroom Context Optimization

Token compression framework achieving 47-92% reduction. Context budgets per operation, automatic compression before agent invocation.

- **`/headroom-analyze {project}`** — Analyze token usage per context block with compression opportunities.
- **`/headroom-apply {project}`** — Apply compressions. Preview default, `--apply` to persist changes.
- **`headroom-optimization` skill** — 5-phase compression framework.
- **`context-budget` rule** — Max token budgets per operation type.

---

[2.39.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.38.0...v2.39.0
[2.38.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.37.0...v2.38.0
[2.37.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.36.0...v2.37.0
