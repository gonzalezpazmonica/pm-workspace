# GraphRAG Quality Gates — SE-030-T

> 12 thresholds derivados del bytebell "Three-Layer GraphRAG Evaluation Framework" (Dic '25). Se chequean en `eval-run` y el Court. Fallar cualquier threshold bloquea `sprint-close`.

## Thresholds canónicos

### Retrieval layer

| Métrica | Threshold | Significado |
|---|---|---|
| NDCG@10 | ≥ 0.75 | Normalized Discounted Cumulative Gain top-10 |
| Recall@20 | ≥ 0.85 | Recall de chunks relevantes en top-20 |
| MRR | ≥ 0.6 | Mean Reciprocal Rank |
| Cross-Repo Precision | ≥ 0.7 | Precisión al buscar entre múltiples repos |

### Reasoning layer

| Métrica | Threshold | Significado |
|---|---|---|
| Context Coherence | ≥ 0.9 | Coherencia semántica entre chunks recuperados |
| Relevance | ≥ 0.8 | Proporción de chunks relevantes a la query |
| Completeness | ≥ 0.85 | Cobertura del contexto necesario |

### Generation layer

| Métrica | Threshold | Significado |
|---|---|---|
| Groundedness | ≥ 0.9 | Respuesta fundamentada en chunks recuperados |
| Hallucination | ≤ 0.1 | Afirmaciones sin soporte en chunks |
| Attribution Accuracy | ≥ 0.95 | Citas correctas (file:line) |
| Factual Accuracy | ≥ 0.9 | Exactitud factual verificable |
| Coherence (gen) | ≥ 0.85 | Coherencia del output generado |

## Uso

### Validar un resultado

```bash
bash scripts/graphrag-quality-gate.sh --metrics results.json
```

`results.json` debe contener las 12 métricas. Exit codes:
- `0` — todos los thresholds PASS
- `1` — algún threshold FAIL
- `2` — input malformado

### Integración

- `eval-run` invoca este gate tras cada evaluación
- `sprint-close` bloquea si alguno FAIL
- Court `correctness-judge` y `pr-agent-judge` consultan thresholds

## Rollout

1. **Fase 1**: WARN sólo (metrics recolectadas sin bloquear)
2. **Fase 2 (+2 sprints)**: FAIL en Generation layer (Hallucination ≤ 0.1, Groundedness ≥ 0.9, Attribution ≥ 0.95)
3. **Fase 3 (+4 sprints)**: FAIL en todas las 12

## Fuentes

- [bytebell — Three-Layer GraphRAG Eval Framework](https://bytebell.ai/blog) Dic '25
- [bytebell — End-to-End Stress Test](https://bytebell.ai/blog) Ene '26
- SE-030 — `docs/propuestas/SE-030-graphrag-quality-gates.md`
