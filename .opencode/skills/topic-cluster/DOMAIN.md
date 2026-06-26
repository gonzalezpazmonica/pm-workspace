# Domain: Topic Cluster

> Discover cross-project patterns that keyword heuristics miss.
> Spec: SE-033 — `docs/propuestas/SE-033-topic-cluster-skill.md`

## Problema

`retro-patterns`, `backlog-patterns`, `lesson-extract`, `incident-correlate` agrupan documentos con heurísticas frágiles:
- Keyword matching exacto (pierde sinónimos y parafraseos)
- Regex sobre tags manuales (pierde si tag falta)
- Co-ocurrencia superficial (no mide intención)

Resultado: patrones reales cross-proyecto no se detectan hasta la tercera ocurrencia. Aprendizaje compuesto perdido.

## Solución

BERTopic (Grootendorst 2022): pipeline de 3 pasos bien validado en literatura:

```
docs → Sentence-BERT embeddings → UMAP dim-reduction → HDBSCAN clustering → c-TF-IDF labeling
```

Cada paso es sustituible. c-TF-IDF genera labels legibles sin LLM.

## Arquitectura

| Componente | Responsabilidad |
|---|---|
| `scripts/topic-cluster.py` | Wrapper stdin→stdout, ImportError graceful |
| `bertopic` lib | Pipeline orchestrator |
| `sentence-transformers` | all-MiniLM-L6-v2 embeddings (lightweight) |
| `UMAP` | Dimensional reduction (dense vectors → 5D) |
| `HDBSCAN` | Density-based clustering (no pre-set K) |
| `fallback_keyword_cluster` | Non-ML fallback por keyword counting |

## Integracion downstream

| Consumer | Input | Output útil |
|---|---|---|
| `retro-patterns` | Todas las retros del último Q | Clusters temáticos del quarter |
| `backlog-patterns` | Backlog completo | Duplicate candidates semánticos |
| `lesson-extract` | Cross-project lessons | Patrones reusables |
| `incident-correlate` | Últimos N incidents | Root-cause clusters |

Integration: cada consumer pipes su JSON a `topic-cluster.py`. Sin cambio de interfaz consumer.

## Tradeoffs

**Pros**:
- Descubre patrones sin keyword pre-definido
- Labels auto-generados (c-TF-IDF)
- Zero-install default (fallback keyword)
- HDBSCAN no fuerza K arbitrario

**Contras**:
- Latencia 10-30s en 100 docs (no hot-path)
- HDBSCAN sensible a `min_cluster_size`
- Precision baja con <50 docs
- Modelo sbert +200MB disco

## Limitaciones conocidas

- **Corpora pequeños**: <20 docs → resultados ruidosos
- **Docs muy cortos**: <20 palabras → embeddings poco informativos
- **Multi-idioma mezclado**: sbert all-MiniLM es ~OK pero mejor con modelo multilingüe
- **Nuevos temas emergentes**: necesitan umbrales ajustados

## Métrica de éxito (SE-033)

>=3 clusters útiles sobre corpus real de 50+ documentos, donde "útil" = humano al verlos dice "sí, esto es un tema real".

Evaluación propuesta:
1. Exportar 50 retros reales
2. Correr topic-cluster
3. Humano etiqueta cada cluster: `útil|ruido|ambiguo`
4. Target: >=60% `útil`

## Roadmap futuro

- Slice 3 (post-adoption): integración auto en `retro-patterns` --cluster flag
- Slice 4: benchmark sobre corpus proyecto real (aceptance criteria)
- Slice 5: persistencia de topics entre sprints (detectar patron recurrente)
- Slice 6: visualización HTML interactive (opcional)
