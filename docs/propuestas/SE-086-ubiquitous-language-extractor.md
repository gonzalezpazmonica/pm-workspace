---
id: SE-086
title: SE-086 — Ubiquitous-language extractor (DDD glossary from conversations + memory-graph)
status: APPROVED
origin: mattpocock/skills/ubiquitous-language + domain-model (MIT) — análisis 2026-04-27
author: Savia
priority: media
effort: M 5h
related: SPEC-027 memory-graph, SE-076 episodic memory, SE-082 architectural-vocabulary
approved_at: "2026-04-27"
applied_at: null
expires: "2026-06-27"
era: 190
---

# SE-086 — Ubiquitous-language extractor

## Why

Cada proyecto tiene términos de dominio propios (en SaviaFlow: "spec", "slice", "Era", "AC"; en Voicebox: "chunk", "crossfade"; en pm-workspace: "agent", "skill", "hook"). Hoy esos términos se mencionan en specs, code review, memoria, sin un glosario centralizado. Cuando un agente o un humano nuevo entra en un proyecto, descubre el vocabulario por osmosis o lo inventa, generando drift.

Pocock implementa el patrón DDD "ubiquitous language" en dos skills:
- `ubiquitous-language/SKILL.md` — extractor que toma una conversación y produce un glosario
- `domain-model/SKILL.md` — gestiona `CONTEXT.md` (glosario) + `docs/adr/` (decisiones)

pm-workspace ya tiene infra parcial: `memory-graph.py` (SPEC-027) extrae entidades de la JSONL store, y SE-076 Slice 1 añadió episodes con `entities: [...]`. Falta un puente: extraer entidades de dominio (no técnicas — no "memory-graph.py", sí "Era", "slice", "spec") y consolidarlas en un `CONTEXT.md` del proyecto.

Coste de no adoptar: el vocabulario de cada proyecto deriva, agentes nuevos pierden tiempo aprendiéndolo, specs lo reinventan. Coste de adoptar: ~150 LOC de python (extractor) + ~80 LOC de markdown (skill).

## Scope (M 5h, 2 slices)

### Slice 1 (S 2h) — Skill `.opencode/skills/ubiquitous-language/`

`SKILL.md` (~80 LOC) con instrucciones para que el agente:

1. Lea la conversación reciente (últimos N turnos) o el path indicado
2. Extraiga términos de dominio (no técnicos): nombres con mayúscula, conceptos repetidos, jerga del proyecto
3. Para cada término, infiere definición desde el contexto
4. Pregunta a la usuaria si hay términos faltantes o malinterpretados
5. Escribe en `projects/<proyecto>/CONTEXT.md` (proyectos con CLAUDE.md propio) o pregunta dónde

Trigger: usuaria dice "extrae glosario", "ubiquitous language", "/glossary", o agente identifica >5 términos repetidos sin glosario presente.

Atribución MIT a `mattpocock/skills/ubiquitous-language/SKILL.md` + `domain-model/SKILL.md` en header.

### Slice 2 (M 3h) — Bridge a memory-graph

`scripts/extract-domain-entities.py` (~150 LOC):

- Toma JSONL store (`output/.memory-store.jsonl`) o un path arbitrario
- Filtra entries por `topic_key` o `project` field
- Extrae candidatos de domain term (regex + heuristics — case-sensitive multi-word, not in stop-list, not technical infrastructure terms)
- Cross-references contra `CONTEXT.md` existente: marca *new* (candidato a añadir), *existing* (ya documentado), *inconsistent* (CONTEXT.md tiene definición distinta del uso reciente)
- Output: `output/domain-entity-report-<project>-<date>.md` con tabla `term | mentions | inferred-definition | status`
- Modo `--auto-update CONTEXT.md` para añadir términos *new* automáticamente con definición tentativa marcada `[REVIEW]`

Cross-reference desde SE-076 episodic memory: episodes con `entities` field que coinciden con CONTEXT.md términos se marcan en grafo con edge `DOMAIN_TERM` (ya tenemos `MENTIONED_IN`).

## Acceptance criteria

### Slice 1
- [ ] AC-01 `.opencode/skills/ubiquitous-language/SKILL.md` ≤80 LOC compliant SE-084
- [ ] AC-02 Atribución MIT a Pocock
- [ ] AC-03 Skill describe trigger + proceso 5-pasos
- [ ] AC-04 Tests BATS ≥6 estáticos

### Slice 2
- [ ] AC-05 `scripts/extract-domain-entities.py` ejecutable, modos report + auto-update
- [ ] AC-06 Output incluye 3 status (new/existing/inconsistent)
- [ ] AC-07 `--auto-update` marca términos nuevos con `[REVIEW]` (no claim definitiveness)
- [ ] AC-08 Tests BATS ≥10 (extracts terms, marks status correctly, refuses overwrite without --auto-update flag)
- [ ] AC-09 SE-076 grafo emite edge `DOMAIN_TERM` cuando entities coinciden con CONTEXT.md
- [ ] AC-10 CHANGELOG fragment

## No hace

- NO crea CONTEXT.md automáticamente en cada proyecto — usuario decide dónde existe
- NO sustituye ADRs (`docs/adr/`) — ese es scope futuro (SE-### post Era 190 si vale la pena)
- NO genera definiciones autoritativas de términos — siempre marca `[REVIEW]` en auto-update
- NO toca `memory-graph.py` core — Slice 2 añade solamente el edge type `DOMAIN_TERM`

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Falsos positivos en extracción (términos que parecen dominio pero son código) | Alta | Bajo | Stop-list explícita; usuaria revisa output siempre antes de auto-update |
| CONTEXT.md drift vs uso real | Media | Medio | `inconsistent` status detecta drift; auditor periódico (no Era 190) |
| Solapa con architectural-vocabulary.md (SE-082) | Baja | Bajo | Distinto: SE-082 = vocabulario arquitectónico universal; SE-086 = términos de dominio per-proyecto |

## Dependencias

- ✅ SPEC-027 memory-graph.py existe
- ✅ SE-076 Slice 1 episodic memory (entities field) IMPLEMENTED batch 72
- ✅ `.opencode/skills/` directory
- Sin bloqueantes externos. Independiente de SE-081-085, SE-087.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Skill | `.opencode/skills/ubiquitous-language/SKILL.md` | autoload via AGENTS.md regen |
| Extractor | `scripts/extract-domain-entities.py` | python puro, idéntico |
| Memory-graph edge | `scripts/memory-graph.py` (Slice 2) | mismo |

### Verification protocol

- [ ] Smoke: extractor produce report sobre store de prueba con términos sembrados
- [ ] Skill invocable desde OpenCode v1.14 idéntico a Claude Code
- [ ] Edge `DOMAIN_TERM` aparece en grafo tras Slice 2

### Portability classification

- [x] **PURE_PYTHON + DOCS**: python + markdown, cross-frontend trivial.

## Referencias

- `mattpocock/skills/ubiquitous-language/SKILL.md` + `domain-model/SKILL.md` — fuente
- Eric Evans "Domain-Driven Design" — origen del término "ubiquitous language"
- SPEC-027 `scripts/memory-graph.py` — infra Phase 1
- SE-076 episodic memory — entities field
