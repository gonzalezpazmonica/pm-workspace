# Banking Detection — Algoritmo de detección de proyecto bancario

> Extiende `vertical-detection.md` con entidades, deps y patterns específicos de banca.

---

## Fase 1 — Domain Entities (35%)

Buscar en: models, schemas, migrations, DTOs, domain/, entities/

### Core Banking
Account, Transaction, Ledger, Settlement, Transfer, Payment, Instruction, Balance, Statement, Currency, ExchangeRate

### Advanced
Position, Exposure, Liquidity, Counterparty, NostroAccount, VostroAccount, Mandate, Authorization, Clearing, Reconciliation

### Regulatory
KYC, AML, Sanction, ComplianceCheck, RegulatoryReport, AuditTrail, RiskAssessment, CreditScore, Provision

### BIAN-specific
ServiceDomain, BusinessArea, ControlRecord, BehaviorQualifier

**Score:** entidades_encontradas / 10 (cap 100%)

---

## Fase 2 — Naming & Routes (25%)

### API Routes
`/api/accounts`, `/api/transfers`, `/api/payments`, `/api/settlements`, `/api/positions`, `/api/instructions`, `/api/kyc`, `/api/scoring`, `/api/reconciliation`

### Namespaces y paquetes
`Banking.*`, `Settlement.*`, `Risk.*`, `Trading.*`, `Payments.*`, `Core.*`, `Clearing.*`

### Kafka Topics
`payments.*`, `accounts.*`, `settlement.*`, `risk.*`, `fraud.*`, `kyc.*`, `transactions.*`

**Score:** routes_encontradas / 5 (cap 100%)

---

## Fase 3 — Dependencies (15%)

### Infrastructure
kafka, confluent-kafka, spring-kafka, aws-msk, snowflake-connector, apache-iceberg, denodo

### ML/AI
mlflow, evidently, shap, lime, feast, sagemaker, vertex-ai

### Banking-specific
swift-sdk, iso20022, sepa-tools, bian-api, open-banking-sdk, plaid

### Observability
prometheus-client, grafana-sdk, elasticsearch, cloudwatch-sdk

**Score:** deps_encontradas / 5 (cap 100%)

---

## Fase 4 — Configuration (15%)

### Environment variables
`KAFKA_BROKER*`, `SNOWFLAKE_*`, `SWIFT_*`, `BIAN_*`, `MLFLOW_*`, `SETTLEMENT_*`, `KYC_*`, `AML_*`, `PCI_*`, `BANKING_*`

### Config files
`kafka-config.*`, `snowflake-config.*`, `bian-mapping.*`, `data-classification.*`, `feature-store.*`

### Docker/K8s
Servicios con nombres: `payment-`, `settlement-`, `scoring-`, `fraud-`, `account-`, `kyc-`

**Score:** configs_encontradas / 4 (cap 100%)

---

## Fase 5 — Documentation (10%)

README, docs/, wiki con menciones de: BIAN, TOGAF, ArchiMate, ISO 20022, SWIFT, settlement, core banking, Basel, PSD2, SEPA, open banking, data mesh, feature store, MLOps

**Score:** menciones / 5 (cap 100%)

---

## Score final

```
score = (fase1 × 0.35) + (fase2 × 0.25) + (fase3 × 0.15) + (fase4 × 0.15) + (fase5 × 0.10)
```

- ≥55% → Banking confirmed → ofrecer `/banking-bian`
- 25-54% → Probable banking → preguntar al usuario
- <25% → No banking → ignorar

## Distinción vs finance genérico

Si se detecta banca (score ≥55%): sugerir `/banking-*` commands.
Si solo finanzas (score <55% banking pero ≥55% finance): mantener `/vertical-finance`.
Banking es un subconjunto más específico de finance.
