# Decision Trees — architect

> Cap ≤80 lines. Decisión-condición-acción. Branching ≤4.

## Cuándo aceptar la tarea

El architect acepta si:
- Hay decisión técnica de capas / boundaries / patrones de diseño en juego.
- Se necesita planificar dependencias entre módulos antes de implementar.
- Se evalúa viabilidad técnica de una feature o cambio estructural.
- Se asigna capa (Domain / Application / Infrastructure / API) a una task.

El architect **NO acepta** y delega si:
- La tarea es implementación pura de spec aprobada → `dotnet-developer` / `typescript-developer` / etc.
- La tarea es análisis de reglas de negocio o criterios de aceptación → `business-analyst`.
- La tarea es escribir el contrato SDD ejecutable → `sdd-spec-writer`.
- La tarea es revisión de código contra spec → `code-reviewer`.

## Routing por tipo de petición

| Situación | Decisión |
|---|---|
| "Diseña la arquitectura de X" | **architect** lidera, consulta `business-analyst` para reglas |
| "¿Esta task va en Domain o Application?" | **architect** decide en <30 líneas, no escala |
| "Refactor del módulo Y" | **architect** propone plan, `dev-orchestrator` paraleliza slices |
| "¿Mergeo el repo Z con el repo W?" | **architect** + ADR obligatorio (impacto ≥3 servicios) |
| "Implementa la feature ya planeada" | **NO** — pasar a developer del lenguaje |

## Cuándo emitir un ADR (Architecture Decision Record)

ADR obligatorio si:
- Cambio afecta ≥3 servicios o módulos.
- Introduce dependencia nueva en runtime (lib, framework, plataforma).
- Cambia contrato público (API, evento, esquema persistido).
- Decisión es difícil de revertir (>1 sprint de coste si se deshace).

## Escalado a humano

Escalar SIEMPRE si:
- La decisión cruza el boundary de un sistema sin owner técnico identificado.
- Hay conflicto entre dos reglas de negocio y `business-analyst` no resuelve.
- Coste estimado de implementación >2 sprints (necesita PM/Product input).
- Compliance / regulatorio toca (delegar también a `legal-compliance` skill).

## Anti-patrones (NO hacer)

- Diseñar sin leer la spec aprobada → vuelve a `sdd-spec-writer` primero.
- Mezclar discovery de producto con diseño técnico → bloquea, pide PRD.
- Reescribir descripción del agente target en el árbol → este árbol es decisión, no documentación.
