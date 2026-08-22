# SCL-013 — Flujo end-to-end (P6): objetivo multi-paso sin intervención

**Status:** APPROVED (operadora, 2026-08-22) → IMPLEMENTED 2026-08-22
**Fecha:** 2026-08-22
**Area:** Evaluación / Orquestación / SAGI (L11)
**Línea de investigación:** L11 (SAGI por orquestación)
**Estimación:** ~8h
**Depende de:** SCL-011 (orquestador) + SCL-012 (harness de pruebas)

> **Origen**: protocolo L11 v1.2, prueba P6 (test tipo ACI/Suleyman adaptado) y
> roadmap SAGI H6. Esta spec la formaliza como desarrollo; el run-2 real queda
> en la línea L11 (cúpula SaviaLabs, privado).

---

## 1. Problema y objetivo

Las pruebas P1-P3 (SCL-012) validan que el orquestador produce mejoras por
componente (aprendizaje, memoria, criterio). Falta la prueba integradora: que el
orquestador pueda **tomar un objetivo multi-paso del backlog y completarlo en N
pasos sin intervención humana intermedia**, produciendo un artefacto de calidad
verificable y delegando al final para aprobación humana (CRIT-031).

**Tarea de referencia**: partir del estado del workspace y producir una spec
válida completa desde un objetivo declarado (p. ej. `docs/specs/`), en un número
finito de pasos.

**Objetivo medible**: el tratamiento (con orquestador) completa la tarea con
calidad ≥80/100 (auditor determinista) y en menos pasos que el baseline (LLM sin
orquestador). Sin violar CRIT-031: el objetivo se delega explícitamente; el
resultado es propuesta `INFERRED` pendiente de `human_authored`.

## 2. Contratos

### 2.1 `scripts/sagi-e2e.sh`

```text
sagi-e2e.sh --goal "objetivo multi-paso" [--dry-run] [--max-steps N]
  --max-steps   límite de pasos (default 10)
Exit: 0 siempre (reporte) · 2 input inválido · 3 dependencia ausente
```

Harness determinista run-1: simula el flujo del orquestador (LEER→DECIDIR→
VALIDAR→PERSISTIR→MEDIR) con pasos contados y un auditor de calidad 0-100
determinista. Sin LLM (run-1); el run-2 real delega a `savia-orchestrator.sh`.

### 2.2 Métricas

```json
{"goal":"...","steps_used":N,"max_steps":N,"quality":0-100,"delta_pass":true|false,"veredicto":"PASS|FAIL"}
```

- `steps_used`: pasos consumidos (menos = mejor).
- `quality`: auditor determinista (completitud del objetivo, 0-100).
- `delta_pass`: tratamiento completa con `quality>=80` y `steps_used < 10`.

## 3. Reglas de negocio

| ID | Regla | Incumplimiento |
|---|---|---|
| RN-01 | Nunca modifica CRITERIO.md ni CONSTITUCION; resultado solo propuesta | Test de hash invariante |
| RN-02 | `--max-steps` es límite duro; si se supera → veredicto FAIL (no bucle infinito) | Test adversarial |
| RN-03 | Sin LLM en run-1, sin red, sin vendor names (CRIT-001) | Test |
| RN-04 | El objetivo se delega explícitamente (CRIT-031); el e2e no auto-activa | Test |

## 4. Criterios de aceptación

- [x] AC-1. `sagi-e2e.sh` existe, `set -uo pipefail`, bash -n OK, 0 vendor names.
- [x] AC-2. Con `--goal` corto y alcanzable → completa en ≤10 pasos, quality ≥80.
- [x] AC-3. `--dry-run` muestra el plan sin ejecutar.
- [x] AC-4. `--max-steps 2` con goal complejo → FAIL (límite duro respetado).
- [x] AC-5. Emite JSON reproducible con las métricas del contrato.
- [x] AC-6. Hashes de CRITERIO.md/CONSTITUCION.md invariantes tras el run.
- [x] AC-7. Suite BATS ≥ 8 verdes, incluyendo adversariales.

## 5. Ficheros

**Crear**: `scripts/sagi-e2e.sh` · `tests/test-scl-013-e2e.bats`

**No tocar**: CRITERIO/CONSTITUCION, SaviaLabs, plugins, orquestador.

## 6. Riesgos

- **Harness simula calidadd real**: run-1 solo valida el mecanismo; el run-2
  real (L11) mide la calidad con auditor y llama al orquestador. Se declara.
- **Falso positivo por goal trivial**: el goal de fixture es acotado y conocido;
  la calidad la decide un auditor determinista, no el harness.

## 7. Referencias

- SCL-011 (orquestador), SCL-012 (pruebas P1-P5), protocolo L11 v1.2 (P6).
- `docs/sagi-roadmap.md` (H6). CRIT-031 (delegación explícita), CRIT-001 (local).