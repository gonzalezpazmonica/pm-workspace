---
name: burnout-radar
description: Detección temprana de señales de burnout con análisis de riesgo por miembro del equipo
developer_type: all
agent: task
context_cost: medium
---

# /burnout-radar — Detección Temprana de Burnout

Analiza patrones de sobrecarga laboral y riesgo de burnout basándose en métricas objetivas del SPACE framework (dimensión Satisfaction & Wellbeing).

## Sintaxis

```bash
/burnout-radar [--team] [--individual nombre] [--period sprint|month|quarter] [--lang es|en]
```

## Opciones

- **--team**: Análisis de todo el equipo (por defecto)
- **--individual nombre**: Enfoque en miembro específico
- **--period**: sprint (últimas 2 semanas), month (últimos 30 días), quarter (últimos 90 días)
- **--lang**: Idioma del informe (español por defecto)

## Señales de Riesgo Analizadas

1. **Horas extra sostenidas** — Media semanal > 40h en últimos N sprints
2. **Sprints fallidos consecutivos** — >30% items no completados en 2+ sprints
3. **WIP alto** — Promedio WIP/persona > 2.5 (paralelización excesiva)
4. **Cambios frecuentes de prioridad** — >3 repriorizaciones/sprint
5. **Reducción de throughput personal** — Trend descendente de velocity individual >15% sprint-a-sprint
6. **Baja participación en retros** — <50% asistencia o sin contribuciones

## Output

Mapa de calor con scores por miembro (0-100):
- **🟢 0-30**: Bajo riesgo — ritmo sostenible
- **🟡 31-60**: Riesgo moderado — vigilar
- **🔴 61-100**: Riesgo alto — acción recomendada

Recomendaciones personalizadas:
- Redistribución de carga
- Pausas estratégicas
- Ajuste de sprints o scope

## Ejemplo

```bash
/burnout-radar --team --period sprint --lang es
```

Genera informe con score de burnout de cada miembro del sprint actual.

🦉 **Nota de Savia**: El bienestar del equipo es el cimiento de la excelencia. 
Este comando es un acto de cuidado, no de vigilancia.
