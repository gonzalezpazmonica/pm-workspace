---
name: banking-architecture
description: Skill: Banking Architecture
maturity: beta
category: "governance"
tags: ["banking", "architecture", "finance", "compliance"]
priority: "low"
---

# Skill: Banking Architecture

> Conocimiento especializado para equipos de desarrollo, arquitectura y PM en entornos bancarios.

---

## Cuándo usar

- Proyecto detectado como bancario (score ≥55% en `/banking-detect`)
- Comandos `/banking-*` invocan este skill automáticamente
- Arquitecto o PM trabaja con stack BIAN, Kafka, Snowflake, MLOps

## References disponibles

| Reference | Uso | Cargado por |
|-----------|-----|-------------|
| `bian-framework.md` | Service domains, metamodelo BIAN, ArchiMate | `/banking-bian` |
| `eda-patterns-banking.md` | Saga, CQRS, Event Sourcing, Kafka topologías | `/banking-eda-validate` |
| `data-governance-banking.md` | Lineage, clasificación, feature stores, data mesh | `/banking-data-governance` |

## Flujo general

```
/banking-detect → identifica proyecto bancario
       ↓
/banking-bian → valida arquitectura vs BIAN
       ↓
/banking-eda-validate → valida pipelines Kafka/EDA
       ↓
/banking-data-governance → audita gobierno de datos
       ↓
/banking-mlops-audit → audita pipeline ML/IA
```

## Stack típico detectado

**Infraestructura:** AWS/Azure, Docker, Kubernetes/OpenShift
**Messaging:** Kafka, MSK, AMQ, Apache Pulsar
**Data:** Snowflake, Iceberg, Denodo, Delta Lake
**ML:** MLflow, Evidently, SageMaker, Vertex AI
**Observabilidad:** Prometheus, Grafana, ELK, CloudWatch
**CI/CD:** Jenkins, Bitbucket, Azure DevOps, GitHub Actions
**Estándares:** BIAN, TOGAF, ArchiMate, ISO 20022, SWIFT

## Integración con pm-workspace

- `/arch-detect` → Si banking detected → sugiere `/banking-bian`
- `/diagram-generate --type archimate` → Usa templates BIAN
- `/obs-query` → Dashboards bancarios: settlement latency, TPS, liquidity
- `/vertical-finance` → Complementario (compliance) vs banking (tooling)
- `/compliance-scan --sector banking` → Extiende sector finance

## Restricciones

- **NUNCA** acceder a datos financieros reales sin autorización explícita
- **NUNCA** dar consejo de inversión o regulatorio vinculante
- **SIEMPRE** marcar recomendaciones como "sugerencia técnica, no asesoría legal"
- Las regulaciones varían por jurisdicción (EU, US, LATAM, APAC)
