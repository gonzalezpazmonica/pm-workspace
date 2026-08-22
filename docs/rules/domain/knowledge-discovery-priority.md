---
context_tier: L1
token_budget: 300
spec: SE-335
---

# Prioridad de descubrimiento de conocimiento

> SE-335. Cargada eager en el arranque de ambos frontends. Orden imperativo, no intención.

Al resolver una pregunta de conocimiento, consultar SIEMPRE en este orden y no saltar:

1. **Cúpulas de conocimiento (SaviaVaults MCP)**: `vault_search`, `vault_read`, `vault_graph`.
   Domos: savia-docs (reglas, specs, decisiones), SaviaLearning (lecciones), SaviaLabs (experimentos).
2. **Capas de memoria**: `~/.savia-memory/auto/MEMORY.md` + `bash scripts/memory-store.sh recall`.
3. **Grafo de código**: codebase-memory (`search_graph`/`trace_path`) o codegraph.
4. **Grep/glob a ficheros**: SOLO último recurso — literales, config, no-código, o cuando 1-3 no cubren el caso.

**Regla**: si empiezas por grep sin haber consultado 1-3, estás saltando el orden.
