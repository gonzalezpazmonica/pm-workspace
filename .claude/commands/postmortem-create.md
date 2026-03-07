# Crear Postmortem Guiado

**alias:** `/postmortem-create`, `/postmortem-new`

**propósito:** Crear postmortem estructurado enfocado en documentar el viaje de diagnóstico.

**parámetros:** `$ARGUMENTS` = `{incident-id}` o descripción breve

## Flujo

1. Obtener ID del incidente
2. Crear timestamp ISO 8601 (YYYYMMDD-incident-id)
3. Guiar a través de cada sección:
   - Timeline (¿cuándo se notó?)
   - Diagnosis Journey (paso a paso)
   - Resolution (acciones que lo corrigieron)
   - Mental Model Update (qué saber)
   - Heuristic Extraction (si X, chequea Y)
   - Comprehension Gap (¿código AI? ¿modelos?)
   - Prevention (qué lo hubiera atrapado)
4. Guardar a: `output/postmortems/YYYYMMDD-{incident-id}.md`
5. Enlazar a comprehension report si aplica

## Énfasis

Plantilla obligatoria. No permitir guardar incompleto.
