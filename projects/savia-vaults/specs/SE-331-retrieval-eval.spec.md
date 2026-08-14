# Spec: SE-331 — Eval de recuperación (RAGAS-like)

**Task ID:**        SE-331
**PBI padre:**      SE-331 — Evaluación de recuperación
**Sprint:**        2026-08
**Fecha creacion:** 2026-08-14
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     typescript-developer
**Estado:**         IMPLEMENTED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 3 h |
| Human effort | 1.5 h |
| Review effort | 15 min |
| Context risk | low |
| Agent-capable | yes |

---

## 1. Contexto y Objetivo

LightRAG integra **RAGAS for Evaluation** (métricas de contexto: precision,
recall) para medir la calidad de recuperación. SaviaVaults tiene quality.ts
(SE-288 S6) sobre *datos* (cobertura, autoridad, caducidad, conflictos) pero
**nada mide la búsqueda**: no hay forma de saber si `search "X"` recupera lo
relevante.

Objetivo: **eval de recuperación determinista** (sin LLM):
- banco de queries de referencia con documentos relevantes esperados,
- métricas precision@k, recall@k sobre `search` (BM25) y `search --enrich`,
- informe publicable en health-report y por CLI.

## 2. Contrato Tecnico

### 2.1 Banco de evaluación

```typescript
// src/search/eval.ts
interface EvalQuery {
  query: string;
  relevantPaths: string[];   // paths que DEBEN recuperarse
  note?: string;
}

interface RetrievalEvalResult {
  mode: 'bm25' | 'enriched';
  precisionAtK: number[];    // por k=1..10
  recallAtK: number[];
  meanPrecisionAtK: number;  // mean precision@10
  meanRecallAtK: number;
  failedQueries: { query: string; relevant: string[]; retrieved: string[] }[];
}
```

Banco por defecto en `projects/savia-vaults/eval/queries.json` (seeder genera
30+ queries sobre el vault real con paths relevantes). Sobreescribible por
`--eval-file`.

### 2.2 Runner

```typescript
class RetrievalEval {
  async run(
    config: VaultConfig,
    queries: EvalQuery[],
    modes: ('bm25' | 'enriched')[]
  ): Promise<Record<string, RetrievalEvalResult>>;
}
```

- precision@k = |relevant ∩ retrieved_k| / k
- recall@k = |relevant ∩ retrieved_k| / |relevant|
- K de 1 a 10 (configurable).

### 2.3 CLI + Health

- `vaults eval search [--modes bm25,enriched] [--top-k 10] [--eval-file <path>]`
  → tabla comparativa + meanPrecision/meanRecall por modo.
- health-report incluye sección `search-eval` (solo si el banco existe) con los
  promedios y bandera de regresión (meanRecall@10 < 0.5 → warning).

## 3. Criterios de aceptacion

- [ ] AC-1: eval con banco mínimo (1 query) computa precision@k y recall@k.
- [ ] AC-2: query donde el relevante está en top-1 → recall@1 = 1.
- [ ] AC-3: query donde el relevante está fuera del top-10 → recall@10 = 0.
- [ ] AC-4: compara modos bm25 y enriched (métricas separadas).
- [ ] AC-5: `--eval-file` externo sobreescribe el banco default.
- [ ] AC-6: `vaults eval search` imprime tabla + promedios.
- [ ] AC-7: health-report incluye `search-eval` cuando existe banco.
- [ ] AC-8: determinista (mismo vault → mismas métricas).

## 4. Tests

`tests/retrieval-eval.test.ts` (vitest): métricas, top-k, modos, banco externo,
determinismo, health integration.

## 5. Notas

- El banco default para SaviaLabs se genera con `vaults eval seed` usando el
  grafo + contenido real; los paths relevantes se toman de entidades fuertemente
  conectadas (PPR alto) para no fabricar expectativas artificiales.
