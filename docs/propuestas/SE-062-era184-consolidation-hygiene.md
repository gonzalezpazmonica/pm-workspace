---
id: SE-062
title: SE-062 — Era 184 Consolidation + Hygiene post-Era 183
status: IMPLEMENTED
origin: drift audit post-Era 183 (batch 23, 2026-04-22)
author: Savia
priority: alta
effort: M 12-15h
gap_link: Drift doc/realidad + deuda post-22-batches
approved_at: "2026-04-22"
applied_at: "2026-04-22"
batches: [24, 25, 26, 27]
expires: "2026-05-22"
---

# SE-062 — Era 184 Consolidation + Hygiene

## Purpose

Tras 22 batches consecutivos (Era 182 closure → Era 183 Tier 3 5/6) sin ciclo de hygiene intermedio, drift audit post-Era 183 identifica deuda compuesta:

- **Skills count triple drift**: CLAUDE.md, ROADMAP y filesystem con cifras distintas
- **Duplicate SE-056**: dos ficheros violan SE-044 spec-id-guard aprobado
- **18 scripts huérfanos** sin skill docs (probes + auditors sin integración discoverable)
- **CHANGELOG inflación**: >8000 líneas sin consolidación (SE-053 aprobado pero sin ejecutar)
- **33 specs PROPOSED sin owner** — viola espíritu autonomous-safety
- **Frontmatter migration incompleta**: SE-036 slices 2-3 pendientes

Cost of inaction: bajo sprint 1, compuesto después. Sin ciclo hygiene, Era 185+ arranca sobre base ruidosa.

## Objective

Cerrar drift identificado en 5 sprints cortos (SE-062.1 - SE-062.5), sin añadir features nuevas. Criterio medible en drift-auditor re-run post-Era 184.

## Slicing

### SE-062.1 — Counter sync (1h)
- CLAUDE.md skills count alineado con filesystem
- ROADMAP header counters verificados
- Drift check en CI (ya existe, ampliar a commands/agents/hooks triple)

### SE-062.2 — Duplicate SE-056 resolution (1h)
- Investigar cuál es canónico (SE-056 vs SE-056-python-runtime-sbom-virtualenv-enforceme)
- Consolidar en un solo fichero con ADR referencia SE-044
- Actualizar referencias cruzadas

### SE-062.3 — Skills para 18 scripts huérfanos (4h)
- Auditor: MCP security, permissions wildcard, hook injection, rule manifest → skill unificada `security-scan`
- Probes: scrapling/oumi/memvid/bertopic/reranker → skill unificada `tier3-probes`
- O 1 SKILL.md aggregator referenciando scripts sin crear skill individual (decision: aggregator)

### SE-062.4 — SE-053 changelog consolidation hook activation (3h)
- Script ya existe (`changelog-consolidate-if-needed.sh`)
- Wire en hook post-PR-merge
- Threshold: consolidar si CHANGELOG supera umbral configurable

### SE-062.5 — Frontmatter SE-036 Slices 2-3 (3h)
- Normalizar 4 specs legacy restantes (SPEC-066/067/068/069)
- Estrategia: refactor body para mover `**Status**:` después del `## Problem`
- Habilitar frontmatter YAML sin romper validate-spec

## Acceptance criteria

- CLAUDE.md/ROADMAP/filesystem counters sincronizados (triple check en CI)
- Zero duplicate spec IDs (SE-044 gate enforcement)
- Cada script en `scripts/` tiene referencia en al menos un SKILL.md o es explícitamente categorizado como "internal tool" en docs
- CHANGELOG bajo umbral tras consolidation
- Specs migradas a frontmatter YAML canónico
- Drift auditor re-run pasa con zero findings HIGH severity

## No scope

- No añadir features nuevas
- No tocar Tier 7 backlog (PDF, GAIA, Enterprise)
- No iniciar SE-028 Oumi ni SE-042 voice training
- No refactorizar skills existentes (solo añadir docs)

## Riesgos

| Riesgo | Mitigación |
|---|---|
| SE-062.5 rompe validate-spec | BATS tests antes de commit |
| Skills aggregator confunde discovery | Mantener refs cruzadas SKILL↔script |
| CHANGELOG consolidation deja fragmentos viejos | Dry-run antes de apply |

## Referencias

- Drift audit: batch 23 (este PR)
- Era 183 closure: batch 22 (PR #663)
- SE-044 spec-id guard: `docs/decisions/adr-001-spec-110-id-collision-resolution.md`
- SE-053 spec: ya aprobado, sin ejecutar
