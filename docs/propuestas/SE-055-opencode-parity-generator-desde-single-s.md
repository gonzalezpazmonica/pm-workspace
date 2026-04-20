---
id: SE-055
title: SE-055 — .opencode parity generator desde single source
status: PROPOSED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: Baja
effort: M 6h
gap_link: D10
approved_at: null
applied_at: null
expires: "2026-05-20"
---

# SE-055 — .opencode parity generator desde single source

## Purpose

Dos CLAUDE.md diverging. Template unico + generator reproduce ambos.

**Gap enlazado**: D10 (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-055
- audit-roadmap-reprioritization-20260420.md
