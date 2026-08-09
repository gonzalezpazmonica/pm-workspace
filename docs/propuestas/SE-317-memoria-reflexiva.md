---
id: SE-317
title: "SE-317 — Memoria reflexiva: consolidación automática del knowledge store"
status: PROPOSED
priority: media
---

# SE-317 — Memoria reflexiva: consolidación automática del knowledge store

**Status:** PROPOSED
**Fecha:** 2026-08-09
**Area:** Memory / Knowledge graph / SaviaVaults
**Branch sugerida:** `agent/se317-reflexive-memory`
**Estimacion total:** ~28h (4 slices)
**Inspiracion:** `NVIDIA-NeMo/labs-OO-Agents` (NOOA memory subsystem) + `danielmiessler/LifeOS`

---

## Contexto y evidencia (2026-08-09)

El blog NOOA describe un sistema de memoria que **el agente curatea**: escribe,
consulta y corrige registros con tipos, importancia y tags; las relaciones
tipadas (`supports`, `contradicts`, `derived-from`) conectan registros en un
grafo; y un pase de **reflexión en background** consolida el store: merge de
duplicados, enlazado de relacionados, destilación de episodios en insights y
prune de lo irrelevante. Resultado medido: +11.8 RHAE vs file-based notes en
ARC-AGI-3, sin retraining.

Savia tiene:
- `savia-memory` (markdown, `scripts/memory-store.sh` recall/save/stats),
- `knowledge-graph` (SQLite con entities/relations tipadas, SE-162),
- `context-dome` y SaviaVaults (cúpulas de contexto, SE-293 quotas/audit).

**El hueco.** La memoria de Savia crece por *acumulación reactiva*: cada sesión
añade notas, pero **nada consolida duplicados, enlaza registros relacionados ni
prune información obsoleta**. El `memory-agent` es reactivo (se le pide, actúa).
NOOA demuestra que la consolidación automática (reflexión) es lo que mantiene
el store útil a escala.

---

## Objetivo

Añadir un pase de reflexión periódico (cron + manual) que consolide el
knowledge store de Savia: detectar duplicados (content fingerprint),
enlazar registros relacionados (relaciones tipadas `derived-from`/`supports`),
destilar episodios en insights y marcar registros obsoletos para prune.
Integrado con `savia-memory`, `knowledge-graph` y SaviaVaults.

---

## Out of scope

- NO reescribir el almacenamiento (markdown/SQLite se mantienen).
- NO eliminar registros sin confirmación: el prune produce una *lista candidata*
  que el operador aprueba.
- NO tocar la digestión de reuniones ni los tribunales.

---

## Diseno

### S1 — Detección de duplicados y near-duplicates

`scripts/memory-consolidate.sh scan`:
- fingerprint por contenido (`content-fingerprint` skill, hash determinista),
- detecta near-duplicates con similitud (difflib) sobre notas del mismo dome,
- emite JSONL con candidatos a merge y su score.

### S2 — Enlazado por relaciones tipadas

`scripts/memory-consolidate.sh link`:
- identifica menciones de entidades ya en el knowledge graph,
- propone aristas `derived-from` (nota cita a otra) y `supports`/`contradicts`
  (consistencia entre notas),
- escribe a `knowledge-graph` (sin duplicar entidades).

### S3 — Destilación de episodios en insights

`scripts/memory-consolidate.sh distill`:
- agrupa notas de una misma sesión/episodio (por timestamp y dominio),
- genera una nota resumen (insight) con citas de las fuentes,
- marca las fuentes como `absorbed`.

### S4 — Prune candidato + scheduler

- `scripts/memory-consolidate.sh prune --dry-run`: lista notas obsoletas
  (sin acceso en >N días, absorbidas, contradictorias sin resolución),
- integración con `automation-scheduler` (cron semanal) y comando manual
  `/memory-consolidate`.
- Todo prune va a `output/memory-consolidation/{fecha}.jsonl` para revisión.

---

## Criterios de aceptacion

### AC-S1: Scan

- [ ] AC-S1.1: 2 notas idénticas → candidato a merge con score 1.0.
- [ ] AC-S1.2: 2 notas del mismo episodio → candidato near-duplicate (score
  configurable, default >0.85).

### AC-S2: Link

- [ ] AC-S2.1: nota que cita a otra existente → arista `derived-from`.
- [ ] AC-S2.2: dos notas con entidad compartida → arista `supports` o
  `contradicts` propuesta (no auto-escrita).

### AC-S3: Distill

- [ ] AC-S3.1: episodio de ≥2 notas genera 1 insight con `citations`.
- [ ] AC-S3.2: las fuentes quedan marcadas `absorbed` (no borradas).

### AC-S4: Prune + scheduler

- [ ] AC-S4.1: `--dry-run` no modifica nada y lista candidatos con razón.
- [ ] AC-S4.2: automatización semanal registrada en el scheduler.
- [ ] AC-S4.3: cada ejecución deja reporte en `output/memory-consolidation/`.

---

## Ref

- NVIDIA-NeMo/labs-OO-Agents → memory subsystem (SQLite tipado, reflexión)
- `scripts/memory-store.sh`, `scripts/knowledge-graph.sh`, `.claude/skills/savia-memory/SKILL.md`
- `scripts/savia-automations.sh` (SE-304)
