# Data Governance for Banking — Reference

> Gobierno de datos, lineage, clasificación y feature stores en entornos bancarios.

---

## Data Classification (obligatoria en banca)

### Niveles de clasificación
| Nivel | Ejemplos | Tratamiento |
|-------|----------|-------------|
| **PII** | Nombre, DNI, dirección, email, teléfono | GDPR/LOPD, cifrado at-rest y in-transit |
| **PCI** | PAN, CVV, PIN, fecha expiración tarjeta | PCI DSS v4.0, tokenización, no log |
| **Confidential** | Saldo, scoring, ingresos, deuda | Acceso restringido, audit trail |
| **Internal** | Códigos de producto, IDs internos | Acceso por rol |
| **Public** | IBAN (parcial), tipo de producto | Sin restricción |

### Reglas de masking
- **PAN:** `**** **** **** 1234` (últimos 4 dígitos)
- **DNI:** `****1234X` (últimos 4 + letra)
- **Email:** `m***@domain.com`
- **Saldo:** Nunca en logs ni trazas distribuidas
- **IBAN:** `ES** **** **** ** ********1234`

## Data Lineage

### Qué es
Trazabilidad completa de cada dato: de dónde viene, por dónde pasa, dónde se almacena, quién lo transforma. Obligatorio para reguladores (BCBS 239, GDPR Art. 30).

### Ejemplo de lineage en banca
```
Fuente: Core Banking (mainframe COBOL)
  → ETL (Informatica/Airflow)
    → Data Lake raw (S3/ADLS)
      → Transformación (Spark/dbt)
        → Data Warehouse (Snowflake)
          → Feature Store (Feast/Tecton)
            → Modelo ML (scoring crediticio)
              → API scoring (real-time)
```

### Herramientas de lineage
- **Apache Atlas** — Open source, integra con Kafka, Hive, Spark
- **Collibra** — Enterprise data governance (catálogo + lineage + quality)
- **Alation** — Data catalog con lineage automático
- **DataHub** (LinkedIn) — Open source, metadata graph
- **Snowflake ACCESS_HISTORY** — Lineage nativo en Snowflake

## Data Mesh en banca

### Dominios típicos
```
Domain: Accounts     → Owner: Account Team → Products: current, savings, loans
Domain: Payments     → Owner: Payment Team → Products: SEPA, SWIFT, instant
Domain: Risk         → Owner: Risk Team    → Products: credit scoring, VaR
Domain: Customer     → Owner: CRM Team     → Products: profiles, segments
Domain: Regulatory   → Owner: Compliance   → Products: FINREP, COREP, AML
```

### Data Products
Cada dominio publica "data products" con SLA, schema, lineage, owner, classification. Consumers se suscriben sin acceso directo a la fuente.

## Feature Store para ML en banca

### Arquitectura dual (batch + real-time)
```
Batch features (Airflow → Spark → Snowflake → Feature Store):
  - avg_monthly_balance_3m
  - total_transactions_30d
  - income_category
  - credit_utilization_ratio

Real-time features (Kafka Streams → Feature Store → API):
  - current_balance
  - last_transaction_amount
  - transactions_last_hour
  - device_fingerprint_match
```

### Herramientas
- **Feast** — Open source, integra con Snowflake, Redis, BigQuery
- **Tecton** — Enterprise, real-time + batch, drift detection
- **SageMaker Feature Store** — AWS nativo
- **Databricks Feature Store** — Integrado con MLflow

## Snowflake/Iceberg en banca

### Snowflake best practices
- **Time Travel** — Auditoría de cambios (hasta 90 días)
- **Dynamic Data Masking** — PII automáticamente maskeada por rol
- **Row Access Policies** — Datos por región/jurisdicción
- **External Tables** — Sobre Iceberg para data lake abierto
- **Snowpark** — ML in-database para features batch

### Apache Iceberg
- Formato transaccional para data lake (ACID sobre S3/ADLS)
- Schema evolution sin reescritura
- Time travel para auditoría
- Partition evolution sin romper queries
- Compatible: Snowflake, Spark, Trino, Flink

## GDPR/LOPD en banca

### Derechos del titular
1. **Acceso** — Exportar todos los datos del cliente en 30 días
2. **Rectificación** — Corregir datos erróneos
3. **Supresión** — Derecho al olvido (excepto obligaciones legales: 10 años para transacciones)
4. **Portabilidad** — Exportar en formato estándar (JSON/CSV)
5. **Limitación** — Restringir procesamiento manteniendo almacenamiento

### Retención obligatoria
- Transacciones bancarias: **10 años** (Ley de Prevención de Blanqueo)
- KYC/AML: **10 años** desde fin de relación
- Contratos: **6 años** (Código de Comercio)
- Logs de acceso: **2 años** (LOPD)

## Checklist de auditoría

- [ ] Catálogo de datos actualizado con clasificación
- [ ] Lineage documentado para datos regulatorios
- [ ] Masking aplicado en entornos no-productivos
- [ ] Data retention policies implementadas
- [ ] DPIA (Data Protection Impact Assessment) completado
- [ ] Consentimientos gestionados y trazables
- [ ] Feature store con versionado y lineage
- [ ] Snowflake roles y row policies configurados
