---
id: SE-085
title: SE-085 — Write-a-skill meta-skill (skill creation discipline)
status: APPROVED
origin: mattpocock/skills/write-a-skill (MIT) — análisis 2026-04-27
author: Savia
priority: baja
effort: S 2h
related: SE-084 (audit), SE-081/083/086/087 (skills nuevos siguiendo el pattern)
approved_at: "2026-04-27"
applied_at: null
expires: "2026-06-27"
era: 190
---

# SE-085 — Write-a-skill meta-skill

## Why

Cada vez que se crea un skill nuevo (SE-081, SE-083, SE-086, SE-087, etc.), el agente que lo escribe re-deriva el formato desde cero: frontmatter, "Use when" trigger, progressive disclosure, attribution si viene de upstream MIT. Es trabajo repetitivo y reincidente.

Pocock formaliza la meta-disciplina en un skill llamado `write-a-skill/SKILL.md` que codifica:

1. Proceso (gather requirements → draft → review)
2. Estructura del directorio (SKILL.md + REFERENCE.md + EXAMPLES.md + scripts/)
3. Template de SKILL.md
4. Reglas de description (max 1024 chars, third person, "Use when ...")
5. Cuándo añadir scripts vs prompts puros
6. Cuándo partir en ficheros separados (>100 LOC, distinct domains, advanced features)
7. Review checklist final

Coste de no adoptar: cada skill nuevo en pm-workspace re-inventa formato y se desvía. Coste de adoptar: ~120 LOC de markdown + cero código.

Prioridad **baja** porque:
- SE-084 ya enforced las reglas básicas via auditor + G14 (más fuerte que un skill consultivo)
- Sólo añade valor cuando creamos skill nuevo (frecuencia: ~1/sprint)
- Mónica + agentes ya tienen el pattern interiorizado tras SE-081

Aún así, vale la pena tenerlo porque baja la fricción para sub-agentes (Code Review Court, dev-orchestrator) que ocasionalmente proponen skills.

## Scope (Slice único, S 2h)

### 1. `.claude/skills/write-a-skill/SKILL.md` (clean-room, ~120 LOC)

Contiene las 7 secciones de Pocock adaptadas a pm-workspace:

- **Process**: gather requirements → draft → review with user
- **Structure**: skill-name/{SKILL.md, REFERENCE.md, EXAMPLES.md, scripts/}
- **SKILL.md template** con frontmatter `name`, `description` (incluye "Use when ...")
- **Description requirements**: max 1024 chars, third-person, primer frase capability + segunda frase trigger
- **When to add scripts**: deterministic ops, repeatable code, errors with explicit handling
- **When to split files**: SKILL.md > 100 LOC, distinct domains, rarely-used advanced
- **Review checklist** (6 ítems): trigger included, ≤100 LOC, no time-sensitive info, consistent terms, concrete examples, refs one-level-deep
- **Specific to pm-workspace**: cross-reference `docs/rules/domain/skill-catalog-discipline.md` (SE-084), atribución MIT obligatoria si proviene de upstream

Atribución MIT a `mattpocock/skills/write-a-skill/SKILL.md` en header.

### 2. Cross-reference

`docs/rules/domain/skill-catalog-discipline.md` (creado en SE-084) → "Para crear skills nuevos: usa `.claude/skills/write-a-skill/`"

### 3. Tests BATS estáticos

- SKILL.md existe ≤120 LOC
- 7 secciones presentes (regex grep)
- Cross-reference desde skill-catalog-discipline.md existe

## Acceptance criteria

- [ ] AC-01 `.claude/skills/write-a-skill/SKILL.md` ≤120 LOC con frontmatter compliant SE-084
- [ ] AC-02 7 secciones presentes (Process, Structure, Template, Description, Scripts, Splitting, Checklist)
- [ ] AC-03 Atribución MIT a Pocock en header (clean-room)
- [ ] AC-04 Cross-reference desde `skill-catalog-discipline.md` (SE-084)
- [ ] AC-05 Skill mismo pasa el auditor SE-084 en modo `--gate` (dogfood)
- [ ] AC-06 Tests BATS ≥6 estáticos
- [ ] AC-07 CHANGELOG fragment

## No hace

- NO genera skills automáticamente — es referencia consultiva
- NO duplica `docs/rules/domain/skill-catalog-discipline.md` — ese es el rule canónico (gate enforced); este skill es la guía de "cómo aplicarlo en práctica"
- NO impone una arquitectura específica para scripts (TS vs bash vs python) — agnostic

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Drift con skill-catalog-discipline.md (la regla) | Media | Bajo | Cross-ref bidireccional; SE-084 audit cubre los hechos enforced |
| Sub-agentes no consultan el skill al crear uno nuevo | Alta | Bajo | SE-084 G14 los pillará igualmente |

## Dependencias

- ✅ `.claude/skills/` directory existe
- **Recomendado**: SE-084 IMPLEMENTED antes (para que skill-catalog-discipline.md exista para el cross-ref); si SE-084 viene después, este spec deja stub y se actualiza
- Sin bloqueantes externos. Independiente de SE-081/082/083/086/087.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| SKILL.md | `.claude/skills/write-a-skill/SKILL.md` | autoload via AGENTS.md regen |

### Verification protocol

- [ ] AGENTS.md regen pasa drift check
- [ ] Skill mismo pasa SE-084 auditor en `--gate` (dogfood)

### Portability classification

- [x] **PURE_DOCS**: markdown puro. Cross-frontend trivial.

## Referencias

- `mattpocock/skills/write-a-skill/SKILL.md` — fuente
- `docs/rules/domain/skill-catalog-discipline.md` (SE-084) — regla canónica enforced
