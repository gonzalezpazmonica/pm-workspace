---
id: SPEC-126
title: SPEC-126 — Polyglot Developer (renumbered from SPEC-110) — consolidate 12 *-developer agents into 1
status: REJECTED
origin: SPEC-109 action 8 (audit 2026-04-17)
author: Savia
---

# SPEC-126 — Polyglot Developer (REJECTED)

## Why this was proposed

Pm-workspace tiene 12 agents `*-developer` (cobol, dotnet, frontend, go, java, mobile, php, python, ruby, rust, terraform, typescript), totalizando ~1423 líneas con aparente duplicación de frontmatter, identity blocks, restricciones y decision trees.

Aparente overhead: ~1500 líneas de "boilerplate repetido".

## Why it was rejected

Tras analizar la estructura real:

### 1. "Duplicación" es expertise específico por lenguaje
Cada agent tiene:
- Convenciones de naming específicas (PascalCase Go vs camelCase JS)
- Comandos de verificación pre-implementación (`go build ./...` vs `dotnet build`)
- Linters y frameworks propios (`golangci-lint` vs `eslint` vs `ruff`)
- Patrones de error handling específicos (Go explicit returns vs Java try-catch)

Esto NO es duplicación — es expertise que debe mantenerse discreto para que el LLM active el contexto correcto.

### 2. Un único agent polyglot degrada el contexto
Agent actual: Go-developer carga ~107 líneas específicas de Go.
Agent polyglot: cargaría las 12 secciones (~1423 líneas) cada vez que se invoca, incluso para una task simple de Python.

Penalty: ~13× más tokens de prompt system por invocación. Opus 4.7 rinde mejor con contextos focalizados, no diluídos.

### 3. Routing por nombre es arquitectura, no deuda
`/spec-implement` routes a `{language}-developer` basado en la spec. Un dispatch centralizado en un único agent requeriría:
- Branching lógico dentro del prompt (fragil con LLMs)
- O un pre-router externo que haga el mismo trabajo que el routing actual

Ganancia: 0. Complejidad: alta.

### 4. Las ~1500 líneas "duplicadas" son 100-200 por agent
Cada agent tiene 100-150 líneas. El "duplicación" percibida (frontmatter, restricciones genéricas) es ~20 líneas. 12 × 20 = 240 líneas de redundancia real, no 1500.

Solution alternativa: extraer ese boilerplate a `@docs/rules/domain/developer-agent-core.md` importado por cada agent (ya existe parcialmente vía `@docs/rules/languages/<lang>-rules.md`).

## Decision

**REJECTED** el refactor de consolidación.

**ACCEPTED** como alternativa de menor alcance:
- Extraer el boilerplate común (restricciones, identity block genérico) a un fragmento importado por todos los `*-developer` agents.
- Mantener los 12 agents específicos.
- Ahorro estimado: ~200 líneas, sin degradar contexto por invocación.

Esto se tratará en una futura spec si el ahorro justifica el trabajo. Actualmente no es prioritario.

## Lessons

1. **"Duplicación" aparente puede ser expertise discreto.** Medir antes de consolidar.
2. **Agent-per-domain es un patrón válido.** No todos los prompts deben ser DRY.
3. **Context efficiency > code reuse** cuando el consumidor es un LLM.

## Deferral rationale (original, ahora superado)

~~Refactor de alto riesgo — ejecutar cuando sprint completo disponible.~~

Tras análisis: no es solo "alto riesgo", es **diseño incorrecto**. Se cierra sin implementar.
