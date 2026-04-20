---
id: SE-054
title: SE-054 — SE-036 Slices 2-3 finish frontmatter migration
status: PROPOSED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: Alta
effort: M 10h
gap_link: D16 D17
approved_at: null
applied_at: null
expires: "2026-05-20"
---

# SE-054 — SE-036 Slices 2-3 finish frontmatter migration

## Purpose

81/111 specs sin migrar. Slice 2 batch 40 + Slice 3 batch 41 + enforcement gate. Desbloquea tooling grep/jq.

**Gap enlazado**: D16 D17 (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-054
- audit-roadmap-reprioritization-20260420.md
