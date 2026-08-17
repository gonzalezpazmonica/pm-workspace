# SCL — Savia Continuous Learning Roadmap

> Roadmap propio del programa **Savia Continuous Learning (SCL)**.
> Nueva era de specs: prefijo `SCL-###` (desacoplada de `SE-###`).
> **Anclaje al roadmap general:** Era 205 en `docs/ROADMAP.md`.
> **Spec fundacional:** `docs/specs/SCL-001-aprendizaje-continuo.spec.md` (PROPOSED 2026-08-16).

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
| **F1 — Cerrar el bucle** | SCL-001 PROPOSED | Captura canónica → ciclo de vida shadow/canary/active → métrica `L` → agnosticismo | **Era 205** |
| **F2 — Federar el aprendizaje** | SCL-002 (candidata) | Aprendizaje cross-dome, divergencia entre instancias (Labs L5) | Era 206+ |
| **F3 — Instrumentar Labs** | SCL-003 (candidata) | Ejecutar Labs L1-L6 como instrumentos del bucle (SE-291 S2-S8) | Era 206+ |
| **F4 — Búsqueda híbrida** | SCL-004 (candidata) | Embeddings híbridos para la métrica de divergencia (ADR-003, Fase 4) | Era 206+ |

---

## SCL-001 — Cerrar el bucle (30h, 4 slices)

> Detalle completo: `docs/specs/SCL-001-aprendizaje-continuo.spec.md`.

| Slice | Objetivo | Esfuerzo | Depende de | Valor |
|---|---|---|---|---|
| S1 — Captura canónica | Artefacto `learning-proposal` unificado, idempotente, registrado en el grafo de SaviaVaults | 7h | hooks de captura, SaviaVaults grafo | Entrada formal del bucle |
| S2 — Sustrato como artefacto de despliegue | Ciclo de vida shadow→canary→active→superseded + rollback instantáneo | 9h | S1, git, CRIT-024 | Despliegue del conocimiento |
| S3 — Aprendizaje medido | Métrica `L` = p_consistent + divergencia (L1) + ignorancia resuelta (L2) | 8h | SE-292 S6, Labs L1/L2 | Gate anti-autoengaño |
| S4 — Agnóstico a LLM | Bucle sobre texto, cero fine-tuning, prueba E2E multi-proveedor | 6h | S1-S3, ADR-012 | Cierra la tesis |

### Orden recomendado

```
S1 (captura, 7h) → S2 (ciclo de vida + rollback, 9h) → S3 (métrica L, 8h) → S4 (agnosticismo, 6h)
```

S1-S2 son el esqueleto (capturar + desplegar) y se sostienen sin métrica; S3 convierte el
esqueleto en bucle cerrado; S4 es verificación transversal del agnosticismo y necesita los
tres anteriores para su prueba E2E.

### Hitos medibles

- **M1 (S1):** una propuesta de aprendizaje generada por evento, idempotente y consultable
  por grafo.
- **M2 (S2):** una entrada errónea activada y revertida con rollback que restaura el diff.
- **M3 (S3):** reporte de ventana que distingue "aprendió" de "no aprendió" con `ΔL` medido.
- **M4 (S4):** sustrato convergente entre dos proveedores sobre el mismo escenario.

---

## Backlog SCL (futuras, sin especificar)

| Spec | Tesis | Origen | Estado |
|---|---|---|---|
| SCL-002 | Aprendizaje federado: el sustrato aprende de instancias que divergen | Labs L5 + SE-282 | CANDIDATA |
| SCL-003 | Ejecutar Labs L1-L6 como instrumentos permanentes del bucle | SE-291 S2-S8 | CANDIDATA |
| SCL-004 | Embeddings híbridos para medir divergencia grafo-modelo con recall | ADR-003 (Fase 4) | CANDIDATA |
| SCL-005 | p_consistent como política de autonomía graduada | SE-292 S6 + ADR-010 | CANDIDATA |

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
