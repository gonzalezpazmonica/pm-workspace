---
id: SE-057
title: SE-057 — Rule-manifest integrity gate INDEX size y coverage
status: IMPLEMENTED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: baja
effort: S 3h
gap_link: D20 INDEX 165L
approved_at: "2026-04-20"
applied_at: "2026-04-20"
batches: [9]
expires: "2026-05-20"
---

# SE-057 — Rule-manifest integrity gate INDEX size y coverage

## Purpose

INDEX.md rule viola Rule #22. Manifest JSON no validado vs filesystem. Cross-check script.

**Gap enlazado**: D20 INDEX 165L (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-057
- audit-roadmap-reprioritization-20260420.md
