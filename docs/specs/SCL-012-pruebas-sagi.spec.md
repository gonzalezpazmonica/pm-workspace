# SCL-012 — Pruebas de SAGI: P1-P5 (emergencia medible del orquestador)

**Status:** APPROVED (operadora, 2026-08-22) → IMPLEMENTED 2026-08-22
**Fecha:** 2026-08-22
**Area:** Evaluación / Epistemología / SAGI (L11)
**Línea de investigación:** L11 (SAGI por orquestación)
**Estimación:** ~6h (harness de 5 pruebas sobre el orquestador SCL-011)
**Depende de:** SCL-011 (orquestador)

> **Renumeración (2026-08-22)**: era `labs/specs/SE-336-sagi-pruebas.spec.md`
> (investigación); SE-336 colisionaba con producción (Turn-SDLC). Al pasar a
> producción: SCL-011 (orquestador) + **SCL-012** (pruebas). LP-20260822-5f47cb3d.

---

## 1. Origen

La línea L11 define 5 pruebas de SAGI. Esta spec las operacionaliza como un
harness reproducible sobre `savia-orchestrator.sh` (SCL-011), con instrumentos
existentes (métrica L, recall, autonomía, fed). Disciplina de Labs: preregistro,
resultado negativo de primera clase.

## 2. Pruebas (harness determinista, sin LLM en run-1)

> Run-1 usa fixtures deterministas para validar el **mecanismo**; run-2 (L11,
> privado) robustece con señal real. Cada prueba compara tratamiento (con
> orquestador) vs baseline (sin) a igual presupuesto.

| Prueba | Qué mide | Éxito |
|---|---|---|
| P1 | Aprendizaje continuo: la LP de iteración N se inyecta en N+1; L crece | L(i10) > L(i1) y delta tratamiento-baseline > 0 |
| P2 | Memoria cross-sesión: se "aprende" un hecho, otra sesión lo recupera por recall | Sesión B aplica el hecho; baseline no lo conoce |
| P3 | Criterio estable: 10 dilemas; consulta CRITERIO.md | Misma decisión + mismo CRIT citado en 10/10 |
| P4 | Adaptación a tarea nueva: convergencia de sustrato en tarea no vista | L crece entre iteraciones de tarea no vista |
| P5 | Escalado multi-agente: 2 instancias federadas comparten tarea | Sustrato convergente (misma lección en ambas) |

**Emergencia (R2)**: cada prueba documenta si la mejora aparece SOLO con la
orquestación (no atribuible a un componente aislado) — registro de emergencia
del protocolo L11.

## 3. Acceptance criteria

- [x] AC-1. Harness `scripts/sagi-pruebas.sh` ejecuta P1-P3 con baseline y
  tratamiento a igual presupuesto (fixtures deterministas); P4/P5 opcionales
  (dry-run declarado) por depender de run real/federación.
- [x] AC-2. Cada prueba emite JSON reproducible: {prueba, tratamiento, baseline,
  metrica, delta, veredicto}.
- [x] AC-3. Veredicto agregado: >=2 de 5 con delta positivo → CONFIRMA; si no,
  INCONCLUSO/REFUTA con registro.
- [x] AC-4. Resultado negativo es primera clase: si <2 confirman, el reporte lo
  dice explícitamente (ART-04).

> Verificación 2026-08-22: `bats tests/test-scl-012-pruebas.bats` 8/8.
> Run-1 determinista sobre el orquestador SCL-011: P1, P2, P3 → CONFIRMA.
> P4/P5 declarados dry-run (necesitan run real / federación). Bug de parsing
> `--pruebas` sin valor (exit 2) corregido.

## 4. Riesgos

| Riesgo | Mitigación |
|---|---|
| R1: fixtures sintéticos no validan producción | Run-2 con datos reales (L11 privado); run-1 valida el mecanismo |
| R2: "emergencia" confundida con mejora de componente | Registro de emergencia por prueba (solo con orquestación) |
| R3: presupuesto excedido | Fixtures deterministas (sin LLM) en run-1; presupuesto declarado por prueba |

## 5. Ficheros

**Crear**: `scripts/sagi-pruebas.sh` · `tests/test-scl-012-pruebas.bats`

**No tocar**: CRITERIO/CONSTITUCION, plugins, SaviaLabs (detalle de runs privado
a la cúpula).

## 6. Referencias

- SCL-011 (orquestador), SCL-001 S3 (métrica L), SCL-006 (autonomía), SCL-007 (fed).
- L11: cúpula SaviaLabs (protocolo v1.2). CRIT-031 (todo output = INFERRED).