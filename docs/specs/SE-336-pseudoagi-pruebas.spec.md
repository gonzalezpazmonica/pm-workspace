# SE-336 — Pruebas de pseudo-AGI: P1-P5 (emergencia medible del orquestador)

**Status:** PROPOSED
**Fecha:** 2026-08-20
**Area:** Evaluación / Epistemología / Labs L11
**Línea de investigación:** L11 (pseudo-AGI por orquestación)
**Estimación:** 8h (5 pruebas x 10 iteraciones, fixtures deterministas + corridas flash)
**Depende de:** SE-335 (orquestador)

---

## 1. Origen

La línea L11 define 5 pruebas de pseudo-AGI. Esta spec las operacionaliza con
instrumentos ya existentes (metrica L, recall, divergencia, autonomia) y
criterios de exito falsables, siguiendo la disciplina de Labs (preregistro,
resultado negativo de primera clase).

## 2. Pruebas

### P1 — Aprendizaje continuo sin re-entrenar
- Tarea de referencia: generar una spec SE-### valida.
- 10 iteraciones. Tratamiento: orquestador persiste learning proposals y las
  inyecta via recall. Baseline: LLM sin orquestacion.
- **Exito**: metrica L mejora entre iteracion 1 y 10 en tratamiento, y el
  delta tratamiento-baseline es positivo.

### P2 — Memoria cross-sesion
- Sesion A aprende CRIT-001 (soberania). Sesion B (nueva, sin el hecho) decide
  un caso de soberania.
- **Exito**: sesion B aplica soberania (recall recupera CRIT-001) vs baseline
  que no la conoce.

### P3 — Criterio estable
- 10 dilemas de criterio. Tratamiento: consulta CRITERIO.md. Baseline: LLM solo.
- **Exito**: coherencia = misma decision + mismo CRIT citado en 10/10.

### P4 — Adaptacion a tarea nueva
- Tarea no vista (dome para dominio nuevo). Mide convergencia de sustrato
  (la tarea genera learning proposals que mejoran la siguiente iteracion).
- **Exito**: metrica L crece entre iteraciones de una tarea no vista.

### P5 — Escalado multi-agente
- Dos instancias federadas (SCL-007 A2A) sobre tarea compartida.
- **Exito**: sustrato convergente (misma leccion persistida en ambas).

## 3. Acceptance criteria

- AC-1. Las 5 pruebas se ejecutan con baseline y tratamiento a igual
  presupuesto de tokens (asercion de presupuesto).
- AC-2. Cada prueba emite JSON reproducible: {prueba, tratamiento, baseline,
  metrica, delta, veredicto} (test).
- AC-3. >=2 de 5 pruebas con delta positivo → la linea L11 se marca CONFIRMA;
  si no, INCONCLUSO/REFUTA con registro (test agregado).
- AC-4. Resultado negativo es primera clase: si <2 pruebas confirman, el
  reporte lo dice explicitamente (asercion de honestidad, ART-04).

## 4. Riesgos

| Riesgo | Mitigacion |
|---|---|
| R1: pruebas con fixtures sinteticos no validan produccion | Run-2 con datos reales; run-1 valida el mecanismo (patron de L1-L10) |
| R2: "emergencia" se confunde con mejora de un componente | Cada prueba documenta si la mejora es SOLO con orquestacion (registro de emergencia, protocolo L11) |
| R3: presupuesto excedido | Presupuesto por prueba declarado (120K tokens c/u); abortar si se supera |

## 5. Verification method

1. Suite BATS `tests/test-se-336-pseudoagi.bats` (AC-1..AC-4).
2. E2E: las 5 pruebas sobre el orquestador (SE-335), 10 iteraciones c/u.
3. Resultado agregado → veredicto de la linea L11 en `labs/results/`.

## 6. Referencias

- L11: `labs/hypotheses/l11-pseudo-agi-orquestacion.md`,
  `labs/protocols/l11-pseudoagi-protocol.md`
- SE-335 (orquestador), SCL-001..008, metrica L (SCL-003)
