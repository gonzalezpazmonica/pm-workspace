---
id: SE-047
title: SE-047 — Agents catalog auto-sync con .claude/agents/
status: IMPLEMENTED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: alta
effort: S 4h
gap_link: D5
approved_at: "2026-04-20"
applied_at: "2026-04-20"
batches: [6, 7]
expires: "2026-05-20"
---

# SE-047 — Agents catalog auto-sync con .claude/agents/

## Purpose

docs/rules/domain/agents-catalog.md declara 56 agents, reales 65+. 9 sin documentar. Generator desde frontmatter + test paridad.

**Gap enlazado**: D5 (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-047
- audit-roadmap-reprioritization-20260420.md
