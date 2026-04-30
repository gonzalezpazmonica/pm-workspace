---
version_bump: patch
section: Fixed
---

## [6.23.2] — 2026-04-30

Batch 84 — Drift cleanup post-audit. Backlog audit detectó 5 specs IMPLEMENTED via batches 78-83 con frontmatter PROPOSED, 1 status inválido (`ALL` en SPEC-106), 3 UNLABELED, 1 DRAFT (SPEC-110 cargada como `@import` en CLAUDE.md). Process hygiene antes de continuar Critical Path.

### Fixed

#### Spec frontmatter status normalizados (10 specs)

- `docs/propuestas/SPEC-103-deterministic-first-digests.md` — PROPOSED → IN_PROGRESS (Slice 1 IMPLEMENTED batch 82, Slice 2 pendiente)
- `docs/propuestas/SPEC-125-recommendation-tribunal-realtime.md` — PROPOSED → IN_PROGRESS (Slice 1 foundation IMPLEMENTED batch 83, NO ACTIVADO; Slices 2+3 follow-up)
- `docs/propuestas/savia-enterprise/SPEC-SE-035-reconciliation-delta-engine.md` — PROPOSED → IN_PROGRESS (Slices 1+3 IMPLEMENTED batch 81, Slices 2/4/5 follow-up)
- `docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md` — PROPOSED → IN_PROGRESS (Slices 1+2 IMPLEMENTED batches 79+80, Slice 3 sunset PAT pendiente)
- `docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md` — PROPOSED → IMPLEMENTED (8/12 ACs cumplidos batch 78, 4 deferred a repo Enterprise post-deploy)
- `docs/propuestas/SPEC-106-truth-tribunal-report-reliability.md` — `ALL` (inválido) → IMPLEMENTED (Truth Tribunal completo en producción: orchestrator + 7 jueces + scripts + tests)
- `docs/propuestas/SPEC-110-memoria-externa-canonica.md` — DRAFT → IMPLEMENTED (cargado como `@import` en CLAUDE.md desde Era anterior)
- `docs/propuestas/SPEC-047-requirement-pushback.md` — UNLABELED → APPROVED (body declara "Status: APPROVED — Phase 1")
- `docs/propuestas/SPEC-025-chinese-compatibility.md` — UNLABELED → PROPOSED (research study, no implementación)
- `docs/propuestas/SPEC-079-legal-compliance-agent.md` — UNLABELED → PROPOSED (body declara "Estado: Propuesta")

#### Roadmap actualizado

- `docs/propuestas/ROADMAP.md` — `last_updated: 2026-04-18 → 2026-04-30`, `expires: 2026-06-18 → 2026-06-30`. Sección "## 6. Live status" reescrita para reflejar realidad post-batch-83: último PR mergeado, recientes (Era 232 cerrada + Recommendation Tribunal foundation + image relevance filter + hotfixes), top 10 Critical Path repriorizado tras audit, próximo slice = SPEC-107 Slice 1 (medición AI Cognitive Debt).

#### Tests de regresión

- `tests/structure/test-spec-status-frontmatter.bats` — 28 tests certified. Cubre:
  - Hard rule: zero specs con status UNLABELED / ALL / DRAFT / ENTERPRISE_ONLY
  - Specific drift fixes post-batch-83 verificados explícitamente (7 specs)
  - Coverage: cada SPEC-NNN.md y SPEC-SE-NNN.md tiene una línea `status:`
  - Edge: empty/whitespace-only/nonexistent status detectables
  - Coverage adicional: `scripts/claude-md-drift-check.sh` companion (set -uo pipefail, exit 0 sobre estado actual, fail graceful sobre CLAUDE.md ausente)
  - Negative paths: validación de migración (no UNLABELED leakage), test enum check (las 6 status canónicas listadas)
  - ROADMAP.md freshness gate (`last_updated >= 2026-04-30` y citas batches recientes)

### Why this matters

El frontmatter `status:` es la verdad operativa que consume el roadmap, los reports, el agente architect. Si dice PROPOSED cuando en realidad está IMPLEMENTED, las decisiones de prioridad se hacen sobre datos falsos. El audit detectó 10 specs con drift acumulado (incluyendo 1 inválido `ALL` que indicaba malformación pura del frontmatter). El test BATS añadido enforce regression — la próxima vez que alguien marque un status inválido o no actualice tras IMPLEMENTED, falla en CI antes de que el drift se acumule.

### Spec ref

Audit ejecutado por agent business-analyst (2026-04-30) tras Mónica pedir "revisa specs, reprioriza roadmap y continúa desarrollando". Top 10 Critical Path post-audit documentado en `docs/propuestas/ROADMAP.md` §6. Próximo: SPEC-107 Slice 1 (AI Cognitive Debt measurement, ~10h, read-only, severity Alta) per orden previo de la usuaria.
