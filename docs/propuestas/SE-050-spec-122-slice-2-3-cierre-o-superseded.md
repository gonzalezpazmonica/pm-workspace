---
id: SE-050
title: SE-050 — SPEC-122 Slice 2+3 cierre o SUPERSEDED
status: IMPLEMENTED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: alta
effort: M 8h
gap_link: SPEC-122
approved_at: "2026-04-20"
applied_at: "2026-04-20"
batches: [9]
expires: "2026-05-20"
---

# SE-050 — SPEC-122 Slice 2+3 cierre o SUPERSEDED

## Purpose

Slice 1 merged hace 4 dias. Slices 2 skill update y 3 docs especificados y pequenos. Terminar o marcar abandono.

**Gap enlazado**: SPEC-122 (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-050
- audit-roadmap-reprioritization-20260420.md
