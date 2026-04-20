---
id: SE-056
title: SE-056 — Python runtime SBOM + virtualenv enforcement
status: PROPOSED
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: Media
effort: M 8h
gap_link: 5 py scripts sin requirements
approved_at: null
applied_at: null
expires: "2026-05-20"
---

# SE-056 — Python runtime SBOM + virtualenv enforcement

## Purpose

Fragilidad runtime. SBOM + .savia-venv auto-create + pin deps. Reproducibilidad.

**Gap enlazado**: 5 py scripts sin requirements (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-056
- audit-roadmap-reprioritization-20260420.md
