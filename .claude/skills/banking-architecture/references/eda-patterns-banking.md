# EDA Patterns for Banking — Reference

> Event-Driven Architecture patterns específicos del sector bancario.

---

## Patrones fundamentales

### Event Sourcing en banca
Cada transacción es un evento inmutable. El estado de la cuenta se reconstruye reproduciendo eventos. Crítico para: auditoría, reconciliación, settlement, regulación.

**Eventos típicos:** AccountOpened, DepositMade, WithdrawalProcessed, TransferInitiated, TransferCompleted, PaymentFailed, FraudDetected, KYCVerified.

### CQRS (Command Query Responsibility Segregation)
Separar escrituras (comandos) de lecturas (queries). En banca: las escrituras van al ledger (event store), las lecturas van a proyecciones optimizadas (balance, extracto, reporting).

**Write side:** Kafka → Event Store → Ledger
**Read side:** Projections → Snowflake / ElasticSearch / Redis

### Saga Pattern (Orquestación vs Coreografía)
Transacciones distribuidas sin 2PC. En banca: transferencias entre cuentas, settlement, pagos internacionales.

**Orquestación (recomendada para settlement):**
```
Saga Orchestrator → Debit Source Account
                  → Credit Destination Account
                  → Notify SWIFT Gateway
                  → Update Regulatory Report
                  → Compensate on failure
```

**Coreografía (adecuada para notificaciones):**
Cada servicio emite eventos que otros consumen sin coordinador central.

## Kafka en banca — Topologías

### Topic design
```
payments.initiated     → Payment Service publica
payments.validated     → Fraud Service publica tras verificación
payments.executed      → Settlement Service publica tras liquidación
payments.failed        → Cualquier servicio publica en caso de fallo
payments.dlq           → Dead Letter Queue para eventos no procesables
```

### Partitioning strategy
- **Por account_id:** Garantiza orden de eventos por cuenta
- **Por currency:** Separa flujos EUR, USD, GBP
- **Por region:** Cumplimiento GDPR por jurisdicción

### Reliability patterns
1. **Idempotencia:** Cada consumer debe ser idempotente (usar event_id como dedup key)
2. **Exactly-once semantics:** Kafka Transactions + idempotent producer
3. **DLQ (Dead Letter Queue):** Eventos que fallan N veces → DLQ para análisis manual
4. **Circuit Breaker:** Si settlement-service no responde → circuit open → retry con backoff
5. **Outbox Pattern:** Escribir evento en tabla outbox + publicar a Kafka en misma transacción DB

## Schemas y contratos

### Avro/Protobuf obligatorio
En banca NO se usa JSON sin schema. Avro o Protobuf con Schema Registry garantizan:
- Compatibilidad forward/backward entre versiones
- Validación de tipos en tiempo de compilación
- Evolución de schema sin romper consumers

### Convenciones de naming
```
com.bank.payments.v1.PaymentInitiated
com.bank.accounts.v1.AccountDebited
com.bank.settlement.v1.SettlementCompleted
com.bank.fraud.v1.TransactionFlagged
```

## Anti-patterns en banca

1. **Event Soup:** Demasiados tipos de eventos sin taxonomía clara
2. **Temporal Coupling:** Consumer que asume orden entre topics distintos
3. **Missing Correlation ID:** Imposible trazar una transacción end-to-end
4. **Unbounded Retry:** Retry infinito bloquea el consumer group
5. **Schema-less Events:** JSON sin schema → incompatibilidades silenciosas
6. **Direct DB Access:** Servicio A lee BD de servicio B sin API
7. **Missing Dead Letter Queue:** Eventos fallidos se pierden

## Métricas clave para Kafka en banca

| Métrica | Umbral alerta | Crítico |
|---------|---------------|---------|
| Consumer lag | >1000 eventos | >10000 |
| End-to-end latency | >500ms | >2s |
| DLQ rate | >0.1% | >1% |
| Replication ISR | <3 | <2 |
| Producer error rate | >0.01% | >0.1% |
| Schema compatibility | BACKWARD | — |

## Integración con observabilidad

- Cada evento debe incluir: `trace_id`, `span_id`, `correlation_id`
- OpenTelemetry Kafka instrumentation para trazas distribuidas
- Grafana dashboard: consumer lag, throughput por topic, latencia p99
- Alertas: lag creciente, DLQ creciente, errores de serialización
