---
name: banking-mlops-audit
description: Auditar pipeline MLOps — versionado, drift, XAI, model risk, scoring architectures
developer_type: all
agent: task
context_cost: high
---

# /banking-mlops-audit [--project {nombre}] [--focus pipeline|risk|xai|scoring]

> 🏦 Audita tu pipeline MLOps bancario: versionado, drift, explicabilidad, riesgo de modelos.

---

## Cargar perfil y skill

Grupo: **Architecture & Tech** — cargar `identity.md` + `projects.md` + `preferences.md`.
Skill: `@.claude/skills/banking-architecture/SKILL.md`

## Parámetros

- `--project {nombre}` — Proyecto (default: activo)
- `--focus {area}` — Focalizar: `pipeline` | `risk` | `xai` | `scoring` (default: all)

## Flujo

### Paso 1 — Detectar stack MLOps

Buscar en config, deps y código:
- Model registry: MLflow, Weights & Biases, SageMaker, Vertex AI
- Training: PyTorch, TensorFlow, scikit-learn, XGBoost, LightGBM
- Monitoring: Evidently, WhyLabs, NannyML, Great Expectations
- Serving: Seldon, KServe, TorchServe, SageMaker Endpoint
- GenAI: LangChain, LlamaIndex, vector DBs (Pinecone, Weaviate, pgvector)
- Orchestration: Airflow, Kubeflow, Prefect

### Paso 2 — Auditar CI/CD/CT Pipeline

| Check | Esperado | Criticidad |
|-------|----------|------------|
| Model versioning | Cada modelo versionado con metadata | CRITICAL |
| Data versioning | Dataset snapshots reproducibles | CRITICAL |
| Automated training (CT) | Retrain trigger definido | WARNING |
| Automated testing | Unit + integration + model quality | CRITICAL |
| Staging environment | Modelos probados antes de prod | CRITICAL |
| Rollback mechanism | Volver a versión anterior en <5min | CRITICAL |
| A/B testing / Shadow mode | Comparar modelos en paralelo | WARNING |

### Paso 3 — Auditar Model Risk Management

Basado en SR 11-7 (Federal Reserve) y EBA Guidelines:

- **Model inventory:** ¿Existe registro de todos los modelos en producción?
- **Model documentation:** ¿Cada modelo tiene model card con: propósito, datos, métricas, limitaciones?
- **Validation:** ¿Modelos validados por equipo independiente?
- **Performance monitoring:** ¿Métricas monitoreadas (AUC, precision, recall, calibration)?
- **Drift detection:** ¿Data drift y concept drift monitoreados?
- **Challenger models:** ¿Existe benchmark contra modelo challenger?
- **Materiality assessment:** ¿Clasificación por impacto (Tier 1/2/3)?

### Paso 4 — Auditar Explicabilidad (XAI)

| Check | Esperado | Criticidad |
|-------|----------|------------|
| SHAP values disponibles | Para modelos de scoring | CRITICAL |
| LIME o alternativa | Para explicaciones locales | WARNING |
| Feature importance | Documentada y versionada | CRITICAL |
| Fairness metrics | Bias por género, edad, origen | CRITICAL |
| Adverse action reasons | Motivos de rechazo para clientes | CRITICAL (regulatorio) |
| Model cards | Documentación estándar por modelo | WARNING |

### Paso 5 — Auditar Scoring Architectures

Evaluar diseño de scoring (batch y real-time):

**Batch scoring:**
- Airflow/Spark → Feature Store → Model → Snowflake → Downstream
- ¿Frecuencia adecuada? ¿Reconciliación con real-time?

**Real-time scoring:**
- API REST/gRPC → Feature Store (real-time) → Model → Response
- ¿Latencia p99 < 100ms? ¿Fallback si modelo no disponible?

**Event-driven scoring:**
- Kafka event → Scoring service → Result event → Consumer
- ¿Idempotente? ¿DLQ para scoring fallido?

### Paso 6 — Evaluar GenAI (si aplica)

- RAG: ¿Documentos indexados con lineage? ¿Hallucination detection?
- Prompts: ¿Gestionados con versionado? ¿Prompt injection prevention?
- Vector DB: ¿Embeddings versionados? ¿Relevance metrics?
- Fine-tuning: ¿LoRA/adapters con reproducibilidad?
- Safety: ¿Content filters? ¿PII detection en prompts y responses?

### Paso 7 — Generar informe

```markdown
# 🏦 MLOps Audit — {proyecto}

**Stack:** {tecnologías detectadas}
**Modelos en prod:** {N} | **GenAI:** {Sí/No}

## Health Score
| Área | Score | Issues |
|------|-------|--------|
| CI/CD/CT Pipeline | {n}% | {N} |
| Model Risk Mgmt | {n}% | {N} |
| Explicabilidad (XAI) | {n}% | {N} |
| Scoring Architecture | {n}% | {N} |
| GenAI (si aplica) | {n}% | {N} |

## Issues Críticos
1. ❌ {descripción}

## Recomendaciones
- {acción priorizada}
```

Output: `output/banking-mlops-{proyecto}-{fecha}.md`

## Restricciones

- **NUNCA** acceder a datos de entrenamiento reales
- **NUNCA** dar consejo regulatorio vinculante sobre model risk
- Análisis de código y config, no de modelos en ejecución
- Recomendar validación independiente por Model Risk Management
