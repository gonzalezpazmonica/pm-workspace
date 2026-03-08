---
name: sdlc-state-machine
description: sdlc-state-machine
maturity: beta
---

# sdlc-state-machine

**Descripción:** Máquina de estados formal para pipeline SDLC con puertas configurables y políticas de transición.

## Estados del Ciclo de Vida

1. **BACKLOG** — Iniciación. Idea registrada, sin especificar.
2. **DISCOVERY** — Investigación. Criterios de aceptación definidos.
3. **DECOMPOSED** — Descomposición. Dividido en tareas técnicas.
4. **SPEC_READY** — Especificación lista. Documentación técnica completa.
5. **IN_PROGRESS** — Desarrollo activo. Sprint asignado.
6. **VERIFICATION** — Verificación. Pruebas (unitarias, integración, e2e, rendimiento, seguridad).
7. **REVIEW** — Revisión. Code review, aprobación de cambios.
8. **DONE** — Completado. Entregado a producción.

## Transiciones y Puertas (Gates)

Cada transición tiene puertas configurables que deben evaluarse antes de avanzar.

### BACKLOG → DISCOVERY
- **Gate:** PBI tiene criterios de aceptación definidos
- **Verificar:** campo acceptance_criteria no vacío

### DISCOVERY → DECOMPOSED
- **Gate:** Historias técnicas identificadas
- **Verificar:** al menos 3 tareas vinculadas

### DECOMPOSED → SPEC_READY
- **Gate:** Especificación técnica documentada
- **Verificar:** documento spec.md existe y tiene > 200 caracteres

### SPEC_READY → IN_PROGRESS
- **Gate:** Especificación aprobada + revisión de seguridad
- **Verificar:** approval_status=approved, security_review=passed

### IN_PROGRESS → VERIFICATION
- **Gate:** Desarrollo completado, código integrado
- **Verificar:** todos los commits merged, ci_status=passing

### VERIFICATION → REVIEW
- **Gate:** Todos los 5 niveles de verificación pasan
- **Verificar:** unit_tests=passed, integration_tests=passed, e2e_tests=passed, performance_tests=passed, security_tests=passed

### REVIEW → DONE
- **Gate:** Code review aprobado, tests en producción pasan
- **Verificar:** code_review_approved=true, prod_tests=passing, deployment_successful=true

## Persistencia y Auditoría

**Ubicación de estado:** `projects/{project_id}/state/tasks/{task_id}.json`

**Auditoría:** Toda transición se registra con timestamp, actor y resultados de evaluación de puertas.

## Configuración por Proyecto

Las puertas pueden sobrescribirse por proyecto en `projects/{project_id}/policies/sdlc-gates.json`

## Integración con pm-workspace

- Los comandos `/sdlc-status`, `/sdlc-advance`, `/sdlc-policy` proporcionan interfaz.
- La regla `sdlc-gates` define configuración por defecto.
- Auditoría accesible para reportes de cumplimiento y trazabilidad.
