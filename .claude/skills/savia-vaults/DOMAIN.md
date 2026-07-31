# SaviaVaults — Dominio

## Por que existe esta skill

Las cupulas de contexto (SaviaVaults) son el sistema de gestion de conocimiento persistente de Savia. Sin una skill operativa que guie a los agentes en la interaccion con vaults, cada agente implementaria su propio protocolo de busqueda, indexacion y federacion, generando drift entre sesiones y duplicacion de conocimiento. Esta skill centraliza el uso del CLI `vaults` y las MCP tools para operaciones rutinarias, delegando las decisiones estrategicas al agente `context-dome-manager`.

## Conceptos de dominio

- **Cupula de contexto (Dome)**: repositorio git-backed que almacena notas markdown con frontmatter y busqueda BM25
- **Federacion**: busqueda cross-dome con max 1 hop, content-hash dedup, weight system (0.1-2.0)
- **Protocolo dual**: MCP stdio (9 tools) + A2A HTTP (5 endpoints)
- **Circuit breaker**: CLOSED, OPEN, HALF_OPEN con 5 fallos consecutivos y 5min cooldown

## Reglas de negocio que implementa

- NO borrar dome sin backup previo
- NO exponer domes sensibles sin autenticacion
- NO federar en bucle (max 1 hop)
- NO modificar `.savia-vault/` a mano; usar `vaults` CLI
- NO indexar `.git` o `node_modules`

## Relacion con otras skills

- **Upstream**: context-dome (generacion de CONTEXT_DOME.md), knowledge-graph (grafo de entidades)
- **Downstream**: ubiquitous-language (glosarios indexables en domes)
- **Paralelo**: savia-memory (memoria de sesion, distinta de cupulas de documentacion)

## Decisiones clave

- Federacion read-only (nunca escribe en domes remotos)
- Degradacion graceful: domes offline se omiten, resultados locales siempre se devuelven
- Delegacion de diseno estrategico al agente `context-dome-manager` (heavy, L2)

## Especificaciones relacionadas

- SE-280: SaviaVaults Context Dome Server
- SE-281: Gap Corrections
- SE-282: Savia Federate
- SE-283: Security Hardening
- SE-284: vaults CLI
- SE-285: Skill + Agent definition
