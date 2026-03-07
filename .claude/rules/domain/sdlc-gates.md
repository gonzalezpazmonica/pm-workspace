# Regla: Configuración de Puertas SDLC
# ── Políticas de transición, overrides por proyecto, auditoría ─────────────

> Define las puertas (gates) evaluables para cada transición de estado en el ciclo SDLC.
> Puede sobrescribirse por proyecto en `projects/{proyecto}/policies/sdlc-gates.json`.

## Puertas por Transición

### BACKLOG → DISCOVERY
- **Gate:** acceptance_criteria_present
  - **Descripción:** PBI tiene criterios de aceptación definidos
  - **Evaluación:** Campo `acceptance_criteria` no vacío y >50 caracteres
  - **Por defecto:** ✅ Requerida

### DISCOVERY → DECOMPOSED
- **Gate:** technical_stories_identified
  - **Descripción:** Se han identificado historias técnicas
  - **Evaluación:** ≥3 tareas técnicas vinculadas con relación "Child"
  - **Por defecto:** ✅ Requerida

### DECOMPOSED → SPEC_READY
- **Gate:** spec_documented
  - **Descripción:** Especificación técnica documentada
  - **Evaluación:** Fichero `spec.md` existe y >200 caracteres
  - **Por defecto:** ✅ Requerida

### SPEC_READY → IN_PROGRESS
- **Gate:** spec_approved
  - **Descripción:** Especificación aprobada
  - **Evaluación:** Campo `approval_status` = "approved"
  - **Por defecto:** ✅ Requerida

- **Gate:** security_review_passed
  - **Descripción:** Revisión de seguridad completada
  - **Evaluación:** Campo `security_review` = "passed"
  - **Por defecto:** ✅ Requerida

### IN_PROGRESS → VERIFICATION
- **Gate:** development_completed
  - **Descripción:** Desarrollo completado, código integrado
  - **Evaluación:** Todos los commits en rama asociada están merged a main
  - **Por defecto:** ✅ Requerida

- **Gate:** ci_passing
  - **Descripción:** CI pipeline pasando
  - **Evaluación:** Campo `ci_status` = "passing"
  - **Por defecto:** ✅ Requerida

### VERIFICATION → REVIEW
- **Gate:** all_tests_pass
  - **Descripción:** Todos los 5 niveles de verificación pasan
  - **Evaluación:** unit_tests + integration_tests + e2e_tests + perf_tests + security_tests = "passed"
  - **Por defecto:** ✅ Requerida

### REVIEW → DONE
- **Gate:** code_review_approved
  - **Descripción:** Code review aprobado
  - **Evaluación:** Campo `code_review_approved` = true
  - **Por defecto:** ✅ Requerida

- **Gate:** prod_tests_passing
  - **Descripción:** Tests en producción pasan
  - **Evaluación:** Campo `prod_tests` = "passing"
  - **Por defecto:** ✅ Requerida

- **Gate:** deployment_successful
  - **Descripción:** Despliegue a producción exitoso
  - **Evaluación:** Campo `deployment_successful` = true
  - **Por defecto:** ✅ Requerida

## Override por Proyecto

Crear `projects/{proyecto}/policies/sdlc-gates.json`:

```json
{
  "version": 1,
  "policies": {
    "BACKLOG_to_DISCOVERY": {
      "acceptance_criteria_present": {
        "enabled": true,
        "override_reason": "Requerido para este proyecto"
      }
    },
    "SPEC_READY_to_IN_PROGRESS": {
      "security_review_passed": {
        "enabled": false,
        "override_reason": "Proyecto sin requisitos de seguridad"
      }
    }
  }
}
```

## Auditoría

Cada transición registra:
- Timestamp ISO 8601 UTC
- Actor (usuario que ejecutó la transición)
- Resultados de cada puerta: pass/fail + evidencia
- Estado final (success/blocked)

Ejemplo en `projects/{proyecto}/state/tasks/PBI-001.json`:
```json
{
  "transitions_log": [
    {
      "from": "SPEC_READY",
      "to": "IN_PROGRESS",
      "timestamp": "2026-03-07T11:30:00Z",
      "actor": "monica.gonzalez@company.com",
      "gate_results": {
        "spec_approved": { "pass": true, "evidence": "approval_status=approved" },
        "security_review_passed": { "pass": false, "evidence": "security_review=pending" }
      },
      "status": "blocked",
      "blockers": ["security_review_passed"]
    }
  ]
}
```

## Convenciones de Evaluación

- **Campos booleanos:** true/false directo
- **Enumeraciones:** comparar contra valores esperados (e.g., "passed", "approved")
- **Contadores:** ≥ umbral especificado
- **Ficheros:** existencia + tamaño mínimo
- **Relaciones:** contar items vinculados con relación específica

Todas evaluables sin intervención humana (deterministas).
