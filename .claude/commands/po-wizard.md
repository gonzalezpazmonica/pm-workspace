# PO Wizard

**Aliases:** po, po-actions

**Arguments:** `$ARGUMENTS` = action (plan-sprint | prioritize | acceptance-criteria | review)

**Description:** Guided interface for Product Owners. Step-by-step wizards using plain language, no technical jargon. Simplifies sprint planning, backlog prioritization, acceptance criteria definition, and work review.

## Flujo de Acción

### plan-sprint
Wizard paso a paso para planificar un sprint:
1. "¿Cuántos días tiene este sprint?" → Calcular puntos de equipo disponibles
2. "¿Quién participará?" → Confirmar equipo
3. "¿Cuál es el objetivo del sprint?" → Guardar meta
4. "¿Qué historias priorizas?" → Seleccionar del backlog
5. Resumen final con fecha inicio/fin

### prioritize
Asistente para reordenar backlog:
1. "¿Qué criterios usamos?" → Valor | Urgencia | Riesgo | Complejidad
2. "¿Cuál es la mejor estrategia?" → Sugerir orden
3. Mostrar top 10 historias ordenadas
4. ¿Apruebas este orden?

### acceptance-criteria
Ayuda a definir criterios de aceptación:
1. "¿Qué necesita el usuario?" → Capturar necesidad
2. "¿Cuándo sabemos que está listo?" → Criterios
3. Generar formato Given/When/Then
4. ¿Apruebas estos criterios?

### review
Revisión de trabajo completado:
1. "¿Qué historias reviso?" → Seleccionar
2. "¿Se cumplió el objetivo?" → Sí/No/Parcial
3. "¿Hay bloqueantes?" → Documentar
4. Generar resumen de sprint

## Output

Todos los wizards generan un fichero estructurado en `output/po-actions/`.
Formato: plain text, lista clara, sin tablas complejas, 100% en español natural.
