---
id: SE-048
title: SE-048 — Rule-orphan detector (handoff-protocol caso seed)
status: IMPLEMENTED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: alta
effort: M 6h
gap_link: D9 gap SPEC-121
approved_at: "2026-04-20"
applied_at: "2026-04-20"
batches: [6, 7]
expires: "2026-05-20"
---

# SE-048 — Rule-orphan detector (handoff-protocol caso seed)

## Purpose

SPEC-121 regla handoff escrita, 0 agentes la usan. Cross-reference audit cada rule con uso real.

**Gap enlazado**: D9 gap SPEC-121 (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-048
- audit-roadmap-reprioritization-20260420.md
