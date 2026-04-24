---
id: SE-039
title: Test-auditor global sweep — score ≥80 sobre todos los .bats existentes
status: IMPLEMENTED
origin: ROADMAP-UNIFIED-20260418 Wave 4 D2 + SPEC-055 enforcement
author: Savia
related: SPEC-055-test-auditor, scripts/test-auditor.sh, tests/*.bats
approved_at: "2026-04-24"
applied_at: "2026-04-24"
implemented_at: "2026-04-24"
expires: "2026-06-18"
priority: alta
---

# SE-039 — Test-auditor global sweep

## Purpose

Si NO hacemos esto: SPEC-055 test-auditor audita tests NUEVOS en cada PR (G6b), pero los tests preexistentes NUNCA pasan por auditor. Tenemos 100+ archivos `.bats` en `tests/` de los cuales una fracción desconocida está bajo el umbral de 80. El gate nuevo protege futuro, no presente.

Evidencia indirecta: feedback_test_excellence_patterns.md memoria documenta que los primeros tests Savia generaba scoreaban 40-60 — solo los últimos ~15 PRs tienen tests que empiezan en 80+. Los ~85 restantes son legacy sin auditar.

Cost of inaction: falsa sensación de cobertura. Un test que pasa pero no detecta mutaciones reales (patrón de tests zombies del research mutation-testing 2026-04-18) nos vende seguridad que no tenemos. Cuando ocurra un bug en código cubierto por test zombie, el coste de investigación será alto.

## Objective

**Único y medible**: ejecutar `scripts/test-auditor.sh` sobre cada `.bats` en `tests/`, producir ranking, y remediar bottom-10 hasta ≥80. Criterio: ≥95% de archivos .bats con score ≥80 tras sweep.

## Slicing

### Slice 1 — Batch audit (2h)

- `scripts/audit-all-bats.sh` ejecuta test-auditor sobre cada .bats
- Output: `output/bats-audit-sweep-{date}.md` — tabla ordenada por score ascending
- NO modifica tests en este slice (read-only)

### Slice 2 — Remediation bottom-10 (4h)

- Por cada test <80, aplicar patrones de `feedback_test_excellence_patterns.md`:
  - Safety header
  - Negative tests
  - Edge cases
  - Coverage coverage
  - SPEC/docs references
- Re-audit post-fix: cada uno debe llegar a ≥80

### Slice 3 — Enforcement (30min)

- G6b gate en pr-plan.sh ya existe para tests CHANGED
- Añadir modo `--full-sweep` (opt-in) para auditar TODO
- CI job semanal que ejecuta sweep completo y reporta regresiones (>1 test bajo 80)

### Slice 4 — Mutation testing integration (depende SE-035)

- Cuando SE-035 aterrice, top-5 tests ya auditados ≥80 pasan por mutation testing
- Si mutation score <50%, upgrade a tier "excellent" requerido
- Ortogonal: auditor mide forma, mutation mide eficacia

## Acceptance Criteria

- [ ] AC-01 `scripts/audit-all-bats.sh` operativo con output estructurado
- [ ] AC-02 Ranking completo de todos los .bats con score
- [ ] AC-03 ≥95% de tests en score ≥80 post-sweep
- [ ] AC-04 CI job semanal configurado (GitHub Actions cron)
- [ ] AC-05 Doc `docs/rules/domain/test-quality-gate.md` formaliza el SLA
- [ ] AC-06 Integration con SE-035 mutation testing documentada (futuro)

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Algunos tests legacy son difíciles de remediar | Slice 2 prioriza por criticidad del código testeado, no por score |
| Sweep tarda >30min en local | Slice 1 usa paralelismo bounded (MAX_PARALLEL=5 per feedback_bounded_concurrency) |
| Falsos positivos del auditor | Documentar exempciones con justificación por test |

## Aplicación Spec Ops

- **Simplicity**: una métrica (score auditor)
- **Probe**: Slice 1 es el probe — si ≥95% ya está ≥80, abort spec (no hay deuda)
- **Speed**: 4 slices, 3 de ellos ≤2h

## Referencias

- SPEC-055 test-auditor
- `feedback_test_excellence_patterns.md` (memoria)
- `feedback_mutation_testing.md` (memoria — ortogonal, futuro)
- ROADMAP-UNIFIED-20260418 §Wave 4 D2
- SE-035 mutation testing (complementa este spec)

## Dependencia

Independiente. Precede a SE-035 mutation testing (audit cleanliness antes de mutation testing).

## Resolution (2026-04-24)

**Todas las acceptance criteria cumplidas. Slice 4 (mutation testing integration) deferido — depende de SE-035.**

### Slice 1 — Batch audit (ya existente, tests nuevos)

- `scripts/audit-all-bats.sh` — 164 lineas, ya existente, testeado en este PR
- `tests/test-audit-all-bats.bats` — 38 tests certified (score 97)
- Output: `output/bats-audit-sweep-20260424.md`

### Slice 2 — Remediation bottom-10 (N/A)

Probe de Slice 1 demostro que **100% (232/232)** de los tests existentes ya scoran ≥80. AC-03 ya cumplido sin remediation. Slice 2 abortado per criterio "Spec Ops / Probe" del propio spec ("si ≥95% ya está ≥80, abort").

### Slice 3 — Enforcement

- `.github/workflows/bats-audit-sweep.yml` — CI cron semanal (lunes 06:00 UTC) + workflow_dispatch manual
- `docs/rules/domain/test-quality-gate.md` — doctrine doc con SLA, enforcement layers, remediation playbook, scoring criteria
- G6b en pr-plan.sh ya existente para tests CHANGED (no se modifica)

### Stats baseline 2026-04-24

- Total .bats: 232
- Compliant (≥80): 232 (100%)
- Average score: 87
- Bottom decile (score=80): 13 tests (lista en reporte)

### Slice 4 — Mutation integration (DEFERRED)

Bloqueado por SE-035 Slice 3+ completion. Ortogonal documentado en `test-quality-gate.md §Mutation testing (future)`.

## Acceptance Criteria final

- [x] AC-01 `scripts/audit-all-bats.sh` operativo con output estructurado
- [x] AC-02 Ranking completo de todos los .bats con score
- [x] AC-03 ≥95% de tests en score ≥80 post-sweep (100% actual)
- [x] AC-04 CI job semanal configurado (`.github/workflows/bats-audit-sweep.yml`)
- [x] AC-05 Doc `docs/rules/domain/test-quality-gate.md` formaliza el SLA
- [ ] AC-06 Integration con SE-035 mutation testing documentada (deferred — solo doc stub, integration real en SE-039 Slice 4)
