---
name: Trace Search
description: Buscar y filtrar trazas across multiple observability platforms with natural language support
developer_type: all
agent: task
context_cost: high
---

# /trace-search

Busca y filtra trazas distribuidas en plataformas de observabilidad.

## Uso

```
/trace-search {criterio} [--source grafana|datadog|appinsights|all] [--period 1h|24h|7d] [--status error|slow|all] [--service nombre] [--lang es|en]
```

## Descripción

Savia busca trazas usando lenguaje natural y filtros específicos. Soporta OpenTelemetry, Datadog APM, Azure App Insights y Grafana Tempo.

### Búsqueda Natural

Describe el problema de forma natural:
- "trazas con errores en el servicio de pagos en las últimas 2 horas"
- "llamadas lentas al API de usuarios hace 24 horas"
- "fallos en checkout con código 502"

Savia interpreta el contexto y busca las trazas correspondientes.

### Filtros Disponibles

- `--source`: Plataforma (grafana, datadog, appinsights, all)
- `--period`: Rango temporal (1h, 24h, 7d)
- `--status`: error (errores), slow (duracion > percentil 95), all
- `--service`: Filtrar por nombre de servicio
- `--lang`: es o en

### Resultados

Para cada traza encontrada:
- Trace ID
- Servicios involucrados
- Duración total
- Estado (error/success/slow)
- Resumen de error (si aplica)
- Timestamp

Pagination automática para resultados grandes.

## Ejemplos

```
/trace-search trazas con errores en pagos últimas 2h
/trace-search llamadas lentas a usuarios --source datadog --period 24h
/trace-search checkout fallando --service payment-api --status error
/trace-search database timeouts --source all --period 7d --lang en
```

## Soportes

- OpenTelemetry (Jaeger, Tempo)
- Datadog APM
- Azure App Insights
- Grafana Tempo
- Elasticsearch

## Rol Adaptado

Savia presenta resultados de forma contextual según el rol del usuario.
