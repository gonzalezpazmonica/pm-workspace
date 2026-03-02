---
name: Error Investigate
description: Investigación asistida de errores en producción con root cause analysis y correlación de datos
developer_type: all
agent: task
context_cost: high
---

# /error-investigate

Investigación profunda de errores en tiempo real.

## Uso

```
/error-investigate {descripción del error} [--source all] [--period 24h] [--correlate] [--lang es|en]
```

## Descripción

Describe el error en lenguaje natural. Savia ejecuta investigación asistida:

### Paso 1 — Búsqueda de logs
Busca en Loki, Datadog Logs, App Insights patrones coincidentes
en el período especificado.

### Paso 2 — Correlación de trazas
Encuentra trazas distribuidas con errores en el período indicado.
Analiza correlación temporal entre logs y trazas.

### Paso 3 — Análisis de despliegues
¿Se deployó algo justo antes del error?
- Revisa pipeline CI/CD de los últimos X minutos
- Correlaciona timestamp error vs. timestamp deploy

### Paso 4 — Métricas de infraestructura
¿Hay saturación? Analiza:
- CPU, memoria, disco (Grafana, Datadog, App Insights)
- Latencias de red
- Errores de DNS

### Paso 5 — Identificación del servicio origen
¿Dónde se originó el error?
- Análisis de stack traces y logs
- Propagación a servicios dependientes

### Paso 6 — Hipótesis de root cause
Savia construye una hipótesis basada en:
- Patrón de errores encontrados
- Timeline del incidente
- Cambios recientes (código, config, infraestructura)

### Paso 7 — Recomendaciones de mitigación
- Acciones inmediatas (rollback, escalado, reinicio)
- Investigación adicional requerida
- Cambios preventivos para futuro

## Opciones

- `--source`: all (default) | grafana | datadog | appinsights
- `--period`: 1h | 24h (default) | 7d
- `--correlate`: incluir análisis de despliegues y cambios recientes
- `--lang`: es (default) | en

## Ejemplo de entrada natural

"Los usuarios reportan que el checkout está fallando desde las 3 PM"

Savia entiende:
- Servicio: checkout
- Problema: failings
- Tiempo: desde las 3 PM (últimas N horas)

Y busca automáticamente.

## Output

Informe estructurado con:
- **Timeline del incidente**: qué pasó cuándo
- **Servicios afectados**: lista con % de errores
- **Causa probable**: hipótesis basada en datos
- **Impacto estimado**: cuántos usuarios, cuántas transacciones
- **Pasos de mitigación**: qué hacer ahora
- **Acciones preventivas**: para futuro

## Soportes

- Grafana Loki + Prometheus
- Datadog Logs + APM
- Azure App Insights
- Elasticsearch
- OpenTelemetry
