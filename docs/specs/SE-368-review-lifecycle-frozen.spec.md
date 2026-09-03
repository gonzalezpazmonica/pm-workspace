# SE-368 — Review Lifecycle congelado: un registro de autoridad por lineage

**Status:** PROPOSED (2026-09-02, para aprobación de la operadora)
**Fecha:** 2026-09-02
**Área:** Code Review / Courts / Proceso PR
**Fuente de inspiración:** review lifecycle "freeze → review → correct ≤1 vez → close en el último evento causal" con un solo registro de autoridad por lineage (análisis release open-source 2026-09-02)
**Criterio humano aplicable:** CRIT-001 (todo local)

---

## 1. Motivación

El flujo de revisión de Savia (pr-plan gates, courts, Code Review Court) tiene el
concepto de revisar, pero **no congela el candidato** de forma explícita ni
mantiene **un único registro de autoridad por lineage** (rama/PR/cambio). En la
práctica, un PR puede revisarse contra versiones que cambian a mitad del proceso,
dos fases pueden leer "dos representaciones de la misma verdad", y el cierre no
se ata a un **último evento causal** — aparece un commit, re-revisión, otro
commit, y el "fin" queda ambiguo.

La lección del modelo de referencia: **freeze una vez, revisa los bytes
congelados, corrige como mucho una vez, cierra en el último evento causal**. Un
solo registro (por `cwd + lineage`) gobierna todo el ciclo: binding, epoch,
revisión admitida, resultados de refutador/validador, estado de corrección y
disposición terminal. Nada lee dos representaciones de la misma verdad a mitad
de serie.

## 2. Alcance

**Dentro:**
- Semántica de "candidato congelado" (digest del diff/bytes revisados)
- Registro único de autoridad por lineage (rama/PR) con su ciclo completo
- Cierre en el último evento causal (sin FINALIZE post-evidencia)
- Integración con push-pr.sh / pr-plan / courts

**Fuera:**
- Cambio del sistema de gates existente (aditivo)
- UI de revisión (CLI)

## 3. Principios de diseño

1. **Congelar, no re-leer**: al empezar una revisión, se congela el digest del
   estado a revisar; la revisión trabaja sobre esos bytes, no sobre `main` que
   avanza.
2. **Un registro por lineage**: `agent/rama-cambio` tiene un único ledger de
   revisión (frozen digest, epoch, admitted lens, resultados, corrección,
   disposición). No hay dos archivos con la misma verdad.
3. **Cierre en el último evento causal**: cuando la evidencia está completa, la
   revisión cierra; los gates de entrega posteriores (CI/hooks) son política
   ordinaria del repo, no re-abren la revisión.
4. **Corrección acotada**: tras congelar, se permite corregir (como mucho una
   iteración) y re-congelar; no un bucle abierto.
5. **Aprobación terminal y reconocida**: el approve final consume un token
   pendiente y quema el lineage (análogo a grants SE-343 one-shot).
6. **CRIT-001**: todo local.

## 4. Formato del registro

`data/review-ledger/<lineage>.json`:

```json
{
  "lineage": "agent/changelog-fix-20260902",
  "frozen": {
    "digest": "sha256:<del diff>",
    "head": "f1665dc7",
    "frozen_at": "2026-09-02T19:00:00Z"
  },
  "epoch": 1,
  "admitted_lens": ["correctness", "spec", "security"],
  "results": {
    "refuter": {"verdict": "PASS", "at": "..."},
    "validator": {"verdict": "PASS", "at": "..."}
  },
  "corrections": 0,
  "terminal": {
    "disposition": "APPROVED" | "REJECTED" | "CHANGES_REQUESTED",
    "closed_at": "2026-09-02T19:30:00Z",
    "last_causal_event": "f1665dc7"
  },
  "acknowledged": false
}
```

## 5. Diseño técnico

### 5.1 `scripts/review-lifecycle.sh` (registro + transiciones)

- `freeze <lineage> [--head SHA]`: congela el digest actual del diff; crea/avanza
  el registro único. Rechaza si ya existe un registro abierto (no dos verdades).
- `state <lineage>`: muestra el registro actual (frozen digest, epoch, estado).
- `correct <lineage>`: marca una corrección (acotada, configurable ≤N).
- `close <lineage> --disposition APPROVED|REJECTED`: cierra en el último evento
  causal; disposición terminal.
- `acknowledge <lineage>`: consume el token pendiente (one-shot), quema el
  lineage (marca acknowledged). Solo la invocación exacta lo consume.
- `--validate`: un registro no puede tener dos disposiciones; no se cierra sin
  frozen digest; acknowledge solo tras APPROVED.

### 5.2 Integración

- `push-pr.sh`: al crear el PR, `freeze` el lineage.
- Courts: al terminar, escriben su resultado al registro (admitted lens).
- `pr-plan.sh`: al final (aprobado), `close` + (si procede) `acknowledge`.
- Los gates de CI existentes siguen siendo política ordinaria; no re-abren.

## 6. Criterios de aceptación

- **AC-0** `freeze` congela digest y rechaza segundo open (test)
- **AC-1** Un registro por lineage: crear dos → error (test)
- **AC-2** `close` ata la disposición al último evento causal (test)
- **AC-3** `acknowledge` consume el token una sola vez (segundo → no-op) (test)
- **AC-4** Corrección acotada: superar el límite → bloqueado (test)
- **AC-5** `--validate` detecta doble disposición (test)
- **AC-6** Integración: push-pr.sh congela; pr-plan cierra; sin regresión en
  gates existentes

## 7. OpenCode Implementation Plan

### Bindings touched
- `scripts/review-lifecycle.sh` (nuevo)
- `data/review-ledger/` (nuevo)
- `push-pr.sh`, `pr-plan.sh` (hooks freeze/close)
- Courts (escriben resultado al registro)

### Verification protocol
```bash
bats tests/bats/test-review-lifecycle.bats
bash scripts/review-lifecycle.sh freeze agent/test-lineage --head HEAD
bash scripts/review-lifecycle.sh state agent/test-lineage
bash scripts/review-lifecycle.sh close agent/test-lineage --disposition APPROVED
bash scripts/review-lifecycle.sh acknowledge agent/test-lineage
```

### Portability classification
- Bash + JSON; local; portable; CRIT-001

## Referencias
- Review lifecycle congelado con registro de autoridad por lineage (concepto,
  análisis 2026-09-02)
- Savia: SE-343 (grants one-shot), pr-plan (G0-G18), courts, push-pr.sh,
  autonomous-safety.md, CRIT-001
