---
name: agent-cost
description: Coste estimado de uso de agentes por sprint/proyecto
developer_type: agent-single
agent: azure-devops-operator
context_cost: low
---

# Comando: agent-cost

## Descripción

Estima el coste de uso de agentes basándose en tokens consumidos. Agrupa por agente, comando y opcionalmente por sprint. Incluye recomendaciones de optimización.

## Datos

Lectura desde `projects/{proyecto}/traces/agent-traces.jsonl` (mismo formato que `/agent-trace`)

## Modelo de costes

Configurable en `CLAUDE.local.md`:
- **Opus 4.6**: $15/M tokens entrada, $75/M tokens salida
- **Sonnet 4.6**: $3/M entrada, $15/M salida
- **Haiku 4.5**: $0.80/M entrada, $4/M salida

## Comportamiento

**Agrupación:** por agente, por comando
**Opcional `--sprint`:** grupos por sprint si se especifica

**Cálculo:** coste_total = (tokens_in * precio_entrada + tokens_out * precio_salida) / 1_000_000

## Output

Tabla de costes con:
- Agente | Comando | Tokens entrada | Tokens salida | Coste estimado
- Subtotal por agente
- Coste total del período

Tendencia: costes de los últimos 3 sprints (si existe histórico)

Recomendaciones:
- Identificar operaciones más costosas
- Sugerir optimizaciones (ej: usar Haiku para tareas simples)

Si no hay trazas: mostrar costes estimados basados en patrones típicos

## Ejemplos

```
/agent-cost
/agent-cost --sprint "Sprint 2026-05"
```

## Requisitos

- Trazas disponibles en `projects/{proyecto}/traces/`
- Configuración de costes actualizada
