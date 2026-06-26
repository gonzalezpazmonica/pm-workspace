---
spec_id: SE-103
title: Quarterly dormant rules review (~40 rules)
status: IMPLEMENTED
implemented_at: "2026-06-24"
approved_by: operator (2026-05-27)
priority: P3
effort: S
estimated_time: 90 min
depends_on: none
source: output/20260527-auditoria-obsoleto-legado.md (Tier 3.11)
---

# SE-103 — Dormant rules quarterly review

## Problema

`rule-usage-analyzer.sh` marca ~40 reglas con tier:dormant, consumers vacíos. Superset de SE-096 (huérfanas duras). Algunas pueden integrarse, otras archivarse, otras son referencia legítima.

## Solución

Trimestral (Q1, Q2, Q3, Q4):
1. Listar dormant
2. Triage por categoría: archive | integrate | reference-only (frontmatter explícito)
3. CHANGELOG por trimestre

## Aceptación

- Lista dormant <20 tras primera ronda
- Frontmatter `usage: reference-only` en las que se queden
