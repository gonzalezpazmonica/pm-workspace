# Revisar Postmortems Pasados

**alias:** `/postmortem-review`, `/postmortem-analysis`

**propósito:** Analizar postmortems históricos para extraer patrones y brechas recurrentes.

**parámetros:** 
- `--recent` (últimos 5 postmortems)
- `{incident-id}` (postmortem específico)
- Sin parámetros: listado interactivo

## Flujo

1. **Localizar postmortems** en `output/postmortems/`
2. **Cargar ficheros solicitados**
3. **Extraer patrones por Diagnosis Journey:**
   - Qué checks se hicieron primero (frecuencia)
   - Qué hipótesis fueron correctas/falsas
   - Dónde se atascó el equipo (puntos ciegos comunes)
4. **Compilar:**
   - Heurísticas recurrentes
   - Brechas de comprensión comunes
   - Causas raíces por tipo
5. **Guardar resumen** en `output/postmortem-trends.md`

## Output

- Tabla de incidentes analizados
- Top 5 gaps de diagnóstico
- Patrones por módulo/área
- Recomendación: qué heurísticas documentar

Sugerir: `/postmortem-heuristics` para compilar debugging playbook
