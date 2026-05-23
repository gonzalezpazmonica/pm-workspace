---
spec_id: SPEC-144
title: /speckit.* slash command aliases — compatibilidad cross-tool con github/spec-kit
status: IMPLEMENTED
implementation_pr: 766
implementation_date: "2026-05-23"
slices_done: "1"
origin: Investigación 2026-05-23 (P6). github/spec-kit (>100k stars, MIT) es estándar de facto para SDD. SPEC-120 ya alineó el template; faltan los slash commands para que cualquiera que conozca spec-kit pueda usar Savia sin re-aprender.
severity: Media — DX externa, adopción comunitaria.
effort: ~4h (S) — 8 ficheros de redirección + tests.
priority: P6 — multiplicador de adopción.
confidence: alta
bucket: Q2 2026
related_specs:
  - SPEC-120 (spec-kit template alignment — IMPLEMENTED 2026-04-24; este spec completa la cara externa)
---

# SPEC-144 — /speckit.* Slash Command Aliases

## Why

`github/spec-kit` define una serie estable de slash commands que ya son tribal knowledge:

- `/speckit.constitution` — declara principios inmutables.
- `/speckit.specify` — captura el "what" inicial.
- `/speckit.clarify` — preguntas dirigidas para cerrar ambigüedad.
- `/speckit.plan` — diseño técnico.
- `/speckit.tasks` — descomposición en tasks.
- `/speckit.analyze` — review cruzado.
- `/speckit.implement` — ejecución.
- `/speckit.checklist` — gate de calidad.

Savia ya tiene SDD propio con flujos equivalentes (skills `spec-driven-development`, `product-discovery`, `pbi-decomposition`, `consensus-validation`, `verification-lattice`). Pero los nombres difieren — alguien que llega de spec-kit no encuentra puerta de entrada y abandona o duplica trabajo.

Crear 8 slash commands en `.claude/commands/speckit.*.md` que delegan al flujo Savia existente reduce fricción de adopción y publicita explícitamente la compatibilidad. Sin cambiar nada bajo el capó.

## Scope

### Funcional

Crear 8 comandos delgados (≤30 líneas cada uno) en `.claude/commands/`:

| Comando spec-kit | Delegación Savia |
|---|---|
| `/speckit.constitution` | invoca skill `savia-identity` con args para constituir un proyecto |
| `/speckit.specify $args` | invoca skill `product-discovery` |
| `/speckit.clarify $args` | invoca skill `context-interview-conductor` |
| `/speckit.plan $args` | invoca skill `spec-driven-development` (sección Plan) |
| `/speckit.tasks $args` | invoca skill `pbi-decomposition` |
| `/speckit.analyze $args` | invoca skill `consensus-validation` |
| `/speckit.implement $args` | invoca agentes SDD (`dev-orchestrator`) |
| `/speckit.checklist $args` | invoca skill `verification-lattice` |

Cada comando:
- Frontmatter mínimo: `name`, `description` (cita spec-kit como referencia).
- Banner que indica equivalencia: "Este comando es alias de spec-kit → invoca [skill X de Savia]".
- Pass-through de `$ARGUMENTS` al skill.

### No funcional

- Cero duplicación de lógica — todo es delegación.
- Tests BATS verifican que invocar `/speckit.constitution` produce el mismo efecto que llamar el skill directo.
- Documentar en `docs/agent-teams-sdd.md` la tabla de equivalencias.

## Design

### Estructura

```
.claude/commands/
├── speckit.constitution.md
├── speckit.specify.md
├── speckit.clarify.md
├── speckit.plan.md
├── speckit.tasks.md
├── speckit.analyze.md
├── speckit.implement.md
└── speckit.checklist.md

tests/
└── test-speckit-aliases.bats

docs/
└── agent-teams-sdd.md   # añadir tabla equivalencias spec-kit ↔ Savia
```

### Ejemplo `speckit.specify.md`

```markdown
---
name: speckit.specify
description: Alias spec-kit compatible. Captura el "what" inicial de una spec. Invoca skill product-discovery de Savia.
---

# /speckit.specify

> Alias compatible con github/spec-kit. Equivalente Savia: skill `product-discovery`.

**Argumentos:** `$ARGUMENTS` (descripción inicial del feature/PBI)

## Ejecución

Este comando delega en la skill `product-discovery` que ya implementa el flujo JTBD + PRD:

1. Lee `$ARGUMENTS` como brief inicial.
2. Si vacío → entrevista interactiva.
3. Output: borrador de spec en `output/specs/draft-{slug}-{date}.md`.

Equivalencia confirmada con spec-kit en `docs/agent-teams-sdd.md`.
```

## Acceptance Criteria

- [ ] AC-01: 8 ficheros creados en `.claude/commands/speckit.*.md`, frontmatter mínimo, ≤30 líneas cada uno.
- [ ] AC-02: Cada comando invoca correctamente la skill equivalente con `$ARGUMENTS` propagado.
- [ ] AC-03: Tabla de equivalencias en `docs/agent-teams-sdd.md`.
- [ ] AC-04: README.md y README.en.md mencionan compatibilidad spec-kit (Rule #12).
- [ ] AC-05: BATS test `tests/test-speckit-aliases.bats` cubre los 8 comandos.
- [ ] AC-06: `/help speckit` lista los 8 (smart-routing skill ya los descubre por convención).

## Agent Assignment

- **Capa**: Application
- **Agente**: `dev-orchestrator` (creación) + `tech-writer` (docs)
- **Skills**: `smart-routing`, `spec-driven-development`

## Slicing

- **Slice 1** (2h) — Los 8 comandos como redirecciones simples.
- **Slice 2** (1h) — Tabla de equivalencias + actualización READMEs.
- **Slice 3** (1h) — Tests BATS + verificación con `/help`.

## Feasibility Probe

No requiere — son aliases puros. Si en Slice 1 alguna skill destino no acepta el modo de invocación necesario, se documenta gap y se itera sobre la skill, no sobre el alias.

## Riesgos

- **Drift con spec-kit upstream**: si spec-kit renombra/elimina un comando, los aliases quedan dangling. Mitigación — watcher mensual SPEC-146 vigila releases de github/spec-kit.
- **Confusión con SDD propio**: alguien podría pensar que `/speckit.*` y skills nativas son sistemas distintos. Mitigación — banner explícito en cada alias y tabla canónica en docs.
