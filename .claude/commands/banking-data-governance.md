---
name: banking-data-governance
description: Auditar gobierno de datos — lineage, clasificación, GDPR/LOPD, feature stores
developer_type: all
agent: task
context_cost: high
---

# /banking-data-governance [--project {nombre}] [--focus lineage|classification|features|gdpr]

> 🏦 Audita el gobierno de datos de tu proyecto bancario: lineage, clasificación, GDPR.

---

## Cargar perfil y skill

Grupo: **Architecture & Tech** — cargar `identity.md` + `projects.md` + `preferences.md`.
Reference: `@.opencode/skills/banking-architecture/references/data-governance-banking.md`

## Parámetros

- `--project {nombre}` — Proyecto (default: activo)
- `--focus {area}` — Focalizar: `lineage` | `classification` | `features` | `gdpr` (default: all)

## Flujo

### Paso 1 — Detectar stack de datos

Escanear config, deps y código para identificar:
- Data warehouse: Snowflake, BigQuery, Redshift, Synapse
- Data lake: S3, ADLS, GCS con Iceberg/Delta/Hudi
- ETL/ELT: Airflow, dbt, Informatica, Spark
- Feature store: Feast, Tecton, SageMaker FS
- Catálogo: Collibra, Alation, DataHub, Apache Atlas
- Virtualización: Denodo

### Paso 2 — Auditar Data Classification

Escanear modelos de datos, schemas y código buscando:

| Campo | Clasificación esperada | Check |
|-------|----------------------|-------|
| PAN, CVV, PIN | PCI — tokenizado | ❌ si plain text |
| Nombre, DNI, email | PII — cifrado | ❌ si sin cifrar |
| Saldo, scoring | Confidential — acceso restringido | ⚠️ si en logs |
| IBAN | Semi-public — maskeado | ⚠️ si completo en logs |

Verificar que existe `data-classification.md` o equivalente documentado.

### Paso 3 — Auditar Data Lineage

Evaluar trazabilidad:
- ¿Existe documentación de lineage (manual o automática)?
- ¿Hay herramientas de lineage integradas (Atlas, Collibra, DataHub)?
- ¿Los pipelines tienen metadata de origen y transformación?
- ¿Se puede trazar un dato regulatorio desde fuente hasta reporte?

Score de madurez: L0 (sin lineage) → L4 (automático + alertas).

### Paso 4 — Auditar Feature Store (si aplica)

- ¿Existe feature store (batch + real-time)?
- ¿Features versionadas y con lineage?
- ¿Point-in-time correctness para training vs serving?
- ¿Feature drift monitoreado?
- ¿Documentación de cada feature (owner, source, freshness)?

### Paso 5 — Validar GDPR/LOPD

Checklist automático:
- [ ] Registro de actividades de tratamiento (Art. 30)
- [ ] DPIA completado para datos alto riesgo
- [ ] Derecho de acceso implementado (exportar datos en 30 días)
- [ ] Derecho de supresión (con excepciones legales: 10 años transacciones)
- [ ] Consentimientos gestionados y trazables
- [ ] Data retention policies definidas e implementadas
- [ ] Breach notification procedure documentado (72h)
- [ ] DPO designado (obligatorio para banca)

### Paso 6 — Generar informe

```markdown
# 🏦 Data Governance Audit — {proyecto}

**Stack:** {tecnologías detectadas}
**Madurez lineage:** {L0-L4}
**Classification coverage:** {n}%

## Resultados por área
| Área | Score | Issues |
|------|-------|--------|
| Classification | {n}% | {N} issues |
| Lineage | {n}% | {N} issues |
| Feature Store | {n}% | {N} issues |
| GDPR/LOPD | {n}% | {N} issues |

## Issues Críticos
1. ❌ {descripción}

## Recomendaciones
- {acción priorizada}
```

Output: `output/banking-data-gov-{proyecto}-{fecha}.md`

## Restricciones

- **NUNCA** acceder a datos reales de clientes
- **NUNCA** dar asesoría legal sobre GDPR/LOPD
- Análisis basado en código y config, no en datos reales
- Recomendar consultar con DPO para validación final
