---
id: SE-043
title: SE-043 — CLAUDE.md drift-auto-check pre-commit
status: IMPLEMENTED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: Alta
effort: S 4h
gap_link: D1/D2/D3/D4
approved_at: "2026-04-20"
applied_at: "2026-04-20"
batches: [6]
expires: "2026-05-20"
---

# SE-043 — CLAUDE.md drift-auto-check pre-commit

## Purpose

CLAUDE.md cuenta agents/skills/commands/hooks desfasado. SPEC-109 item 7 no cerro. Hook deterministic re-count + compare.

**Gap enlazado**: D1/D2/D3/D4 (ver audit-arquitectura-20260420.md).

## Objective

Unico y medible: cerrar el gap descrito con Slice 1 scaffolding + BATS tests.

## Slicing

- **Slice 1**: probe/scaffolding + BATS tests (≥15 tests, ≥80 auditor score).
- **Slice 2**: implementacion enforcement o integracion.
- **Slice 3**: rollout + deprecation de comportamiento anterior si aplica.

## Acceptance criteria

- Script ejecutable con --help, --json, exit codes 0/1/2.
- Tests BATS con isolation guards (read-only, no side effects en repo).
- Documentacion en docs/rules/domain/ si aplica (≤150 lineas).

## Refs

- audit-arquitectura-20260420.md §Matriz de desincronizaciones
- audit-new-specs-20260420.md §SE-043
- audit-roadmap-reprioritization-20260420.md
