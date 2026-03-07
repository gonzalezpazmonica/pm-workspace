# Revisar Postmortems Pasados

**alias:** `/postmortem-review`, `/postmortem-analysis`

**propósito:** Analizar postmortems históricos para extraer patrones y brechas.

**parámetros:** 
- `--recent` (últimos 5 postmortems)
- `{incident-id}` (postmortem específico)
- Sin parámetros: listado interactivo

## Flujo

1. Localizar postmortems en `output/postmortems/`
2. Cargar ficheros solicitados
3. Extraer patrones:
   - Qué checks primero
   - Qué hipótesis correctas/falsas
   - Dónde se atascó el equipo
4. Compilar:
   - Heurísticas recurrentes
   - Brechas comunes
   - Causas raíces por tipo
5. Guardar resumen en `output/postmortem-trends.md`

## Output

- Tabla de incidentes
- Top 5 gaps
- Patrones por módulo
- Recomendaciones

Sugerir: `/postmortem-heuristics`
