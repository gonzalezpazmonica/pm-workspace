---
id: SE-046
title: SE-046 — Baseline re-levelling + ratchet integrity test
status: IMPLEMENTED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: Media
effort: S 3h
gap_link: D6
approved_at: "2026-04-20"
applied_at: "2026-04-23"
batches: [7, 37]
expires: "2026-05-20"
---

# SE-046 — Baseline re-levelling + ratchet integrity test

## Purpose

Baseline hook-critical-violations=10 vs real=4. Ratchet con margin 2.5x no aprieta. Auto-tighten + BATS guard baseline menor o igual a measured.

**Gap enlazado**: D6 (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-046
- audit-roadmap-reprioritization-20260420.md
