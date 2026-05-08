---
name: Incident Correlate
description: Correlación cruzada de datos de múltiples fuentes para análisis integral de incidentes
developer_type: all
agent: task
context_cost: high
---

# /incident-correlate

Análisis multi-fuente de incidentes con post-mortem draft.

## Uso

```
/incident-correlate [--incident-id ID] [--period auto|1h|24h] [--sources all] [--lang es|en]
```

## Descripción

Combina datos de múltiples plataformas en una vista única del incidente.

### Fuentes correlacionadas

**Métricas:**
- Grafana / Prometheus
- Datadog
- Azure App Insights

**Logs:**
- Loki
- Datadog Logs
- App Insights Traces

**Trazas distribuidas:**
- Grafana Tempo
- Datadog APM
- Azure App Insights Dependencies

**Despliegues:**
- CI/CD pipeline data
- Git commits y timestamps

**Alertas:**
- Alertas que precedieron al incidente
- Correlación temporal con el evento

**Cambios:**
- Cambios de configuración
- Secrets rotados
- Actualizaciones de dependencias

### Análisis realizado

**Timeline unificado**: Todos los eventos en orden cronológico:
- Alerta T-5min
- Deploy T-2min
- Error T0
- Escalada T+10min
- Rollback T+20min

**Cascading failures**: Detectar:
- Fallo inicial → qué servicio falla a continuación
- Propagación en V (amplificación)
- Recuperación en cascada (¿quién se recupera primero?)

**Blast radius**: Cuantificar:
- Usuarios afectados (% del total)
- Transacciones fallidas (volumen)
- Servicios impactados (directa e indirectamente)
- Duración del incidente

**Post-mortem draft automático**:
1. **What happened** — descripción narrativa del timeline
2. **Why** — análisis de causas raíz (primary + contributing factors)
3. **Impact** — resumen de usuarios, transacciones, duración
4. **Timeline detallado** — todos los eventos con fuentes
5. **Root cause** — hipótesis principal con evidencia
6. **Action items** — qué prevenir / cómo mejorar
   - Inmediatos (guardrails, monitoreo)
   - Corto plazo (mejoras de arquitectura)
   - Largo plazo (reingeniería si aplica)

## Opciones

- `--incident-id`: ID de incidente en Datadog/PagerDuty/etc. (opcional)
- `--period`: auto (detecta desde alertas) | 1h | 24h
- `--sources`: all (default) | grafana | datadog | appinsights
- `--lang`: es (default) | en

## Output

📄 Informe multi-fuente con:
- Gráfico temporal de eventos correlacionados
- Timeline tabular (evento, fuente, timestamp, contexto)
- Blast radius (usuarios, transacciones, servicios)
- Post-mortem draft (what/why/impact/timeline/root cause/actions)

El PM puede usar el draft directamente o editarlo manualmente.

## Ejemplo

```
/incident-correlate --incident-id datadog-inc-12345 --period auto
→ Savia encuentra alerta en Datadog con timestamp T
→ Busca logs en Loki/Datadog del período [T-30min, T+30min]
→ Busca trazas en Tempo/APM del mismo período
→ Busca despliegues en Azure Pipelines/CI
→ Busca cambios de config en últimas 24h
→ Construye timeline unificado
→ Detecta que CPU > 95% a T-5min, deploy a T-2min, error a T0
→ Hipótesis: deploy disparó aumento de CPU que causó timeout
→ Genera post-mortem draft
```

## Soportes

- Grafana + Prometheus
- Datadog (Logs, APM, Monitors)
- Azure App Insights (Traces, Metrics, Performance)
- Loki
- Elasticsearch
- OpenTelemetry Tempo
- Jaeger
