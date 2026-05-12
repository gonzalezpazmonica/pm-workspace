---
name: eval-report
description: Generate evaluation report with scoring and analysis
---

---

# /eval-report — Mostrar resultados de evaluación

Visualiza resultados históricos y tendencias de una evaluación específica.

## Argumentos

`$ARGUMENTS` — Nombre de evaluación + opciones:
- `{eval-name}` (requerido) — pbi-quality, spec-quality, estimation-accuracy, review-quality, assignment-quality
- `--sprint {sprint-id}` (opcional) — Filtrar por sprint específico
- `--trend` (opcional) — Mostrar análisis de tendencias últimas 3 evaluaciones
- `--format csv|json` (opcional) — Formato de salida

## Comportamiento

1. Lee histórico de `data/evals/{eval-name}/results/`
2. Calcula métricas: scores por evaluación, trend, desviación estándar
3. Si `--sprint` → filtra resultados del sprint indicado
4. Si `--trend` → análisis de patrones y cambios significativos
5. Genera reporte con visualizaciones

## Output

- Tabla de resultados por evaluación
- Gráfico de tendencia (ASCII)
- Comparativas si hay filtro activo
- Análisis de brechas y mejoras

## Ejemplo

```
/eval-report pbi-quality --sprint Sprint-2026-05 --trend
→ Resultados PBI Quality para Sprint 2026-05
  Last 3 evaluations: 81 → 76 → 76 (↓5% trend)
  Breakdown: Estimation precision ↓, task sizing ↑
```
