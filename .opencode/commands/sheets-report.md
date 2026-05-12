---
name: sheets-report
description: Generate report and sync to Google Sheets
---

---

# /sheets-report — Generar métricas en la hoja Metrics

**Descripción:** Genera automáticamente métricas de sprint en la hoja "Metrics" a partir de los datos en la hoja "Tasks".

**Uso:**
```
/sheets-report {proyecto}
```

**Parámetros:**
- `{proyecto}` (obligatorio) — Nombre del proyecto

## Razonamiento

1. Leer todas las tareas de la hoja Tasks
2. Calcular métricas por sprint
3. Actualizar hoja Metrics con:
   - Velocity (sum of estimates completados)
   - Burndown (% progreso)
   - Blockers (count de items con status Blocked)
   - Completion% (items Done / total)
4. Formatear con colores y gráficos

## Ejecución

Buscar todos los items con `Status = Done` y `Sprint = {actual}`
Calcular automáticamente — sin parámetros adicionales

## Template de Output

```
📊 Métricas actualizadas: {proyecto} — Sprint {actual}

Sprint Metrics:
  • Velocity: 42 SP
  • Burndown: 85%
  • Blockers: 1
  • Completion%: 85%

✅ Guardado en la hoja Metrics
   Gráfico burndown actualizado
```
