---
title: Savia Superpowers — Roadmap Autónomo 2026-04-17
status: SUPERSEDED
superseded_by: ROADMAP.md
author: Savia (autonomous research + self-selection)
origin: Research interno de repos innovadores 2026 + auditoría PM
---

# Savia Superpowers — Roadmap Autónomo (SUPERSEDED)

> **SUPERSEDED 2026-04-18 — Ver `docs/propuestas/ROADMAP.md` como fuente canónica actual.**
> Este documento se mantiene por auditoría histórica. SPEC-120..124 merged en PRs #592–#594.

> Savia selecciona 5 mejoras **implementables en-repo sin infra externa** para dotarse de superpoderes PM. Esta lista es autoasignada, no ordenada por la usuaria, y todos los PRs son Draft pendientes de aprobación humana según `autonomous-safety.md`.

## Selección y racional

Del research de repos innovadores (30+ candidatos), 5 subconjuntos son 100% implementables dentro del monorepo, sin depender de instalar servicios externos. Todas son **adopciones de patrón**, no de plataforma — consistente con el principio "robar concepto, no framework".

| # | SPEC | Mejora | Origen research | Valor | Effort | Riesgo |
|---|---|---|---|---|---|---|
| 1 | SPEC-120 | **Alinear spec template con github/spec-kit** | Top pick #1 | Alto | M | Bajo |
| 2 | SPEC-121 | **Handoff-as-function convention** (OpenAI SDK) | Top pick #8 | Medio-Alto | M | Bajo |
| 3 | SPEC-122 | **LocalAI emergency-mode hardening** (Anthropic shim) | Top pick #3 | Alto | M | Bajo |
| 4 | SPEC-123 | **Graphiti temporal pattern en knowledge-graph** | Top pick #5 | Alto | M | Medio |
| 5 | SPEC-124 | **pr-agent wrapper skill + GHA template** | Top pick #2 | Alto | S | Medio |

**Omitidos conscientemente** (ver racional individual en cada spec):
- Langfuse tracing: requiere deploy self-hosted
- OpenHands worker: requiere Docker runtime
- Kuzu embedded: prototipo requiere dependency externa
- Plane backend MCP: requiere servicio self-hosted
- LangGraph checkpointing: framework Python, no TypeScript/JS

## Estrategia — bundled PRs

Siguiendo el patrón SPEC-109:

- **PR #A** — SPEC-120 spec-kit alignment
- **PR #B** — SPEC-121 handoff convention + SPEC-122 LocalAI hardening (docs + protocol)
- **PR #C** — SPEC-123 temporal pattern en knowledge-graph
- **PR #D** — SPEC-124 pr-agent wrapper + workflow template

Todos PR Draft con `AUTONOMOUS_REVIEWER = @gonzalezpazmonica` como reviewer obligatorio. Ningún merge autónomo (Rule #8, `autonomous-safety.md`).

## Orden de ejecución

Savia implementa en orden 1→5. Cada spec termina con:
1. Commit en rama `agent/autonomous-superpowers-20260417`
2. `/pr-plan` (gate Rule #25)
3. `git push`
4. PR Draft con reviewer @gonzalezpazmonica

Iteración parará cuando:
- Los 5 PRs estén abiertos, o
- Falte contexto/tokens, o
- Aparezca un bloqueador sin fix autónomo

## Seguridad

- **Rama**: `agent/autonomous-superpowers-20260417` (deriva de `main`)
- **Commits**: prefijo `agent(superpowers): ...`
- **PRs**: todos Draft, nunca merge/approve autónomo
- **Reviewer obligatorio**: @gonzalezpazmonica
- **Time-box**: 60 min por spec, abort si 3 fallos consecutivos

## Métricas

- Specs generadas: objetivo 5 / 5
- PRs abiertos: objetivo 4
- CI pass rate: objetivo 100% (bloquea push si falla)
- Cambios revertibles: 100% (solo docs + skills adicionales, ninguna modificación destructiva de core)

## Referencias

- `docs/rules/domain/autonomous-safety.md` — gates de seguridad
- `docs/propuestas/SPEC-109-savia-self-excellence.md` — patrón seguido
