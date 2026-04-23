---
id: SE-049
title: SE-049 — SLM command consolidation pattern slm.sh subcommand
status: IN_PROGRESS
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: Media
effort: L 16h
gap_link: D18 scripts SLM dispersos
approved_at: "2026-04-23"
applied_at: null
slices_complete: [1]
batches: [38]
expires: "2026-05-20"
---

# SE-049 — SLM command consolidation pattern slm.sh subcommand

## Purpose

15 scripts slm-*.sh + duplicacion data-prep/dataset-prep. Consolidar en slm.sh con subcommands reutilizando libs.

**Gap enlazado**: D18 scripts SLM dispersos (ver audit-arquitectura-20260420.md).

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
- audit-new-specs-20260420.md §SE-049
- audit-roadmap-reprioritization-20260420.md
