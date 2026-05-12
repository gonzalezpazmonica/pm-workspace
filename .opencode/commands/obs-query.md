---
name: obs-query
description: Consultas en lenguaje natural a datos de observabilidad — PromQL, KQL, Datadog Query Language
developer_type: all
agent: task
context_cost: high
---

# /obs-query

> 🦉 Pregunta a Savia sobre tus datos en lenguaje natural. Ella traduce a la query nativa correcta.

---

## Sintaxis

```
/obs-query {pregunta en español} [--source grafana|datadog|appinsights|all] [--period 1h|24h|7d|30d] [--lang es|en]
```

### Ejemplos

- "¿Cuál es el tiempo de respuesta medio de la API en las últimas 24 horas?"
- "¿Ha habido picos de errores 500 esta semana?"
- "¿Cuánta memoria está consumiendo el servicio de pagos?"
- "Muéstrame el throughput del endpoint /api/users"
- "¿Qué servicios tienen latencia por encima de 200ms?"

---

## Flujo

### Paso 1 — Procesar pregunta en lenguaje natural

1. Parsear: métrica buscada, servicio/endpoint, período, filtros
2. Validar que hay fuentes conectadas en `.claude/profiles/integrations/`
3. Mapear a plataformas disponibles

### Paso 2 — Generar queries nativas

**Grafana/Prometheus** → PromQL: latency p99, error rate, throughput
**Datadog** → DDQ: latency, error rate, infrastructure metrics, APM
**App Insights** → KQL: requests, exceptions, dependencies, performance

Ejemplos:
- Error rate: `sum(rate(errors[5m])) / sum(rate(requests[5m]))`
- Latency p99: `histogram_quantile(0.99, rate(duration_bucket[5m]))`

### Paso 3 — Ejecutar queries

Ejecutar en paralelo en fuentes conectadas. Cachear resultados (TTL 5 min).
Manejar errores: query fallida → sugerir alternativa.

### Paso 4 — Analizar y explicar

1. Normalizar datos (unidades, escalas, timestamps)
2. Detectar anomalías: comparación con baseline, desviación > 2σ
3. Buscar cambios bruscos (pendiente > threshold)
4. Correlacionar con deployments y eventos

### Paso 5 — Responder adaptando al rol del usuario

**CEO**: resumen ejecutivo + recomendación
**Dev/SRE**: datos técnicos completos + posibles causas
**PM**: impacto en usuarios + acciones recomendadas

---

## Opciones avanzadas

- `--source all` → ejecutar en todas las fuentes y comparar
- `--correlate-events` → buscar correlación con deployments
- `--format chart|table|json` → formato de output

---

## Bajo el capó

- NL → Query: LLM genera queries, valida sintaxis
- Multi-source: ejecuta en paralelo, consolida resultados
- Smart caching: reutiliza queries similares (similarity > 0.8)
- Audit logging: cada query en `ai-audit-log`
- Seguridad: queries no guardan PII, RBAC por usuario

