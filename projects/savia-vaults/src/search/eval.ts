import type { SearchResult } from '../types.js';

/**
 * SE-331 — Evaluación de recuperación (RAGAS-like): precision@k / recall@k.
 *
 * Referente: LightRAG integra RAGAS ("context precision metrics"). SaviaVaults
 * mide calidad de *datos* (SE-288 S6) pero no la calidad de *recuperación*.
 * Esta capa es determinista, sin LLM.
 */

export interface EvalQuery {
  query: string;
  relevantPaths: string[];
  note?: string;
}

export interface RetrievalEvalResult {
  mode: 'bm25' | 'enriched';
  precisionAtK: number[];
  recallAtK: number[];
  meanPrecisionAtK: number;
  meanRecallAtK: number;
  failedQueries: { query: string; relevant: string[]; retrieved: string[] }[];
}

export interface EvalOptions {
  maxResults?: number; // k máximo (default 10)
  topK?: number;
}

export type Searcher = (q: string, maxResults: number) => Promise<SearchResult[]>;

/** precision@k = |relevant ∩ topK| / k */
export function computePrecisionAtK(ranked: string[], relevant: string[], k: number): number {
  if (k <= 0) return 0;
  const topK = ranked.slice(0, k);
  const hits = topK.filter(p => relevant.includes(p)).length;
  return hits / k;
}

/** recall@k = |relevant ∩ topK| / |relevant| */
export function computeRecallAtK(ranked: string[], relevant: string[], k: number): number {
  if (relevant.length === 0) return 0;
  const topK = ranked.slice(0, k);
  const hits = topK.filter(p => relevant.includes(p)).length;
  return hits / relevant.length;
}

/**
 * Ejecuta la evaluación sobre una función de búsqueda inyectada.
 * Determinista.
 */
export async function evaluate(
  queries: EvalQuery[],
  searcher: Searcher,
  modes: ('bm25' | 'enriched')[],
  options: EvalOptions = {},
): Promise<Record<string, RetrievalEvalResult>> {
  const maxResults = options.maxResults ?? 10;
  const result: Record<string, RetrievalEvalResult> = {};

  for (const mode of modes) {
    const precisionAtK = new Array(maxResults).fill(0);
    const recallAtK = new Array(maxResults).fill(0);
    const failedQueries: { query: string; relevant: string[]; retrieved: string[] }[] = [];

    for (const q of queries) {
      const results = await searcher(q.query, maxResults);
      const ranked = results.map(r => r.path);
      const relevant = q.relevantPaths;
      for (let k = 1; k <= maxResults; k++) {
        precisionAtK[k - 1] += computePrecisionAtK(ranked, relevant, k);
        recallAtK[k - 1] += computeRecallAtK(ranked, relevant, k);
      }
      const anyHit = ranked.some(p => relevant.includes(p));
      if (!anyHit) failedQueries.push({ query: q.query, relevant, retrieved: ranked });
    }

    const n = queries.length || 1;
    result[mode] = {
      mode,
      precisionAtK: precisionAtK.map(v => v / n),
      recallAtK: recallAtK.map(v => v / n),
      meanPrecisionAtK: precisionAtK[maxResults - 1] / n,
      meanRecallAtK: recallAtK[maxResults - 1] / n,
      failedQueries,
    };
  }

  return result;
}
