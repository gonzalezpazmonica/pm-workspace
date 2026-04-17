---
id: SPEC-110
title: Polyglot Developer — consolidate 12 *-developer agents into 1
status: PROPOSED (deferred — high risk refactor)
origin: SPEC-109 action 8 (audit 2026-04-17)
author: Savia
---

# SPEC-110 — Polyglot Developer

## Why

Pm-workspace tiene 12 agents `*-developer` (cobol, dotnet, frontend, go, java, mobile, php, python, ruby, rust, terraform, typescript). La mayoría no se invocan activamente (8 de 12 no tienen referencias en commands/skills, solo language-packs).

Cada agent replica:
- Frontmatter (model, tools, maxTurns, context budgets)
- Identity block ("Eres desarrollador X")
- Restricciones absolutas
- Decision trees
- Success metrics

Overhead por agent: 100-200 líneas · 12 agents = ~1500-2400 líneas de duplicación.

## Scope

Crear **un único `polyglot-developer`** que:

1. Acepta parámetro `--language=<lang>` (cobol, dotnet, go, java, python, rust, ts, etc.)
2. Carga el language pack correspondiente (`@docs/rules/languages/<lang>-rules.md`)
3. Delega la SDD spec que recibe, con conocimiento del lenguaje

Deprecar los 12 agents existentes tras 2 sprints de coexistencia.

## Risks

- **ALTO**: routing de tareas actualmente asume agent específico (`dotnet-developer` invocado desde `/spec-implement`). Hay que actualizar N commands/skills para el nuevo routing.
- **MEDIO**: tests BATS que verifican existencia de agents por nombre se rompen.
- **BAJO**: agent-notes protocol puede romperse si hace asunciones sobre el agent-id.

## Plan (no implementado en esta sesión)

1. Crear `polyglot-developer.md` con frontmatter + dispatch a language pack
2. Actualizar `/spec-implement` y 3-4 commands clave para usar `polyglot-developer --language=X`
3. Mantener los 12 agents existentes 2 sprints como deprecated (frontmatter `deprecated: true, replaced_by: polyglot-developer`)
4. Tests BATS migrados
5. Documentación actualizada (agents-catalog, README)
6. Tras 2 sprints sin uso → eliminar los 12

## Acceptance criteria

1. Un único agent `polyglot-developer` funciona para los 12 lenguajes actuales
2. Delta de tokens de contexto medido: reducción ≥30% en sesiones que activaban 1 language developer
3. Tests BATS pasan
4. No se rompe `/spec-implement` ni ningún workflow SDD existente

## Deferral rationale

Refactor de alto riesgo — 12 agents con N consumidores cada uno. Mejor ejecutar cuando:
- Sprint completo disponible (no interrumpir otros trabajos)
- Tests de integración SDD estables
- Plan de rollback validado en sandbox

SPEC-109 (audit remediation) lo deja como spec-only. Implementación futura decidida por humano.
