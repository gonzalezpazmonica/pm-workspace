---
id: SE-045
title: SE-045 — Session-init split fast-path sync + bootstrap async
status: PROPOSED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: Critica
effort: M 12h
gap_link: Latency session-init 468ms vs SLA 20ms
approved_at: null
applied_at: null
expires: "2026-05-20"
---

# SE-045 — Session-init split fast-path sync + bootstrap async

## Purpose

Hook critico fuera de SLA por 23x. Impact directo UX usuaria en cada arranque. Split fast-path sincrono menor a 20ms + lazy async.

**Gap enlazado**: Latency session-init 468ms vs SLA 20ms (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-045
- audit-roadmap-reprioritization-20260420.md
