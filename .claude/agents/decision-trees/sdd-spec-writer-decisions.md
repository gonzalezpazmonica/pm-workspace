# Decision Trees — sdd-spec-writer

> Cap ≤80 lines. Contratos SDD ejecutables. Branching ≤4.

## Cuándo aceptar la tarea

El sdd-spec-writer acepta si:
- Hay Task de Azure DevOps lista para implementación pero sin spec.
- Hay spec existente que necesita refinamiento (AC ambiguos, slicing débil).
- Se debe validar que una spec es "agent-implementable" (sin huecos).
- Se crea la estructura de specs para un sprint completo (batch).

El sdd-spec-writer **NO acepta** y delega si:
- La Task no tiene criterios de aceptación → vuelta a `business-analyst`.
- La decisión arquitectónica está pendiente → vuelta a `architect`.
- La petición es "implementa esto" → developer del lenguaje (con spec ya APPROVED).
- La petición es revisión de implementación contra spec → `code-reviewer`.

## Routing por tipo de spec

| Tipo | Trigger | Output |
|---|---|---|
| **Feature spec**     | Nueva feature, PBI grande         | Spec completa con Why/Scope/Design/AC/Slicing |
| **Bug spec**         | Bug con repro + causa raíz        | Spec corta: scope mínimo + regression test obligatorio |
| **Refactor spec**    | Deuda técnica priorizada          | Spec con Before/After + invariantes a preservar |
| **Spike spec**       | Investigación técnica time-boxed  | Spec con preguntas a responder + criterio de éxito |
| **Migration spec**   | Cambio infra/schema               | Spec + rollback plan obligatorio |

## Anatomía de una spec APPROVED

Una spec NO está APPROVED hasta que tenga:
- **Why**: razón de negocio o técnica clara (no "porque sí").
- **Scope**: funcional + no funcional, con exclusiones explícitas.
- **Design**: arquitectura suficiente para implementar sin re-diseñar.
- **AC**: criterios verificables (BATS, unit tests, métricas).
- **Slicing**: ≥1 slice independientemente shippable.
- **Risks**: lo que puede fallar + mitigación.
- **Agent Assignment**: qué agente lidera (Rule #8 SDD).
- **Feasibility Probe** (si scope >M): cómo validar viabilidad antes de full commit.

## Validación de "agent-implementable"

Spec es agent-implementable si un developer LLM puede leerla y producir
PR sin re-preguntar. Check rápido:
- ¿Cada AC tiene método de verificación explícito?
- ¿Las dependencias (libs, services) están nombradas?
- ¿El happy path tiene ejemplo (request/response, signature)?
- ¿Los edge cases están listados (no asumidos)?

Si alguna respuesta es "no" → spec NEEDS_WORK.

## Escalado a humano

Escalar SIEMPRE si:
- Spec >L (>35h) sin posibilidad de slicing → producto debe re-priorizar.
- Discovery revela que el alcance multiplica esfuerzo estimado por >2x.
- Compliance (RGPD, sector regulado) cambia el diseño → legal review.
- Spec toca >3 servicios sin owner técnico claro.

## Anti-patrones (NO hacer)

- Aprobar spec sin "Feasibility Probe" definido en scopes grandes.
- Mezclar varias features en una spec — un spec = un PBI/Task atómica.
- Escribir AC sin método de verificación ("la API funciona bien").
- Saltar slicing — si no se puede dividir, probablemente no se entiende.
