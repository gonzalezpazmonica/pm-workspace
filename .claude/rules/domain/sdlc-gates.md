# Regla: Configuración de Puertas SDLC

Define las puertas (gates) evaluables para cada transición de estado en el ciclo SDLC.
Puede sobrescribirse por proyecto en `projects/{proyecto}/policies/sdlc-gates.json`.

## Puertas por Transición

### BACKLOG → DISCOVERY
- Gate: acceptance_criteria_present
- Evaluación: Campo `acceptance_criteria` no vacío y >50 caracteres
- Por defecto: ✅ Requerida

### DISCOVERY → DECOMPOSED
- Gate: technical_stories_identified
- Evaluación: ≥3 tareas técnicas vinculadas
- Por defecto: ✅ Requerida

### DECOMPOSED → SPEC_READY
- Gate: spec_documented
- Evaluación: Fichero `spec.md` existe y >200 caracteres
- Por defecto: ✅ Requerida

### SPEC_READY → IN_PROGRESS
- Gate: spec_approved
- Evaluación: approval_status = "approved"
- Por defecto: ✅ Requerida

- Gate: security_review_passed
- Evaluación: security_review = "passed"
- Por defecto: ✅ Requerida

### IN_PROGRESS → VERIFICATION
- Gate: development_completed
- Evaluación: Todos commits merged a main
- Por defecto: ✅ Requerida

- Gate: ci_passing
- Evaluación: ci_status = "passing"
- Por defecto: ✅ Requerida

### VERIFICATION → REVIEW
- Gate: all_tests_pass
- Evaluación: Todos 5 niveles (unit, integration, e2e, perf, security)
- Por defecto: ✅ Requerida

### REVIEW → DONE
- Gate: code_review_approved (true)
- Gate: prod_tests_passing ("passed")
- Gate: deployment_successful (true)
- Por defecto: ✅ Requeridas

## Override por Proyecto

Crear `projects/{proyecto}/policies/sdlc-gates.json` para desactivar puertas específicas.

## Auditoría

Registra por cada transición: timestamp UTC, actor, resultados de puertas, estado final (success/blocked).
