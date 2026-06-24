---
spec_id: SE-212
title: Recall budget experiment — validate MEMORY.md cap empirically
status: IMPLEMENTED
applied_at: "2026-06-24"
priority: P1
effort: S
era: 202
origin: output/research/memanto-savia-20260607.md
inspiration: Memanto ablation study — k=10→k=40 gives +20.4pp LongMemEval
---

# SE-212 — Recall budget experiment (k=40 vs k=200)

## Problema

El cap actual de MEMORY.md es 200 entradas (hard limit). No hay datos empíricos sobre cuántas entradas están siendo excluidas del contexto activo por ese cap, ni si hay patrones de pérdida relevante. Memanto demuestra que k=40→k=200 da +20.4pp en LongMemEval — sin medir, no sabemos si el cap actual es demasiado restrictivo.

## Solución

Antes de subir el cap, medir empíricamente cuántas entradas están siendo excluidas del contexto activo y si hay patrones de pérdida.

## Scope

### 1. `scripts/memory-recall-audit.sh`

Lee `~/.savia-memory/auto/MEMORY.md` (o la ruta configurada), cuenta entradas totales vs entradas en Tier A (accedidas en los últimos 30 días), calcula el "recall budget utilization": qué % del cap está ocupado.

### 2. Flag `--simulate-k <N>`

Muestra qué entradas adicionales estarían disponibles con cap N.

```
$ bash scripts/memory-recall-audit.sh --simulate-k 400
Cap actual: 200  |  Entradas activas (30d): 147  |  Utilización: 73.5%
Con k=400: +53 entradas adicionales disponibles
Entradas excluidas más recientes: [lista]
```

### 3. `output/memory-recall-audit-{date}.md`

Informe con métricas y recomendación.

### 4. Criterio de decisión documentado

Si >80% del cap está ocupado con entradas relevantes, proponer subir cap.

## Acceptance Criteria

- **AC1**: script produce métricas: total entries, tier-A count, cap utilization %, oldest active entry
- **AC2**: `--simulate-k 400` muestra entradas que cap=200 excluye actualmente
- **AC3**: informe con recomendación basada en datos
- **AC4**: no modifica ningún fichero de memoria (read-only)

## OpenCode Implementation Plan

```yaml
classification: PURE_BASH
files_touched:
  - scripts/memory-recall-audit.sh
requires_restart: false
verification: bash scripts/memory-recall-audit.sh --simulate-k 400
```

## Referencias

- `scripts/memory-store.sh` — store de memoria persistente (read)
- `docs/memory-system.md` — sistema de memoria L0-L3
- `docs/ROADMAP.md#era-202` — Era 202 Memory intelligence upgrade
