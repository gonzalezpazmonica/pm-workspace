# SCL — Savia Continuous Learning Roadmap

> Roadmap propio del programa **Savia Continuous Learning (SCL)**.
> Nueva era de specs: prefijo `SCL-###` (desacoplada de `SE-###`).
> **Anclaje al roadmap general:** Era 205 en `docs/ROADMAP.md`.
> **Spec fundacional:** `docs/specs/SCL-001-aprendizaje-continuo.spec.md` (APPROVED 2026-08-16, IMPLEMENTED 2026-08-17).

---

## Tesis

La AGI no llega como un modelo preentrenado "terminado", sino como un sistema que
aprende continuamente: arranca con conocimiento mínimo, crece con la experiencia, y sus
"pesos" se gestionan como artefactos de despliegue (canary, shadow, rollback instantáneo).
El cuello de botella ya no es compute, es imaginación: el mecanismo para convertir
experiencia en conocimiento persistente.

**La vuelta para Savia:** Savia ya es la forma agnóstica a LLM de esa tesis — sus "pesos"
son texto versionado en git (CONSTITUCION + CRITERIO + memoria + skills). Lo que falta es
**cerrar el bucle**: hoy el conocimiento entra al sustrato solo por edición manual de la
operadora o por el ledger reconociendo errores *a posteriori*. SCL convierte el sustrato en
un artefacto de despliegue que **aprende de forma continua, medida y agnóstica a LLM**.

## Principios invariantes del programa

1. **El aprendizaje es sustrato, no parámetros.** Cero fine-tuning, cero acoplamiento a
   proveedor (CRIT-002, ADR-012). El modelo es un ejecutor; el bucle es un compilador de
   texto de sesión a sustrato.
2. **Savia propone, la operadora dispone.** El bucle *propone*; la activación
   `human_authored` sigue siendo humana (CRIT-031, ART-11). La CONSTITUCION y CRITERIO
   permanecen intocables por el bucle.
3. **Aprendizaje medido, no declarado.** Ningún "aprendimos" sin `ΔL` medido (p_consistent
   + divergencia + ignorancia resuelta). "Savia no aprendió" es resultado de primera clase.
4. **Por slice, según dolor demostrado.** Ningún slice se adopta por elegancia conceptual;
   se adopta si su benchmark demuestra el dolor (patrón SE-268).

---

## Fases

| Fase | Estado | Contenido | Anclaje |
|---|---|---|---|
| **F0 — Sustrato** | EXISTENTE | CONSTITUCION, CRITERIO (33 INFERRED), memoria (tier-rotate, bitemporal, consolidate), ledger SE-255 S3, calibración SE-255 S4, SaviaVaults (BM25, grafo, entity resolution), Labs L1-L6, p_consistent (SE-292 S6), multi-proveedor (ADR-012) | Eras 125-204 |
| **F1 — Cerrar el bucle** | SCL-001 **IMPLEMENTED** + SCL-001.1 **IMPLEMENTED** (hook captura + correcciones prod) | Captura canónica → ciclo de vida shadow/canary/active → métrica `L` → agnosticismo | **Era 206** |
| **F2 — Persistir + recall operativo** | SCL-002 **IMPLEMENTED** (cúpula SaviaLearning) + SCL-003 **IMPLEMENTED** (recall por prompt) | Cúpula propia de lecciones (persistencia real cross-instancia) + recuperación automática en el momento de trabajar | Era 206 |
| **F3 — Instrumentar Labs + autonomía** | SCL-004 **IMPLEMENTED** (L1 divergencia grafo-modelo → propuesta) + SCL-006 **IMPLEMENTED** (autonomía graduada por p_consistent) | Labs L1 como instrumento del bucle; autonomía L0-L3 graduada por consistencia medida | Era 206 |
| **F4 — Búsqueda híbrida** | SCL-005 **IMPLEMENTED** (venv ~/.savia/venv, recall híbrido BM25+embeddings) | Embeddings híbridos para la divergencia y el recall (ADR-003 Fase 4) | Era 206 |
| **F5 — Federación cross-dome** | SCL-007 **IMPLEMENTED** (share A2A + search-remote + import INFERRED) | Lecciones compartidas entre instancias remotas vía A2A de SaviaVaults | Era 206 |

---

## SCL-001 — Cerrar el bucle (30h, 4 slices) — IMPLEMENTED 2026-08-17

> Detalle completo: `docs/specs/SCL-001-aprendizaje-continuo.spec.md`.
> **Estado: APPROVED 2026-08-16 → IMPLEMENTED 2026-08-17.**
> Artefactos: `scripts/learning-{proposal,lifecycle,rollback,metric,report,guard}.sh`,
> regla `docs/rules/domain/scl-001-learning-loop.md`, 27 tests BATS
> (`tests/test-scl-001-*.bats`). Bucle cerrado verificado por E2E.

| Slice | Objetivo | Esfuerzo | Depende de | Valor | Estado |
|---|---|---|---|---|---|
| S1 — Captura canónica | Artefacto `learning-proposal` unificado, idempotente, registrado en el grafo de SaviaVaults | 7h | hooks de captura, SaviaVaults grafo | Entrada formal del bucle | DONE (5 AC) |
| S2 — Sustrato como artefacto de despliegue | Ciclo de vida shadow→canary→active→superseded + rollback instantáneo | 9h | S1, git, CRIT-024 | Despliegue del conocimiento | DONE (6 AC) |
| S3 — Aprendizaje medido | Métrica `L` = p_consistent + divergencia (L1) + ignorancia resuelta (L2) | 8h | SE-292 S6, Labs L1/L2 | Gate anti-autoengaño | DONE (7 AC) |
| S4 — Agnóstico a LLM | Bucle sobre texto, cero fine-tuning, prueba E2E multi-proveedor | 6h | S1-S3, ADR-012 | Cierra la tesis | DONE (6 AC) |

### Orden recomendado

```
S1 (captura, 7h) → S2 (ciclo de vida + rollback, 9h) → S3 (métrica L, 8h) → S4 (agnosticismo, 6h)
```

S1-S2 son el esqueleto (capturar + desplegar) y se sostienen sin métrica; S3 convierte el
esqueleto en bucle cerrado; S4 es verificación transversal del agnosticismo y necesita los
tres anteriores para su prueba E2E.

### Hitos medibles

- **M1 (S1):** una propuesta de aprendizaje generada por evento, idempotente y consultable
  por grafo. — **CUMPLIDO** (AC-1.1/1.3/1.4).
- **M2 (S2):** una entrada errónea activada y revertida con rollback que restaura el diff.
  — **CUMPLIDO** (AC-2.3, test E2E).
- **M3 (S3):** reporte de ventana que distingue "aprendió" de "no aprendió" con `ΔL` medido.
  — **CUMPLIDO** (AC-3.3).
- **M4 (S4):** sustrato convergente entre dos proveedores sobre el mismo escenario.
  — **CUMPLIDO** (AC-4.1/4.3).

---

## Backlog SCL (futuras, sin especificar)

> **Corrección de numeración 2026-08-22**: SCL-008 ya existe como *"Acoplamiento
> seguro de Criteria, CL y Vaults"* (APPROVED→IMPLEMENTED 2026-08-17). La antigua
> candidata "reconciliación de lecciones" pasa a **SCL-010**. El origen citado
> como "SE-309 knowledge governance" es drift: SE-309 es Anti-sycophancy
> hardening; la reconciliación se apoya en el `reconciler` (SPEC-183) y en
> `docs/rules/domain/reconciliation-decision-tree.md`, no en SE-309.

**Priorización 2026-08-22** (criterios: dolor demostrado > elegancia · CRIT-019
sin medición no hay prioridad · SE-268 por slice):

| Orden | Spec | Tesis | Esfuerzo | Origen | Por qué este orden | Estado |
|---|---|---|---|---|---|---|
| 1 | **SE-334 (integración) S1** | Fingerprint determinista de errores: "este error apareció 47 veces" (hoy: eventos sueltos en telemetry-events.jsonl). Su alert S2 alimenta el hook de captura SCL → los incidentes entran al bucle | ~14h (S1) | superlog / SE-334 spec | Mayor dolor: la telemetría ya existe (SE-313) pero no se puede agrupar ni alimenta el aprendizaje. Pieza determinista pura, sin LLM, alto ROI por hora | SPEC LISTA (PROPOSED 2026-08-17) |
| 2 | **SCL-010** | Reconciliación de lecciones duplicadas/conflictivas entre instancias federadas (SaviaLearning) | ~8h | reconciler (SPEC-183) + árbol de decisión + SE-309 corregido | Desbloqueo de F5: la federación (SCL-007) ya trae lecciones; sin reconciliación se acumulan duplicados que degradan el recall. Reutiliza el 3-bucket ya probado | CANDIDATA |
| 3 | **SCL-009** | Descubrimiento automático de instancias federadas (registro automático) | ~6h | Labs L5 | Conveniencia sobre federación manual (SCL-007 `--share`); menor dolor que 1 y 2 | CANDIDATA |

**Ya integrado en el bucle (2026-08-22, fuera de este backlog):**
- **SE-335** prioridad de descubrimiento (regla eager) + **SE-336** Turn-SDLC
  (auditor F1-F6, DoD gate, telemetría `order_ok`, reporte). SE-336 S4 alimenta
  la métrica `L` (divergencia regla-comportamiento) — ver `scl-001-learning-loop.md`.

**Orden recomendado**: SE-334 S1 (fingerprint) → SE-334 S2 (alerts→captura SCL,
engancha el bucle) → SCL-010 (reconciliación) → SCL-009 (auto-descubrimiento).
SE-334 es spec de otra savia (agent-multi): se consume como integración, no se
reimplementa.

---

## Métricas de programa

| Métrica | Definición | Fuente |
|---|---|---|
| `L` | p_consistent + divergencia grafo-modelo + ignorancia resuelta | SCL-001 S3 |
| p_consistent | fracción de ejecuciones consistentes sobre k intentos | SE-292 S6 |
| Propuestas capturadas/activadas | ratio del embudo shadow→active | SCL-001 S1/S2 |
| `ΔL` por ventana | variación de la métrica entre ventanas | SCL-001 S3 |
| Rollbacks | entradas revertidas con causa registrada | SCL-001 S2 |

---

## Riesgos top

1. **Métrica `L` autoengaña** (mide actividad, no aprendizaje) — mitigación: base
   determinista; si `L` no separa actividad de mejora, S3 se abandona con registro.
2. **Fricción del ciclo de vida → desactivación** — mitigación: shadow invisible por
   defecto, canary opt-in, rollback es un comando.
3. **Sobre-ingeniería** — Savia ya funciona con heurística; cada slice se justifica por
   dolor demostrado, no por elegancia.
4. **"Agnóstico" como excusa para no evaluar el modelo** — el sustrato es agnóstico; el
   modelo se sigue midiendo por `L` y calibración.

---

## Anclaje al roadmap general

- **Era 205** (`docs/ROADMAP.md`): SCL-001 como Tier 0 del roadmap general.
- SCL consume, no rehace: SE-255 (ledger/calibración), SE-268 S4 (memoria dos velocidades),
  SE-292 S6 (p_consistent), SaviaVaults (grafo/provenance), Labs L1-L6.
- La CONSTITUCION y CRITERIO permanecen intocables por el bucle (CRIT-031): el bucle
  propone, la operadora dispone — "la IA propone, el humano dispone".

## SAGI — orquestador AGI sobre el bucle (L11)

El siguiente nivel del programa es **SAGI** (Savia AGI): un algoritmo determinista
versionado que usa el LLM como heurística reemplazable sobre el sustrato SCL. No es
otra capa de SCL — es el orquestador que asocia el bucle en un flujo AGI medible y
autónomo-delegado (límite CRIT-031 intacto). Ver `docs/sagi-roadmap.md` (vista pública
sanitizada; detalle en la cúpula SaviaLabs).
