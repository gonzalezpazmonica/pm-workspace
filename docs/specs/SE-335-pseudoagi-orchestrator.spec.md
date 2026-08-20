# SE-335 — Orquestador de pseudo-AGI: integra sustrato, cúpulas, criterio y bucle SCL

**Status:** PROPOSED
**Fecha:** 2026-08-20
**Area:** Orquestación / Epistemología / Labs L11
**Línea de investigación:** L11 (pseudo-AGI por orquestación)
**Estimación:** 16h (5 pruebas P1-P5)
**Base verificada:** origin/main 2026-08-20 — SCL-001..008 IMPLEMENTED, SaviaVaults v0.2 (SaviaLearning, federación A2A), CRITERIO.md (34 entradas), SE-334 hardening

---

## 1. Origen — el gap del programa

SCL-001..008 implementaron el bucle de aprendizaje **cerrado, medido y
agnóstico**; SaviaVaults v0.2 provee memoria en cúpulas con grafo y federación;
CRITERIO.md es la autoridad única de criterio (SCL-008). Cada componente existe
y funciona aislado. **Lo que no existe es el orquestador que los integra en un
bucle de decisión continuo.**

La hipótesis de la línea L11: al componer los 4 pilares (sustrato + cúpulas +
criterio + bucle SCL) con un orquestador mínimo, el sistema muestra
**comportamiento de pseudo-AGI emergente** — aprendizaje sin re-entrenar,
memoria cross-sesión, criterio estable, adaptación a tarea nueva y escalado
multi-agente — que ningún componente aislado exhibe.

**Objetivo de negocio medible**: >=2 de 5 pruebas (P1-P5) muestran mejora
medible sobre baseline (metrica L, coherencia de criterio o convergencia de
sustrato).

**Trade-off explícito**: el orquestador es PURE_BASH mínimo (~200 líneas) que
COMPONE los scripts existentes; no reimplementa nada. "Pseudo-AGI" =
comportamiento emergente medible, NO consciencia (SCL-001 S1 anti-deriva).
CRITERIO y CONSTITUCION intocables (CRIT-031, ART-11); el orquestador propone,
la operadora dispone.

## 2. Diseño — orquestador mínimo

```
            ┌────────────────────────────────────────────────┐
            │  orchestrator (PURE_BASH, ~200 lineas)         │
            │                                                │
  tarea ──► │  LEER: CRITERIO.md (human_authored) + cupula   │
            │        (recall BM25/hibrido) + learning props  │
            │  DECIDIR: LLM flash con contexto sustrato      │
            │  PERSISTIR: learning-proposal --persist        │
            │  MEDIR: learning-metric.sh (L)                 │
            │  AJUSTAR: autonomia por p_consistent           │
            └────────────────────────────────────────────────┘
```

**Script**: `scripts/savia-orchestrator.sh`
- No toca los scripts existentes (los compone).
- Usa `learning-recall.sh` (SCL-003/005), `learning-proposal.sh --persist`
  (SCL-001/002), `learning-metric.sh` (SCL-003), `learning-autonomy.sh`
  (SCL-006).
- Agnóstico a LLM (PURE_BASH + flash), sin vendor names (guard SCL-004).

## 3. Acceptance criteria

- AC-1. El orquestador existe (`savia-orchestrator.sh`), `set -uo pipefail`,
  bash -n OK, guard de agnosticismo CLEAN (0 vendor names) (asercion).
- AC-2. Dada una tarea, ejecuta el ciclo completo LEER→DECIDIR→PERSISTIR→MEDIR
  y emite un reporte con la métrica L (test E2E).
- AC-3. No escribe fuera del sustrato (markdown/JSONL) salvo el reporte (test).
- AC-4. No modifica CRITERIO.md ni CONSTITUCION (hash invariante tras N ciclos)
  (test).
- AC-5. `--dry-run` muestra el plan sin ejecutar (test).

## 4. Riesgos

| Riesgo | Mitigación |
|---|---|
| R1: el orquestador duplica lógica existente | Compone scripts, no reimplementa (AC-1/AC-2) |
| R2: "pseudo-AGI" se vuelve afirmación vacía | Solo se afirma si P1-P5 muestran mejora medible (L11) |
| R3: auto-modificación del criterio | CRITERIO/CONSTITUCION intocables (AC-4, CRIT-031) |
| R4: coste de integración alto | Presupuesto declarado (600K tokens); fallback: probar P2/P3 primero (memoria y criterio) |

## 5. Verification method

1. Suite BATS `tests/test-se-335-orchestrator.bats` (AC-1..AC-5).
2. E2E: tarea de referencia (spec) con 10 iteraciones → metrica L mejora
   (P1 de L11).
3. Guard de agnosticismo CLEAN.

## 6. Referencias

- L11: `labs/hypotheses/l11-pseudo-agi-orquestacion.md`,
  `labs/protocols/l11-pseudoagi-protocol.md`
- SCL-001..008, SaviaVaults v0.2, CRITERIO.md, SE-334
