# Changelog — pm-workspace

## [2.44.0] — 2026-03-07

### Added — Era 73: PM-Workspace as MCP Server

Expose project state as MCP server. External tools can query projects, tasks, metrics and trigger PM operations.

- **`/mcp-server-start {mode}`** — Start MCP server: local (stdio) or remote (SSE). Optional `--read-only`.
- **`/mcp-server-status`** — Server status: connections, requests, uptime.
- **`/mcp-server-config`** — Configure exposed resources, tools, and prompts.
- **`pm-mcp-server` skill** — 6 resources, 4 tools, 3 prompts. Token auth for remote, read-only mode.

---


All notable changes to pm-workspace are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## [2.43.0] — 2026-03-07

Descripción: Era 72 — Agent Skills Marketplace

Publica, descubre e instala habilidades de PM en formato estándar. Marketplace local con descobrimiento basado en categorías.

### Added — Era 72: Agent Skills Marketplace

- **`/marketplace-publish {skill}`** — Empaqueta, valida y publica una habilidad a registry local.
- **`/marketplace-search {query}`** — Busca skills por palabra clave, categoría (planning, development, testing, operations, reporting, compliance, communication) o tag.
- **`/marketplace-install {skill}`** — Descarga, valida e integra skill con resolución automática de dependencias.
- **`skills-marketplace` skill** — Pipeline completa de packaging: SKILL.md + DOMAIN.md + references/ + metadata.json. Validaciones estructurales, límites de líneas, PII-free, compatibilidad. Registry local en `data/marketplace/registry.json`.

### Metadata Standard

```json
{
  "name": "skill-name",
  "version": "1.0.0",
  "author": "author-name",
  "category": "planning|development|testing|operations|reporting|compliance|communication",
  "tags": ["tag1", "tag2"],
  "description": "Breve descripción",
  "dependencies": ["skill1"],
  "compatibility": ">=2.0.0",
  "license": "MIT",
  "repository": "https://github.com/user/repo"
}
```

### Categorías de Habilidades

- **planning** — Planificación, roadmaps, sprints
- **development** — Codificación, arquitectura, refactoring
- **testing** — QA, test cases, coverage
- **operations** — Deployment, monitoring, SRE
- **reporting** — Dashboards, analytics, insights
- **compliance** — Auditoría, seguridad, regulación
- **communication** — Documentación, presentaciones, feedback

### Registry Local

Ubicación: `data/marketplace/registry.json`

Estructura por skill: name, version, category, installed (boolean), installed_version (si aplica), path, published_at (timestamp ISO).

### Comandos Agregados

- Total de comandos: 102 (antes: 99)
- Comandos marketplace: 3 nuevos
- Categoría communication extendida

[2.43.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.42.0...v2.43.0
[2.42.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.41.0...v2.42.0
[2.41.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v2.40.0...v2.41.0
