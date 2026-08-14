import { describe, it, expect } from 'vitest';
import { computePrecisionAtK, computeRecallAtK, evaluate } from '../src/search/eval.js';

const ranked = ['a', 'b', 'c', 'd', 'e'];
const relevant = ['a', 'c', 'x'];

describe('SE-331 precision@k', () => {
  it('AC-1: precision@1 con relevante en top-1 → 1', () => {
    expect(computePrecisionAtK(ranked, relevant, 1)).toBe(1);
  });

  it('precision@3 con 2 de 3 relevantes → 2/3', () => {
    expect(computePrecisionAtK(ranked, relevant, 3)).toBeCloseTo(2 / 3, 8);
  });

  it('precision@10 con 2 relevantes encontrados → 0.2', () => {
    expect(computePrecisionAtK(ranked, relevant, 10)).toBe(0.2);
  });
});

describe('SE-331 recall@k', () => {
  it('AC-2: recall@1 cuando único relevante en top-1 → 1', () => {
    expect(computeRecallAtK(['a'], ['a'], 1)).toBe(1);
  });

  it('AC-3: recall@10 con relevante fuera del top-10 → 0', () => {
    expect(computeRecallAtK(['a', 'b'], ['z', 'w'], 10)).toBe(0);
  });

  it('recall@3 con 2 de 3 relevantes → 2/3', () => {
    expect(computeRecallAtK(ranked, relevant, 3)).toBeCloseTo(2 / 3, 8);
  });
});

describe('SE-331 evaluate', () => {
  const queries = [
    { query: 'q1', relevantPaths: ['a', 'c'] },
    { query: 'q2', relevantPaths: ['z'] },
  ];

  it('AC-4: compara modos bm25 y enriched con métricas separadas', async () => {
    const searcher = async () => [
      { path: 'a', score: 0.9, snippet: 'a', tags: [] },
      { path: 'b', score: 0.5, snippet: 'b', tags: [] },
    ];
    const result = await evaluate(queries, searcher, ['bm25', 'enriched'], { maxResults: 10 });
    expect(result['bm25']).toBeDefined();
    expect(result['enriched']).toBeDefined();
    expect(result['bm25'].meanRecallAtK).toBeGreaterThanOrEqual(0);
    expect(result['bm25'].meanRecallAtK).toBeLessThanOrEqual(1);
  });

  it('AC-5: failedQueries lista las que no recuperan relevante', async () => {
    const searcher = async () => [];
    const result = await evaluate(queries, searcher, ['bm25'], { maxResults: 10 });
    expect(result['bm25'].failedQueries.length).toBe(2);
  });

  it('AC-8: determinista — mismas entradas → mismas métricas', async () => {
    const searcher = async () => [{ path: 'a', score: 0.9, snippet: 'a', tags: [] }];
    const r1 = await evaluate(queries, searcher, ['bm25'], { maxResults: 10 });
    const r2 = await evaluate(queries, searcher, ['bm25'], { maxResults: 10 });
    expect(r1['bm25'].meanPrecisionAtK).toBe(r2['bm25'].meanPrecisionAtK);
    expect(r1['bm25'].meanRecallAtK).toBe(r2['bm25'].meanRecallAtK);
  });
});
