# SPEC-SE-009 — Observability Stack (Agnóstico)

> **Prioridad:** P1 · **Estima:** 5 días · **Tipo:** observabilidad federada

## Objetivo

Dotar a Savia Enterprise de un stack de observabilidad **100% basado en
estándares abiertos** (OpenTelemetry, Prometheus, Loki, Tempo, Grafana)
que funcione on-premise y que pueda exportar a cualquier backend comercial
sin acoplamiento: Datadog, New Relic, Dynatrace, Elastic, Sentry. El
cliente elige backend; Savia nunca obliga.

## Principios afectados

- #2 Independencia del proveedor (sin lock con observability SaaS)
- #3 Honestidad radical (métricas medibles y exportables)

## Diseño

### Stack base (sovereign-ready)

```
┌──────────┐   ┌──────────────┐   ┌───────────┐
│  Savia   │──▶│ OTel Collector│──▶│ Backends  │
│ Agents   │   │  (local)      │   │ (agnóstico)│
└──────────┘   └──────────────┘   └───────────┘
                       │
                       ▼
              ┌────────────────┐
              │ Prometheus     │ metrics
              │ Loki           │ logs
              │ Tempo          │ traces
              │ Grafana        │ UI
              └────────────────┘
```

Todo el stack corre local en modo `sovereign` (SE-005). Sin dependencias
externas.

### Exporters opt-in (nunca default)

Configurables por tenant en `observability.yaml`:

```yaml
exporters:
  prometheus_remote_write: http://local:9090/api/v1/write
  # opcional, opt-in explícito:
  datadog:
    enabled: false
    api_key_ref: secret:datadog_key
  newrelic:
    enabled: false
  sentry:
    enabled: false
```

### Métricas Savia estándar

Extender OTel con métricas específicas del dominio agentic:

- `savia_agent_invocations_total{agent,tenant,model}`
- `savia_agent_token_budget_used{agent,model}`
- `savia_agent_duration_seconds{agent,result}`
- `savia_spec_verification_score{spec,layer}`
- `savia_context_usage_ratio{session}`
- `savia_compliance_gate_blocks{gate,reason}`
- `savia_sovereignty_blocks{layer,pattern}`

### Traces de agent runs

Cada invocación de agente emite un span con:
- Inputs (hash, nunca contenido si es N4)
- Tools invocadas (con latencia)
- Outputs (hash + tamaño)
- Token usage (input, output, cache)
- Model tier usado
- Coste estimado

### Dashboards preconstruidos

Grafana JSONs versionados en repo:
- `dashboards/savia-agents-overview.json`
- `dashboards/savia-sprint-health.json`
- `dashboards/savia-compliance.json`
- `dashboards/savia-sovereignty.json`

### Privacy by design

- Contenido de prompts/respuestas NUNCA en traces (solo hashes)
- N4 filtrado antes de exportar
- Logs PII-scrubbed (regla existente `pii-sanitization.md`)

## Criterios de aceptación

1. OTel Collector configurado y funcional con Savia Core
2. Los 7 namespaces de métricas definidos e instrumentados
3. 4 dashboards Grafana funcionales
4. Test: desactivar todos los exporters → Savia sigue operando, métricas locales
5. Documentado cómo exportar a Datadog, NewRelic, Sentry (opt-in)
6. Hook `otel-pii-scrubber.sh` que filtra N4 antes de emit

## Out of scope

- Backends comerciales concretos (el cliente elige)
- APM de aplicaciones de cliente (fuera del scope de Savia)

## Dependencias

- SE-001, SE-005
