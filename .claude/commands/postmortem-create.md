# Crear Postmortem Guiado

**alias:** `/postmortem-create`, `/postmortem-new`

**propósito:** Crear un postmortem estructurado enfocado en documentar el viaje de diagnóstico, no solo la raíz.

**parámetros:** `$ARGUMENTS` = `{incident-id}` o descripción breve del incidente

## Flujo

1. **Obtener ID del incidente** — pedir si no está en `$ARGUMENTS`
2. **Crear timestamp ISO 8601** — ej: `YYYYMMDD-incident-id`
3. **Guiar a través de cada sección:**
   - Timeline (¿cuándo se notó primero?)
   - Diagnosis Journey (paso a paso del razonamiento)
   - Resolution (acciones que lo corrigieron)
   - Mental Model Update (qué debe saber el on-call)
   - Heuristic Extraction (si X, chequea Y primero)
   - Comprehension Gap (¿código AI-generado? ¿modelos mentales?)
   - Prevention (qué lo hubiera atrapado antes)
4. **Guardar a:** `output/postmortems/YYYYMMDD-{incident-id}.md`
5. **Enlazar a comprehension report** si aplica

## Énfasis

Hacer preguntas específicas para surfear el VIAJE diagnóstico, no dejar que sea freeform. Cada sección debe ser concreta, no filosófica.

Plantilla obligatoria: no permitir guardar sin llenar todas las 7 secciones.
