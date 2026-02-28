---
name: agent-efficiency
description: Ratio de eficiencia de agentes — specs completadas, re-work y tiempos
developer_type: agent-single
agent: azure-devops-operator
context_cost: low
---

# Comando: agent-efficiency

## Descripción

Analiza la eficiencia de los agentes midiendo tasa de éxito, tiempos por complejidad, re-trabajo y tasa de éxito en primer intento. Compara contra métricas de sprints anteriores.

## Métricas

- **Tasa de éxito:** specs completadas / total intentos
- **Tiempo promedio por spec:** agrupado por complejidad (small/medium/large)
- **Tasa de re-trabajo:** % specs que requirieron > 1 intento
- **Éxito en primer intento:** specs sin rechazo de code-reviewer
- **Utilización de agentes:** % tiempo activo vs idle en Agent Teams

## Datos

Fuentes:
- Trazas desde `projects/{proyecto}/traces/`
- Histórico de specs en `projects/{proyecto}/specs/`
- Rechazos de code-reviewer en git history / comentarios

## Output

Tabla de eficiencia por agente, por language pack:
- Agente | Tasa éxito | Tiempo promedio | Re-trabajo % | Primer intento %
- Utilización promedio

Benchmark: comparar sprint actual vs promedio últimos 3 sprints

Recomendaciones de mejora: señalar botellas (agentes/lenguajes con baja eficiencia)

## Ejemplos

```
/agent-efficiency
/agent-efficiency --language-pack typescript
```

## Requisitos

- Trazas, specs y histórico de git accesibles
- Datos de al menos 1 sprint anterior para comparación
