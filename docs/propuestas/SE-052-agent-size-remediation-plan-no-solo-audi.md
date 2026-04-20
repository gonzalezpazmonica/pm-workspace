---
id: SE-052
title: SE-052 — Agent-size remediation plan (no solo audit)
status: PROPOSED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: Alta
effort: L 24h
gap_link: 27 agents mayor 4KB
approved_at: null
applied_at: null
expires: "2026-05-20"
---

# SE-052 — Agent-size remediation plan (no solo audit)

## Purpose

Baseline congelado sin plan. Ratchet sin plan es amnistia. Split top-10 con common blocks extraidos. Target 0 over-budget.

**Gap enlazado**: 27 agents mayor 4KB (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-052
- audit-roadmap-reprioritization-20260420.md
