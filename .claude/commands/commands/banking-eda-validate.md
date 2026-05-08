---
name: banking-eda-validate
description: Validar pipelines Kafka/EDA — topologías, schemas, DLQ, Saga, idempotencia
developer_type: all
agent: architect
context_cost: high
---

# /banking-eda-validate [--project {nombre}] [--fix] [--focus topics|schemas|reliability]

> 🏦 Valida tu arquitectura event-driven: Kafka, schemas, Sagas, reliability patterns.

---

## Cargar perfil y skill

Grupo: **Architecture & Tech** — cargar `identity.md` + `projects.md` + `preferences.md`.
Reference: `@.opencode/skills/banking-architecture/references/eda-patterns-banking.md`

## Parámetros

- `--project {nombre}` — Proyecto (default: activo)
- `--fix` — Generar correcciones sugeridas (default: solo análisis)
- `--focus {area}` — Focalizar en: `topics` | `schemas` | `reliability` (default: all)

## Flujo

### Paso 1 — Detectar infraestructura EDA

Buscar en código, config y Docker/K8s:
- Kafka brokers, topics, consumer groups
- Schema Registry (Confluent, Apicurio, AWS Glue)
- Event stores, outbox tables
- Message brokers alternativos (AMQ, MSK, Pulsar)

### Paso 2 — Validar Topic Design

Verificar convenciones de naming, partitioning y configuración:

| Check | Esperado | Criticidad |
|-------|----------|------------|
| Naming convention | `{domain}.{entity}.{event}` | WARNING |
| Partitioning key | account_id o correlation_id | CRITICAL |
| Retention policy | ≥7 días para banca | WARNING |
| Replication factor | ≥3 en producción | CRITICAL |
| DLQ configurado | Sí para cada consumer | CRITICAL |
| Compaction | Solo para snapshots/state | INFO |

### Paso 3 — Validar Schemas

Si hay Schema Registry:
- Compatibilidad: BACKWARD o FULL recomendado
- Formato: Avro o Protobuf (JSON sin schema = ❌)
- Evolución: verificar que no hay breaking changes
- Campos obligatorios: `event_id`, `timestamp`, `correlation_id`, `source`

### Paso 4 — Validar Reliability Patterns

| Pattern | Check | Criticidad |
|---------|-------|------------|
| Idempotencia | Consumer dedup por event_id | CRITICAL |
| Outbox Pattern | Evento en tabla + Kafka en misma TX | CRITICAL |
| Circuit Breaker | Configurado para servicios downstream | WARNING |
| Retry con backoff | Exponential backoff, max retries | WARNING |
| Dead Letter Queue | DLQ con alertas | CRITICAL |
| Exactly-once | Kafka Transactions habilitadas | WARNING |

### Paso 5 — Evaluar patrones arquitectónicos

- **Event Sourcing:** ¿Se reconstruye estado desde eventos?
- **CQRS:** ¿Write side separado de read side?
- **Saga:** ¿Transacciones distribuidas con compensación?
- **Outbox:** ¿Consistencia eventual garantizada?

### Paso 6 — Generar informe

```markdown
# 🏦 EDA Validation — {proyecto}

**Broker:** {Kafka/MSK/AMQ} | **Topics:** {N} | **Consumers:** {M}
**Schema Registry:** {Sí/No} | **Format:** {Avro/Protobuf/JSON}

## Health Score
| Área | Score | Issues |
|------|-------|--------|
| Topics | {n}% | {issues} |
| Schemas | {n}% | {issues} |
| Reliability | {n}% | {issues} |
| Patterns | {n}% | {issues} |

## Issues Encontrados
1. ❌ CRITICAL: {descripción}
2. ⚠️ WARNING: {descripción}

## Recomendaciones
- {acción concreta}
```

Output: `output/banking-eda-{proyecto}-{fecha}.md`

## Restricciones

- **NUNCA** conectar a Kafka brokers de producción sin autorización
- Análisis estático de config/código, no runtime
- Sugerir `/obs-query` para métricas runtime de Kafka
