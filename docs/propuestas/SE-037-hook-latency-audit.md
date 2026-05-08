---
id: SE-037
title: Hook latency + BATS coverage audit — 60 hooks bajo SLA 20ms + tests
status: IMPLEMENTED
origin: ROADMAP-UNIFIED-20260418 Wave 4 D4+D5
author: Savia
related: .opencode/hooks/, scripts/hook-bench.sh, SPEC-081-hook-bats-coverage
approved_at: "2026-04-20"
applied_at: "2026-04-20"
batches: [5]
expires: "2026-06-18"
---

# SE-037 — Hook latency audit + BATS coverage

## Purpose

Si NO hacemos esto: 60 hooks (55 scripts × 59 registros multi-event) se ejecutan en arranque de sesión, en cada tool call, y en events distintos. Sin medición sistemática:
- Un hook que degrade a 200ms mata la UX sin aviso (ya nos pasó con session-end-memory.sh en PR #595)
- Sin tests BATS individuales, cada hook es un single point of failure no auditado
- Memory-prime-hook se hardenó tras fork-bomb 2026-04-18, pero no sabemos cuáles de los otros 59 tienen el mismo patrón

Cost of inaction: cuando ocurra el próximo incidente (fork bomb, latency spike, hook crash), no tendremos baseline ni tests que detecten regresión. Aprendizaje por incidente en lugar de por test — costoso.

## Objective

**Único y medible**: medir latencia de cada hook en los 6 eventos que dispara (SessionStart, PreToolUse, PostToolUse, Stop, UserPromptSubmit, SessionEnd), y asegurar que TODOS los críticos (arranque + per-turn) cumplen SLA <20ms p50. Criterio: `scripts/hook-bench.sh --all` reporta 100% de hooks críticos bajo SLA + al menos 20 hooks con tests BATS individuales (de los 60 totales).

## Slicing

### Slice 1 — Baseline measurement (1h)

- Extender `scripts/hook-bench.sh` para ejecutar CADA hook 10x y reportar p50/p95/p99
- Output: `output/hook-bench-{date}.md` con tabla ordenada por p95
- Flag `--critical-only` filtra hooks que corren en hot path (arranque + per-turn)

### Slice 2 — Identify violations + fix top 3 (2h)

- Cualquier hook crítico con p50 >20ms entra en lista de remediación
- Priorizar 3 worst offenders
- Fix cada uno (background, cache, early-exit patterns)
- Verificar: post-fix p50 <20ms

### Slice 3 — BATS coverage para top-10 críticos (3h)

- SPEC-081 ya propone tests para 10 hooks críticos; ejecutar esa propuesta
- Patrón: `tests/test-hook-{name}.bats` con al menos 10 tests por hook
- Test-auditor score ≥80 cada uno
- CI gate: si un hook crítico cambia, sus tests DEBEN correr y pasar

### Slice 4 — SLA enforcement gate (1h)

- Añadir a `ci-extended-checks.sh` check #9: "hook-bench reporta p50 crítico <20ms"
- Si un hook crítico degrada en un PR, el gate falla

## Acceptance Criteria

- [ ] AC-01 `hook-bench.sh --all` ejecuta y reporta 60 hooks con p50/p95/p99
- [ ] AC-02 Cada hook crítico tiene p50 <20ms medido post-fix
- [ ] AC-03 10 hooks críticos con tests BATS ≥80 auditor score
- [ ] AC-04 ci-extended-checks.sh check #9 instalado y verde
- [ ] AC-05 Doc `docs/rules/domain/hook-performance-sla.md` formaliza el SLA + lista críticos
- [ ] AC-06 CHANGELOG entries por slice

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Hook-bench mide en ambiente Savia pero no en CI remoto | Slice 1 ejecuta en local + añade check en CI GitHub Actions |
| Fix de latencia rompe funcionalidad | Tests BATS existentes sirven de regression gate |
| SLA <20ms demasiado estricto para algunos (ej. hooks de análisis) | Categorizar: critical <20ms, analysis <100ms, background <1s |

## Aplicación Spec Ops

- **Simplicity**: un SLA — 20ms p50 crítico
- **Purpose**: incidentes pasados (fork bomb, 205ms hook) son la prueba
- **Repetition/Probe**: Slice 1 es el probe — si ya estamos todos bajo SLA, abort Slice 2 (no hay problema real)
- **Theory of Relative Superiority**: expires 2026-06-18, re-review

## Dependencia

Absorbe SPEC-081 (hook bats coverage). SPEC-081 se marca SUPERSEDED por SE-037 tras merge.

## Referencias

- `scripts/hook-bench.sh`: tool actual (limitada, solo algunos hooks)
- SPEC-081: propuesta original de coverage, consolidada aquí
- Post-mortem PR #595 (session-end-memory.sh 205ms→18ms)
- `feedback_bounded_concurrency.md` memoria (fork bomb 2026-04-18)
- ROADMAP-UNIFIED-20260418 §Wave 4 D4+D5
