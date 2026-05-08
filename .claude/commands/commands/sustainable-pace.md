---
name: sustainable-pace
description: Cálculo de ritmo sostenible basado en histórico y capacidad real
developer_type: all
agent: task
context_cost: medium
---

# /sustainable-pace — Ritmo Sostenible

Calcula la velocidad máxima del equipo que puede mantenerse sin degradación de calidad ni riesgo de burnout.

## Sintaxis

```bash
/sustainable-pace [--calculate] [--forecast] [--alerts on|off] [--lang es|en]
```

## Opciones

- **--calculate**: Analizar ritmo histórico (defecto)
- **--forecast**: Proyectar sostenibilidad para próximos sprints
- **--alerts on|off**: Activar/desactivar alertas automáticas
- **--lang**: Idioma

## Cálculo

Fórmula:
```
Sustainable Pace = (Average Velocity - Trend) × Quality Factor × Wellbeing Factor
```

Donde:
- **Average Velocity**: Media últimos 5 sprints
- **Trend**: Tendencia (ascendente = reducir)
- **Quality Factor**: % defects/regresiones (baja calidad = reducir)
- **Wellbeing Factor**: Índice de burnout (alto = reducir mucho)

## Análisis Incluido

- Velocity trends
- Overtime patterns
- Quality degradation signals
- Deployment frequency
- Lead time trends

## Alertas

Se generan automáticamente cuando:
- Velocity actual > Sustainable Pace (riesgo sprint siguiente)
- Trend indicador de insostenibilidad
- Defect rate creciente

## Ejemplo

```bash
/sustainable-pace --calculate --forecast --alerts on
```

Muestra ritmo sostenible, proyección 3 sprints, y activa alertas en dashboard.

🦉 **La velocidad no es ambición; la sostenibilidad es estrategia.**
