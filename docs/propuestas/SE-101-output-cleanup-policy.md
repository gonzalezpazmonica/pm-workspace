---
spec_id: SE-101
title: Output dir retention policy (312 stale files, 4.7MB)
status: IMPLEMENTED
approved_by: operator (2026-05-27)
implemented_at: "2026-06-24"
priority: P2
effort: XS
estimated_time: 30 min
depends_on: none
source: output/20260527-auditoria-obsoleto-legado.md (Tier 3.10)
---

# SE-101 — Output retention policy

## Problema

`output/` tiene 312 ficheros >30 días, 4.7 MB. Sin política de retención formal. Informes históricos mezclados con runs activos.

## Solución

### Slice 1: Política documentada (~10 min)
- `docs/rules/domain/output-retention.md`: 90 días por defecto; `output/agent-runs/` rotación semanal; `output/baselines/` retención indefinida

### Slice 2: Script + cron (~20 min)
- `scripts/output-cleanup.sh --dry-run` y `--apply`
- Hook Stop opcional que sugiere cleanup cuando >500 ficheros stale

## Aceptación

- output/ <100 ficheros >90d tras primera ejecución
- Política visible en docs/rules/
