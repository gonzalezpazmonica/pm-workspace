---
id: SE-223
title: codebase-memory-mcp como backend del Code Twin system
status: IMPLEMENTED
priority: P1
effort: M (6h)
origin: Research 2026-06-24 — github.com/DeusData/codebase-memory-mcp (13k stars, arXiv 2603.27277)
author: Savia
applied_at: "2026-06-24"
era: 235
---

# SE-223 — codebase-memory-mcp Code Twin backend

## Resultado

Instalado y operativo. 35.652 nodos, 59.031 edges indexados en 3.1s.
Queries estructurales en 10-21ms. GO confirmado (criterio: ≤5k tokens para 5 preguntas).

## Slices implementados

### Slice 1 (DONE) — Instalación y smoke test

- Binario instalado: ~/.local/bin/codebase-memory-mcp v0.8.1
- MCP registrado: ~/.config/opencode/opencode.json
- Index: bash -c "codebase-memory-mcp cli index_repository '{"repo_path": "$PWD"}'"
- 5 queries de referencia < 25ms cada una
- 13/13 BATS tests: tests/test-se223-codebase-memory-mcp.bats

### Slice 2 (DONE) — Integración en code-twin-agent

- .opencode/agents/code-twin-agent.md actualizado
- Protocolo MCP primario: search_graph, trace_path, get_code_snippet, query_graph
- Protocolo CTF como fallback si MCP no disponible
- Tamaño: 2133 bytes (< 4096 SLA)

## Métricas

- Tokens para 5 preguntas estructurales: ~3.4k (vs >400k con grep/Read)
- Reducción: 120x (confirmado según arXiv 2603.27277)
- Index: 35652 nodos, 59031 edges, 2742 ficheros, 3.1s cold
- Latencia queries: 10-21ms p50

## Notas operacionales

El índice persiste en ~/.cache/codebase-memory-mcp/. Se auto-sincroniza
al detectar cambios en el repo. Re-indexar manualmente:
  codebase-memory-mcp cli index_repository '{"repo_path": "/home/monica/savia"}'
