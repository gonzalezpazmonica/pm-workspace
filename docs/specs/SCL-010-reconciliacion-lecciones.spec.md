# SCL-010 — Reconciliación de lecciones duplicadas/conflictivas entre instancias

**Status:** APPROVED (operadora, 2026-08-22) → IMPLEMENTED 2026-08-22
**Fecha:** 2026-08-22
**Area:** Memoria / SaviaVaults / Epistemología (SaviaLearning)
**Base:** reconciler 3-bucket (SPEC-183) + árbol `docs/rules/domain/reconciliation-decision-tree.md` + federación (SCL-007)
**Developer Type:** agent-single
**Context risk:** low
**Estimación:** agente ~6h / revisión humana 30min

---

## 1. Problema y objetivo

La federación cross-dome (SCL-007) importa lecciones de instancias remotas como
propuestas `INFERRED` en SaviaLearning. Con +1 instancia, la misma lección puede
llegar con distinto `id`/`evidence_hash` (mismo principio, redacción distinta) o
lecciones contradictorias pueden coexistir. Hoy no hay mecanismo que detecte y
clasifique esos pares: el recall degrada con duplicados y las contradicciones se
silencian.

Savia ya tiene el patrón: el `reconciler` 3-bucket (SPEC-183) clasifica
contradicciones de docs en **evolution | auto-resolve | conflict-doc**. Esta
spec lo aplica a las **learning proposals** entre instancias: detectar pares
duplicados/conflictivos, clasificarlos y, en los buckets seguros, proponer la
resolución (nunca aplicarla sola — CRIT-031).

**Objetivo**: `scripts/learning-reconcile.sh` que (1) detecte pares candidatos
por similitud de principio/cambio y (2) los clasifique en los 3 buckets según el
árbol existente. Output en `output/learning-loop/reconcile.jsonl`.

## 2. Contratos

### 2.1 CLI

```text
learning-reconcile.sh [--vault <path>] [--detect] [--classify IDA IDB] [--report]
  --detect     detecta pares candidatos (duplicados/conflictivos) en SaviaLearning
  --classify IA IB   clasifica un par contra el árbol (no muta el sustrato)
  --report     consolida output/learning-loop/reconcile.jsonl
Exit: 0 ok · 2 input inválido · 3 vault/path ausente
```

### 2.2 Clasificación (árbol 3-bucket, adaptado a LPs)

| Bucket | Condición | Acción propuesta |
|---|---|---|
| `evolution` | Mismo principio, distinta fecha, coherencia temporal (una es re-expresión posterior) | Marcar `supersedes` → la más reciente reemplaza; la antigua queda `superseded`, **nunca se borra** (CRIT-024) |
| `auto-resolve` | Mismo principio, `human_authored` > `INFERRED` (autoridad) | El `human_authored` gana; el `INFERRED` se marca candidato a supersede |
| `conflict-doc` | Mismos ids/principio, distinto contenido, ambas con autoridad similar | Escalar: no resolver; registrar par para decisión humana |

La clasificación **solo propone** flags (nunca muta `CRITERIO.md` ni levanta
provenance). La activación de cualquier resolución sigue siendo humana.

### 2.3 Output

```json
{"ts":"ISO","id_a":"LP-...","id_b":"LP-...","bucket":"evolution|auto-resolve|conflict-doc","principle_a":"...","principle_b":"...","proposal":"supersedes|supersede-candidate|escalate","score":0.0}
```

- `--report` consolida todos los pares en `output/learning-loop/reconcile.jsonl`.
- Privacidad RN: nunca guarda texto completo del prompt; los principios se
  registran (son lecciones, no prompts).

## 3. Reglas de negocio

| ID | Regla | Incumplimiento |
|---|---|---|
| RN-01 | El script clasifica y propone; nunca modifica `CRITERIO.md`, nunca levanta provenance | Test de no-mutación |
| RN-02 | `superseded` marca con tombstone; jamás borra (CRIT-024) | Test de retención |
| RN-03 | Duplicado exacto (mismo `evidence_hash`) no genera par — el propio guard de persistencia ya es idempotente | Test de idempotencia |
| RN-04 | Sin red, sin LLM, PURE_BASH+python (CRIT-001) | Test de agnosticismo |
| RN-05 | Privacidad: principles sí, prompts completos no | Test de contenido |

## 4. Criterios de aceptación

- [ ] AC-01: `--detect` sobre un fixture con 2 LPs de mismo principio (distinta redacción) detecta el par.
- [ ] AC-02: `--detect` no reporta como duplicado un mismo `evidence_hash` (RN-03).
- [ ] AC-03: `--classify` de par `human_authored` vs `INFERRED` da bucket `auto-resolve`.
- [ ] AC-04: `--classify` de par con coherencia temporal da bucket `evolution`.
- [ ] AC-05: `--classify` de par ambiguo con autoridad similar da bucket `conflict-doc`.
- [ ] AC-06: `--report` consolida JSONL con los campos del contrato.
- [ ] AC-07: hashes de `CRITERIO.md` y `CONSTITUCION.md` invariantes tras la suite.
- [ ] AC-08: suite BATS >= 12 tests, ~50% adversariales (no-mutación, idempotencia, retención).

## 5. Ficheros

**Crear**: `scripts/learning-reconcile.sh` · `tests/test-scl-010-reconcile.bats`

**Modificar**: `docs/rules/domain/scl-001-learning-loop.md` (referencia a
reconcile como input de `L`/limpieza) — bajo límite SE-311 (150 líneas).

**No tocar**: `CRITERIO.md`, `CONSTITUCION.md`, plugins TS, SaviaLabs.

## 6. Riesgos y rollback

- **Detector ruidoso** (falsos duplicados): solo *propone*; el humano decide.
  Umbral de similitud configurable.
- **Auto-resolve excesivo**: bucket `auto-resolve` solo para `human_authored`
  sobre `INFERRED`, nunca dos `human_authored`.
- **No hay rollback de datos**: nada se borra ni se mueve (solo flags y JSONL).

## 7. OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Reconcile core | `scripts/learning-reconcile.sh` (PURE_BASH+python) | Idéntico (PURE_BASH) |

### Portability classification

- [x] **PURE_BASH**: sin bindings de frontend; corre desde shell.

## 8. Gate de aprobación

Aprobación humana explícita requerida. Antes del PR: `/pr-plan`, `.pr-summary.md`,
rama `agent/scl010-reconcile`. Sin merge ni approve autónomos.

## Referencias

- SCL-007 federación (`docs/specs/SCL-007-federacion-crossdome.spec.md`).
- SPEC-183 reconciliation 3-bucket + `reconciliation-decision-tree.md`.
- SCL-001 S2 (ciclo de vida shadow→active→superseded, CRIT-024).
- CRIT-031 (no auto-activación), CRIT-001 (local), CRIT-024 (cuarentena).