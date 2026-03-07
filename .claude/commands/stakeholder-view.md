# Stakeholder View

**Aliases:** stakeholder, executive-view

**Arguments:** `$ARGUMENTS` = view (summary | milestones | risks | budget)

**Description:** Executive-level dashboard for stakeholders. Shows high-level project status, milestones, risks, and budget impact using business language (no technical jargon, no code references).

## Vistas Disponibles

### summary
Resumen ejecutivo de proyecto:
- Status general (en marcha | retrasado | completado)
- Porcentaje completado
- Fecha finalización estimada vs. real
- Hitos alcanzados esta semana
- Top 3 riesgos

### milestones
Revisión de hitos completados y próximos:
- Hito completado: fecha, entregas, aprobación stakeholders
- Próximos hitos: fecha, scope, owner
- Indicador de riesgo por hito

### risks
Registro de riesgos y mitigación:
- Riesgo identificado | Severidad | Estado | Plan mitigación
- Riesgos cerrados esta semana
- Riesgos nuevos esta semana

### budget
Impacto económico y control de costos:
- Presupuesto inicial | Gastado | Disponible
- Trayectoria (en línea | sobre presupuesto | bajo presupuesto)
- Estimación final vs. aprobado

## Output

Todos los views generan un fichero en `output/stakeholder-reports/`.
Formato: PDF o DOCX listo para presentación, 100% business-friendly.
Incluye: tablas simples, números clave destacados, recomendaciones de acción.
