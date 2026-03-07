---
name: qa-wizard
description: Interactive wizard for QA engineer onboarding
---

---

# QA Wizard

**Aliases:** qa, qa-actions

**Arguments:** `$ARGUMENTS` = action (test-plan | bug-report | validate | regression)

**Description:** Structured wizard for QA engineers. Step-by-step guided flows for test planning, bug reporting, acceptance criteria validation, and regression testing. No technical setup required.

## Flujo de Acción

### test-plan
Wizard para crear plan de test desde PBI:
1. "¿Cuál es la historia a testear?" → Seleccionar PBI
2. "¿Qué casos principales?" → Guiar: Happy path, error paths
3. "¿Condiciones especiales?" → Performance | Seguridad | Data
4. Generar plan con escenarios estructurados
5. ¿Apruebas el plan?

### bug-report
Wizard estructurado para reportar bugs:
1. "¿Qué no funciona?" → Descripción clara
2. "¿En qué ambiente?" → Dev | Pre | Prod
3. "¿Cómo reproducir?" → Pasos numerados
4. "¿Qué esperabas?" vs. "¿Qué viste?" → Diferencia
5. "¿Impacto?" → Crítico | Alto | Moderado | Bajo
6. Generar reporte con formato estándar

### validate
Validar aceptación de criterios (QA sign-off):
1. "¿Qué historia valido?" → Seleccionar
2. "¿Se cumple cada criterio?" → Verificar uno a uno
3. "¿Hay aristas no cubiertas?" → Documentar
4. Veredicto: Aprobada | Requiere ajuste

### regression
Plan de regresión para cambio/fix:
1. "¿Qué cambió?" → Describir
2. "¿Qué áreas afecta?" → Detectar scope
3. "¿Test suite ya existen?" → Identificar
4. Generar lista de tests a re-ejecutar
5. Dar veredicto: Verde para deploy | Riesgos detectados

## Output

Todos los wizards generan fichero en `output/qa-reports/`.
Formato: Plain text estructurado, checklist, reproducible por cualquier QA.
Incluye: pasos paso a paso, datos de test, criterios de pase/fallo.
