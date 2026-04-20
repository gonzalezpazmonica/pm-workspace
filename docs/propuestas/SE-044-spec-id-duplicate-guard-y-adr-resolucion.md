---
id: SE-044
title: SE-044 — Spec-ID duplicate-guard y ADR resolucion SPEC-110
status: PROPOSED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: Alta
effort: S 3h
gap_link: D7/D21
approved_at: null
applied_at: null
expires: "2026-05-20"
---

# SE-044 — Spec-ID duplicate-guard y ADR resolucion SPEC-110

## Purpose

Dos specs SPEC-110 colisionan (memoria-externa Draft + polyglot-developer REJECTED). ADR decide renombrar polyglot a SPEC-126.

**Gap enlazado**: D7/D21 (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-044
- audit-roadmap-reprioritization-20260420.md
