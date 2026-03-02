---
name: Trace Analyze
description: Análisis profundo de trazas específicas con detección de cuellos de botella y cadenas de errores
developer_type: all
agent: task
context_cost: high
---

# /trace-analyze

Analiza una traza específica en profundidad para entender su comportamiento.

## Uso

```
/trace-analyze {trace-id} [--source auto|grafana|datadog|appinsights] [--depth full|summary] [--lang es|en]
```

## Descripción

Savia recupera todos los spans, construye el árbol de llamadas y genera un análisis comprensible del flujo de ejecución.

### Análisis Incluido

**Waterfall Visualization**: Timeline ASCII art mostrando:
- Cada span y su duración
- Paralelismo entre servicios
- Secuencia temporal de eventos

**Bottleneck Detection**: Identifica:
- Span que consume más tiempo
- Servicios más lentos
- Llamadas bloqueantes innecesarias
- Timeouts en cascada

**Error Chain**: Analiza:
- Punto de origen del error
- Cómo se propagó a otros servicios
- Stack traces completos
- Status codes y mensajes de error

**Anomaly Detection**: Compara:
- Duración vs baseline histórico
- Comportamiento esperado de cada span
- Desviaciones significativas

**Service Dependency Map**: Grafo de:
- Servicios involucrados
- Direccion de llamadas
- Latencias entre servicios

**Recomendaciones**: Sugerencias contextuales:
- Qué investigar primero
- Posibles causas según el tipo de error
- Dónde optimizar

### Profundidad de Análisis

- `--depth summary`: Resumen ejecutivo (para CTO/PM)
- `--depth full`: Análisis técnico completo (para Dev/SRE)

## Ejemplos

```
/trace-analyze 7b8a9c1d2e3f4g5h
/trace-analyze abc123def456 --source datadog --depth full
/trace-analyze xyz789 --depth summary --lang en
```

## Output Adaptado

- **Dev/SRE**: Detalles técnicos, spans problemáticos, logs asociados
- **PM/CTO**: Impacto en usuario, servicios afectados, recomendaciones
- **QA**: Datos de comportamiento, variaciones, patrones

## Plataformas Soportadas

- Grafana Tempo
- Datadog APM
- Azure App Insights
- Jaeger
- OpenTelemetry
