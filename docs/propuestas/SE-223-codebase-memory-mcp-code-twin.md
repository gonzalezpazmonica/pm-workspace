---
id: SE-223
title: codebase-memory-mcp como backend del Code Twin system
status: IMPLEMENTED
priority: P1
effort: M (6h)
origin: Research 2026-06-24 — github.com/DeusData/codebase-memory-mcp (13k stars, arXiv 2603.27277)
author: Savia
related: code-twin-agent, scripts/code-twin-load.sh, SE-162 (knowledge-graph)
proposed_at: "2026-06-24"
resolved_at: "2026-07-02"
era: 235
---

# SE-223 — codebase-memory-mcp como backend del Code Twin system

## Problema

El Code Twin system actual (`code-twin-agent`, `scripts/code-twin-load.sh`) carga ASTs en contexto mediante ficheros temporales. Cada consulta estructural ("¿qué llama a `ProcessOrder`?", "¿qué endpoints expone `PaymentService`?") dispara un bucle de grep+Read en cascada. Resultado: 400k+ tokens para responder 5 preguntas estructurales que un índice persistente respondería con 3.4k tokens.

Cost of inaction: a medida que los proyectos crecen (trazabios, dotnet-microservices-home-lab), el Code Twin se vuelve inutilizable por coste de tokens. El cold-start del índice vectorial (15-30s) penaliza cada sesión.

## Tesis

Adoptar `codebase-memory-mcp` (MIT, binario estático Linux x64/arm64, tree-sitter + Hybrid LSP + SQLite WAL) como servidor MCP que reemplaza la lógica de `code-twin-load.sh`. Resultado medido en 31 repos reales: **120x reducción de tokens**, 83% answer quality, 2.1x menos tool calls.

El Code Twin agent pasa de "carga ASTs en contexto" a "consulta MCP server vía 14 herramientas especializadas".

## Objetivo

Instalar `codebase-memory-mcp` como MCP server en pm-workspace, registrarlo en `.opencode/opencode.json`, y redirigir las consultas del `code-twin-agent` a las 14 herramientas MCP. Criterio de éxito: 5 preguntas estructurales de referencia respondidas con ≤5k tokens (baseline actual: >400k).

## Diseño

### Instalación

```bash
# Un solo comando (MIT, binario precompilado)
curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash
# Registra automáticamente en ~/.config/opencode/ y .opencode/
```

### Herramientas MCP disponibles (selección relevante para Savia)

| Tool | Uso en Savia |
|---|---|
| `search_graph` | Equivale a grep+Read: "¿dónde se usa X?" |
| `trace_path` | Call chain BFS depth 1-5: callers/callees |
| `semantic_query` | Búsqueda por concepto: "servicios de autenticación" |
| `detect_changes` | git diff → blast radius → input para CRC |
| `manage_adr` | ADRs como ciudadanos de primera clase (con status lifecycle) |
| `get_file_context` | Sustituto de code-twin-load.sh para ficheros individuales |

### Integración con Code Twin agent

```markdown
# En code-twin-agent prompt (diff mínimo):
Antes: "carga twin.md y AST del fichero relevante"
Después: "usa la tool search_graph o semantic_query del MCP codebase-memory"
```

### detect_changes para CRC

Antes de invocar al Code Review Court: `detect_changes(diff=git_diff_uncommitted)` devuelve mapa de símbolos afectados + clasificación de riesgo. Los jueces reciben este input directamente en vez de hacer grep manual.

## Slices

### Slice 1 — Instalación y smoke test (S, 1.5h)

- Instalar binario via script oficial
- Registrar en `.opencode/opencode.json` como MCP server
- Indexar pm-workspace: `codebase-memory index .`
- Smoke test: 5 preguntas de referencia + medir tokens antes/después
- Criterio GO/NO-GO: reducción ≥10x tokens para preguntas estructurales

### Slice 2 — Integrar en code-twin-agent (M, 3h)

- Actualizar prompt de `code-twin-agent` para usar las 14 tools MCP
- Deprecar `code-twin-load.sh` (mantener como fallback, no invocar por defecto)
- Añadir `detect_changes` como step previo en `court-orchestrator`
- BATS: verificar indexación automática on file change

### Slice 3 — ADR upgrade en memory-store (S, 1.5h)

- Adoptar schema ADR de `manage_adr`: campos `status` (proposed/accepted/deprecated/superseded), `context`, `consequences`
- Migrar entradas tipo `decision` relevantes al nuevo schema
- Documentar en `docs/memory-system.md`

## Risks

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| Binario no compatible con distro | Baja | Binario estático, probado en Ubuntu 22.04+ |
| Índice desactualizado | Media | Auto-sync watcher en background + `codebase-memory sync` en hook PostToolUse |
| Port conflicto MCP | Baja | Puerto configurable en `.opencode/opencode.json` |

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| MCP server | N/A | Registrado en `.opencode/opencode.json` `mcpServers` |
| code-twin-agent | `.opencode/agents/code-twin-agent.md` | Lee desde AGENTS.md |
| court-orchestrator | `.opencode/agents/court-orchestrator.md` | Invoca `detect_changes` tool |

### Portability classification

- [x] **DUAL_BINDING**: MCP es nativo en OpenCode. Claude Code accede via bash wrapper si necesario.
