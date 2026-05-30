# Decision Trees — dev-orchestrator

> Cap ≤80 lines. Planificación de implementación. Branching ≤4.

## Cuándo aceptar la tarea

El dev-orchestrator acepta si:
- Hay una Spec SDD APPROVED y se necesita plan de slices ejecutable.
- Existe spec previa pero el plan original cayó (cambio de scope, slice ya implementado).
- Se pide presupuesto de contexto/tokens para un sprint multi-spec.
- Se necesita análisis de dependencias entre slices antes de fan-out a developers.

El dev-orchestrator **NO acepta** y delega si:
- La Spec no está APPROVED (status DRAFT/NEEDS_WORK) → vuelta a `sdd-spec-writer`.
- La decisión arquitectónica de fondo falta → `architect` primero.
- La petición es "implementa esto ya" sin plan → developer del lenguaje (si Spec basta).
- La petición es revisión post-implementación → `court-orchestrator`.

## Routing por tamaño de Spec

| Tamaño efectivo | Slices recomendados | Estrategia |
|---|---|---|
| **XS/S (≤8h)**   | 1 slice               | Plan mínimo: 1 developer, 1 PR |
| **M (8-24h)**    | 2-3 slices            | Slices verticales independientemente shippables |
| **L (24-40h)**   | 3-5 slices + DAG      | Identificar dependencias críticas, paralelizar lo que se pueda |
| **XL (>40h)**    | NO PLANIFICAR         | Devolver a `sdd-spec-writer` para re-slicing |

## Reglas de slicing

Un slice válido cumple TODAS:
- Independientemente shippable (PR mergeable sin esperar otro slice).
- ≤8000 tokens de contexto necesario (cap `max_context_tokens` del developer).
- ≥1 AC verificable de la Spec lo cubre completamente.
- No requiere cambios en >5 ficheros nuevos + >5 ficheros editados.

Si un slice viola algo → re-cortar antes de fan-out.

## Estimación de tokens

Para cada slice estimar antes de aprobar el plan:
- **Read budget**: tamaño en líneas de ficheros que el developer DEBE leer.
- **Write budget**: tamaño objetivo del output (código + tests).
- **Tool calls**: nº esperado de Edit/Write/Bash.

Si total >8500 tokens del slice → re-cortar (no estirar el budget).

## Análisis de dependencias

Antes de emitir el plan:
- Mapear dependencias entre slices: `S1 → S2` si S2 importa código creado en S1.
- Slices independientes → marcar `parallel: true` para fan-out simultáneo.
- Slices con cadena lineal → secuenciar con handoff claro entre PRs.
- Detectar ciclos → indica slicing roto → devolver a re-slicing.

## Escalado a humano

Escalar SIEMPRE si:
- El plan requiere >5 slices → riesgo de scope creep, validar con PM.
- Existe ambigüedad sobre qué developer/lenguaje asignar a un slice.
- La Spec tiene `Feasibility Probe` pendiente → no planificar hasta resolver.
- Algún slice necesita L4 permissions (infra, court) → exigir aprobación previa.

## Anti-patrones (NO hacer)

- Crear slices "horizontales" (todos los tests primero, todo el código después).
- Slices con dependencias circulares — síntoma de mal entendimiento de la Spec.
- Inflar token budget para evitar re-cortar — el cap es contrato, no sugerencia.
- Asignar developer sin verificar `permission_level` y `tools` disponibles.
- Emitir plan sin DAG explícito cuando hay >2 slices.
