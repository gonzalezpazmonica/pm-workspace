---
id: SE-083
title: SE-083 — TDD vertical-slice skill (anti-horizontal-slicing reinforcement)
status: APPROVED
origin: mattpocock/skills/tdd (MIT) — análisis 2026-04-27
author: Savia
priority: media
effort: S 2h
related: test-engineer agent, test-architect agent, test-runner agent
approved_at: "2026-04-27"
applied_at: null
expires: "2026-06-27"
era: 190
---

# SE-083 — TDD vertical-slice skill

## Why

pm-workspace tiene tres agentes para tests (`test-architect`, `test-engineer`, `test-runner`) pero ninguno enuncia explícitamente el **anti-pattern de horizontal slicing** que Pocock identifica:

> "DO NOT write all tests first, then all implementation. This produces crap tests — they test imagined behavior, the shape of things rather than user-facing behavior, and become insensitive to real changes."

El error es real y reincidente: cuando un agente Claude recibe una spec con N acceptance criteria, la tendencia natural es escribir N tests en bloque antes de implementar. Resultado: tests que verifican estructuras de datos en vez de comportamiento, brittle a refactor.

Pocock corrige con vertical slicing tracer-bullet: `RED → GREEN` por behavior individual. Es disciplina simple, demostrable, y no requiere infra nueva — sólo un skill SKILL.md ≤120 LOC que los agentes invocan cuando aplican TDD.

Coste de no adoptar: el patrón sigue produciendo "crap tests" cuando los agentes aplican TDD nominalmente. Coste de adoptar: ~120 LOC de markdown + 1 cross-reference desde test-architect.

## Scope (Slice único, S 2h)

### 1. `.opencode/skills/tdd-vertical-slices/SKILL.md` (clean-room, ≤120 LOC)

Contiene:

- **Core principle**: tests verify behavior through public interfaces, not implementation
- **Anti-pattern explícito**: horizontal slicing produce crap tests — explicación causal
- **Vertical pattern**: tracer bullet (1 test → 1 impl), incremental loop, refactor sólo en GREEN
- **Per-cycle checklist** (5 ítems): test describes behavior / uses public interface / would survive refactor / minimal code / no speculative features
- **Trigger**: usuaria/agente menciona TDD, "red-green-refactor", test-first, vertical slice, "unit test" + features nuevas

Atribución MIT a `mattpocock/skills/tdd/SKILL.md` en header. Clean-room — la disciplina es universal pero la prosa es propia.

### 2. Cross-reference desde test-architect

`.opencode/agents/test-architect.md` — añadir 1 línea en sección de proceso: "When applying TDD, use `.opencode/skills/tdd-vertical-slices/SKILL.md` — vertical slicing only, never horizontal."

(test-engineer y test-runner son ejecutores; el discípulo de TDD es test-architect.)

### 3. Tests BATS estáticos

- SKILL.md existe, ≤150 LOC, frontmatter válido
- Anti-pattern de horizontal slicing está nombrado explícitamente
- Cross-reference en test-architect existe

## Acceptance criteria

- [ ] AC-01 `.opencode/skills/tdd-vertical-slices/SKILL.md` ≤120 LOC con frontmatter `name`, `description` que incluya "Use when ..."
- [ ] AC-02 Anti-pattern de horizontal slicing nombrado explícitamente con "DO NOT" o equivalente
- [ ] AC-03 Atribución MIT a Pocock en header (clean-room — verificable por diff manual)
- [ ] AC-04 Cross-reference añadida en `test-architect.md`
- [ ] AC-05 Tests BATS ≥8 estáticos (file exists, frontmatter, anti-pattern present, attribution, cross-ref)
- [ ] AC-06 CHANGELOG fragment

## No hace

- NO modifica `test-engineer.md` ni `test-runner.md` — son ejecutores, no discípulos
- NO añade un nuevo agente — disciplina es invocable como skill
- NO sustituye el flujo SDD existente — TDD es complementario, aplicado dentro de un slice ya specced
- NO impone TDD universal — sigue siendo opcional según naturaleza del slice (specs sin behavior testable: docs, configs, no aplica)

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Skill ignorado por test-architect en práctica | Media | Bajo | Cross-ref explícita; SE-084 audit detecta SKILL.md no referenciado |
| Choque con tests BATS estáticos del workspace (que sí son "horizontales" — verifican muchos files) | Media | Bajo | Skill aclara: aplica a TDD de behavior nuevo, NO a structure-tests existentes |

## Dependencias

- ✅ test-architect agent existe
- ✅ `.opencode/skills/` directory existe
- Sin bloqueantes externos. Independiente de SE-081/SE-082/SE-084.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| SKILL.md | `.opencode/skills/tdd-vertical-slices/SKILL.md` | autoload via AGENTS.md regen |
| Agent ref | `.opencode/agents/test-architect.md` | regen via SE-078 |

### Verification protocol

- [ ] AGENTS.md regen pasa drift check
- [ ] Smoke: invocar skill desde OpenCode v1.14 — debe cargar igual

### Portability classification

- [x] **PURE_DOCS**: markdown puro. Cross-frontend trivial.

## Referencias

- `mattpocock/skills/tdd/SKILL.md` — fuente del anti-pattern
- Kent Beck "Test-Driven Development By Example" — origen del red-green-refactor
- pm-workspace `test-architect` agent — discípulo natural
