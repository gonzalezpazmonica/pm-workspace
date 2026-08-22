# SAGI Roadmap — Savia AGI por orquestación (L11) · modulo de desarrollo

> **Fuente de verdad**: `labs/` (privado, sin remote) — hipótesis L11, protocolo v1.2
> y plan de ejecución aprobado 2026-08-21. Este documento es su **vista pública
> sanitizada**: roadmap de desarrollo accionable, sin métricas de runs, sin paths
> de `labs/`, sin detalle N2+ (CRIT-001, política de LPs 2026-08-21).
> Estado: vision general — los detalles de cada prueba viven en la cúpula SaviaLabs.

---

## Tesis

SAGI (Savia AGI) plantea que el flujo AGI es **un algoritmo determinista
versionado que usa el LLM como procesador heurístico reemplazable sobre el
sustrato Savia** — no un modelo más grande. Si el LLM cambia, el algoritmo
sigue (ART-01, CRIT-002); si el algoritmo desaparece, el LLM es un chat sin
memoria. El programa SCL ya implementó el sustrato (captura, ciclo de vida,
métrica L, federación): SAGI es el orquestador que lo cierra en un flujo
AGI medible, alineado con los niveles de autonomía (mapeo L0-L3 Savia ↔
DeepMind, política activa) y con el límite innegociable "la IA propone, la
operadora dispone" (CRIT-031).

## Cómo se integra con el roadmap de desarrollo

| Pieza | Estado | Dónde |
|---|---|---|
| Sustrato de aprendizaje (captura→ciclo→métrica L→federación) | F0-F5 implementado | `docs/SCL-ROADMAP.md` |
| Prioridad de descubrimiento (regla eager) | Se-335 merged | `docs/rules/domain/knowledge-discovery-priority.md` |
| Turn-SDLC: auditor de fases + DoD de respuesta + telemetría `order_ok` | SE-336 merged | `docs/specs/SE-336-turn-sdlc.spec.md` |
| **Telemetría de errores → incidentes → aprendizaje** | SE-334 S1+S2 en PR | `docs/specs/SE-334-telemetry-intelligence.spec.md` |
| Orquestador SAGI (fix-loop reusable) | decisión de diseño pendiente | este roadmap |

## Roadmap de desarrollo (por orden)

### H1 — Blindar la telemetría como sensor del bucle (SE-334 S1+S2)
- Fingerprint determinista de errores: agrupar "este error apareció N veces".
- Alerta con umbral que alimenta el hook de captura SCL (el bucle aprende del
  incidente).
- **Estado**: implementado, en PR. Criterio de cierre: 8 BATS verdes + CI.

### H2 — Robustez del agnosticismo (run-3, P1 con un segundo modelo)
- Replicar la prueba de aprendizaje continuo con un modelo distinto (mid/heavy
  o local vía modo de emergencia).
- **Criterio**: si converge igual, el flujo lo produce el algoritmo, no el modelo.
- **Presupuesto**: ~8-10K tokens. **CRIT-001**: local si está disponible; nunca
  datos N3+ a cloud.

### H3 — Criterio estable con señal real (run-3, P3)
- 10 dilemas de criterio; el algoritmo consulta `CRITERIO.md` y mide coherencia
  (misma decisión + mismo CRIT citado).
- **Por qué primero dentro de P2-P4**: más barato, mayor valor de alineación.
- **Requiere**: orquestador SAGI mínimo versionado (paso H5).

### H4 — Memoria cross-sesión y adaptación a tarea nueva (run-3, P2 y P4)
- P2: sesión nueva sin el hecho — el recall recupera la lección y la aplica.
- P4: tarea no vista — convergencia vía skill + cúpula.
- Nota: P2/P4 comparten infraestructura con H3; P2 relevante hoy gracias a
  SE-335 (descubrimiento cúpulas-primero).

### H5 — Decisión de diseño: orquestador en producción vs investigación
- Decidir si el orquestador SAGI se versiona como artefacto de producción
  (fuera de `labs/`) o permanece como línea de investigación.
- **Si pasa**: candidato a guard/fix-loop reutilizable (patrón auditor
  determinista → LP → recall → re-generación).
- **Es el desbloqueo del resto del programa**: sin el orquestador versionado,
  P6 no se puede formalizar como spec de desarrollo.

### H6 — Flujo end-to-end (P6, test tipo nivel "agente" adaptado)
- "Partir del estado del workspace y lograr un objetivo multi-paso en N pasos
  sin intervención" (p. ej. generar una spec válida desde un PBI).
- **Métrica**: pasos (menos = mejor) + calidad final (auditor) + L.
- **Alineación**: eje "agente" de la autonomía, sin violar CRIT-031 (objetivo
  delegado explícitamente; el algoritmo propone, la operadora dispone).

### H7 — Cierre de la línea y vía de retorno
- Validación humana del ledger L11 + decisión de vía de retorno a código
  (objetivo Labs: ≥3 hallazgos con retorno a producción).
- Contribuciones L11 hasta la fecha: convergencia por auditor-determinista,
  mapeo de autonomía (política activa). Pendiente un tercer hallazgo.

## Dependencias entre hitos

```text
H1 (telemetría) está en PR y no bloquea a H2-H4
H2 (agnosticismo) puede correr sobre labs/ sin producción
H3 (criterio estable) y H4 (memoria/adaptación) → requieren el orquestador mínimo → H5
H5 (decisión de diseño) desbloquea H6 (end-to-end)
H7 (cierre) depende de ≥2 pruebas con mejora medible
```

## Criterios humanos aplicables

- **CRIT-001**: todo run de SAGI en `labs/` (infraestructura propia, sin remote);
  este roadmap y cualquier artefacto de producción no filtran métricas de runs
  ni datos N3+. Detalle de los runs permanece en SaviaLabs.
- **CRIT-031 / ART-11**: ninguna prueba auto-activa sustrato; todo fin en
  propuesta `INFERRED` pendiente de `human_authored`. P6 delega el objetivo por
  decisión humana explícita.
- **Rule #8 (SDD)**: H6 se implementa como spec aprobada antes de orquestación.

## Primer PR de desarrollo a crear desde este roadmap

H2 (agnosticismo, run-3 P1 con segundo modelo) — no requiere orquestador nuevo,
corre íntegro en `labs/` y su lección se sanitiza al repo. Alternativa
priorizable si el orquestador es inminente: **H5 como spec de decisión** para
fijar dónde vive el orquestador y su contrato antes de escribir más runs.