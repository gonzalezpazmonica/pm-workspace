# SE-367 — Derivation Path: cadena causal completa en veredictos y hechos derivados

**Status:** PROPOSED (2026-09-02, para aprobación de la operadora)
**Fecha:** 2026-09-02
**Área:** Verificación / Courts / Razonamiento
**Fuente de inspiración:** razonamiento con reglas y derivación que expande la cadena hasta la sentencia original (análisis open-source 2026-09-02) + Savia L28 M2 (verifier grounds contra trace)
**Criterio humano aplicable:** CRIT-001 (todo local, sin egress)

---

## 1. Motivación

Los tribunals de Savia emiten veredictos, pero el veredicto normalmente no
expone **cómo se llegó a él** de forma expandible: qué regla/criterio se aplicó,
sobre qué premisas, y cuál es la fuente original de cada premisa. Un veredicto
sin derivation path es una conclusión sin el razonamiento que la sostiene —
difícil de auditar y de re-ejecutar.

El modelo de referencia (derivación con reglas) expande la cadena de un hecho
derivado hasta la **sentencia original** que lo sustenta. Aplicado a Savia: un
veredicto de court debe poder expandir su ruta completa — criterio aplicado →
premisas → refs/evidencia originales → tools observadas en el trace (grounding
de L28 M2).

## 2. Alcance

**Dentro:**
- Formato de derivation path en veredictos (regla, premisas, refs, trace ids)
- Registro del path junto al veredicto (persistente, no solo en pantalla)
- Expansión del path: de la conclusión a la cadena completa de premisas
- Integración con courts/tribunals existentes y con L28 M2 (grounding)

**Fuera:**
- Motor de reglas formal (no Datalog nuevo): Savia usa courts bash/python, no
  un motor simbólico
- Reescritura del sistema de veredictos existente (aditivo)

## 3. Principios de diseño

1. **Todo veredicto lleva su path**: regla(s) aplicada(s), premisas, refs citadas
   y (si aplica) eventos del trace observados.
2. **Expandible**: un path puede referenciar sub-paths (premisa que es a su vez
   conclusión de otra regla) → la cadena completa es derivable.
3. **Grounded (L28 M2)**: cada claim del veredicto referencia o bien un ref
   existente o bien un evento del trace realmente observado — nunca una tool
   no ejecutada.
4. **Aditivo**: los veredictos actuales ganan el campo path sin romper consumo
   existente.
5. **CRIT-001**: todo local.

## 4. Formato (aditivo al veredicto)

```json
{
  "verdict_id": "court-20260902-014",
  "judge": "correctness-judge",
  "outcome": "FAIL",
  "path": {
    "rule": "CRITERIO#no-conflicto-intereses",
    "premises": [
      {"rule": "trace:tool_observed", "ref": "trace#t-118", "ground": true},
      {"rule": "ref:source_exists", "ref": "docs/rules/domain/x.md"}
    ],
    "evidence": [
      {"ref": "docs/specs/SE-365.spec.md", "quote": "..."},
      {"trace_event": "tool_blocked", "tool": "git push", "observed": true}
    ]
  }
}
```

## 5. Diseño técnico

### 5.1 `scripts/verdict-path.sh` (wrapper) + `scripts/verdict-path.py` (lógica)

- `attach <verdict_json> --rule R --premises P --evidence E`: adjunta el path a
  un veredicto (valida premisas/refs/grounding).
- `expand <verdict_id>`: expande el path a la cadena completa (premisas →
  sub-paths → refs/trace originales).
- `--validate`: comprueba que cada `ref` existe y que los `trace_event`
  declarados como `ground:true` están en el trace real (integra L28 M2).

### 5.2 Persistencia

- Veredictos con path en `data/verdicts/` (o donde courts ya escriban) —
  aditivo: campo `path` nuevo.

### 5.3 Integración con courts

- Los courts/judges existentes pueden emitir `path` al final de su veredicto
  (regla aplicada = su propia rúbrica; premisas = inputs; evidence = refs).
- `verdict-path.py --validate` se puede invocar como gate de salida del court.

## 6. Criterios de aceptación

- **AC-0** `attach` valida y adjunta el path (test con fixture de veredicto)
- **AC-1** `expand` devuelve la cadena completa (premisas anidadas) (test)
- **AC-2** `--validate` marca `ground:true` con trace_event no observado → FAIL
  (refuerza L28 M2) — test
- **AC-3** Ref inexistente → WARN (test)
- **AC-4** Veredictos existentes sin path siguen siendo consumibles (no regresión)
- **AC-5** Un court real emite veredicto con path válido (test de integración)

## 7. OpenCode Implementation Plan

### Bindings touched
- `scripts/verdict-path.py` (nuevo), `scripts/verdict-path.sh` (wrapper)
- Courts/judges existentes (aditivo: emiten `path`)
- `data/verdicts/` (donde corresponda)

### Verification protocol
```bash
bats tests/bats/test-verdict-path.bats
python3 scripts/verdict-path.py attach --fixture
python3 scripts/verdict-path.py expand court-20260902-014
python3 scripts/verdict-path.py --validate court-20260902-014
```

### Portability classification
- Python3 stdlib + JSON; local; portable; CRIT-001

## Referencias
- Derivación con reglas expandible a fuente original (concepto, análisis 2026-09-02)
- Savia: L28 M2 (grounding verifier→trace), courts/tribunals, source-traceability,
  CRIT-001
