import type { GraphNode, GraphSnapshot } from './graph.js';

/**
 * SE-327 — Personalized PageRank determinista (power method, sin deps, sin LLM).
 *
 * Referente: Microsoft GraphRAG usa community detection + rank ponderado; el
 * comentario "GraphRAG + PPR" del artículo de referencia (LinkedIn) apunta a
 * PPR como mecanismo de relevancia. PPR responde a "qué nodos son más
 * relevantes dado un conjunto semilla".
 *
 * rank = (1-d) * seedVector + d * (M^T * rank), iterado hasta convergencia.
 * Determinista: mismo input → mismo output.
 */

export interface PPRParams {
  /** Factor de amortiguación. Default 0.85. */
  damping?: number;
  /** Máximo de iteraciones. Default 100. */
  maxIterations?: number;
  /** Tolerancia de convergencia (norma L1 del delta). Default 1e-8. */
  tolerance?: number;
}

export class PPRRanker {
  private damping: number;
  private maxIterations: number;
  private tolerance: number;

  constructor(params: PPRParams = {}) {
    this.damping = params.damping ?? 0.85;
    this.maxIterations = params.maxIterations ?? 100;
    this.tolerance = params.tolerance ?? 1e-8;
  }

  /**
   * Ranking PPR sobre el grafo dado un seed set.
   * Devuelve Map<nodeId, score> (solo nodos con score > 0), sin orden.
   * Seeds vacíos → vector uniforme global (PageRank clásico).
   * Semilla inexistente → ignorada. Grafo vacío → Map vacío.
   */
  rank(graph: GraphSnapshot | { nodes: Map<string, GraphNode> }, seeds: string[] = [], params?: PPRParams): Map<string, number> {
    const d = params?.damping ?? this.damping;
    const maxIter = params?.maxIterations ?? this.maxIterations;
    const tol = params?.tolerance ?? this.tolerance;

    const nodes = graph.nodes;
    const ids = [...nodes.keys()];
    if (ids.length === 0) return new Map<string, number>();
    const n = ids.length;
    const index = new Map(ids.map((id, i) => [id, i]));

    // Matriz de transición: out[i] = índices de los targets de cada nodo.
    const out: number[][] = new Array(n);
    for (let i = 0; i < n; i++) out[i] = [];

    for (let i = 0; i < n; i++) {
      const node = nodes.get(ids[i])!;
      const targets = new Set<number>();
      for (const rel of node.outgoing) {
        if (rel.until) continue; // relaciones caducadas no cuentan
        const ti = index.get(rel.target);
        if (ti !== undefined) targets.add(ti);
      }
      out[i] = [...targets];
    }

    // Seed vector (uniforme sobre seeds válidas; global uniforme si vacío).
    const seed = new Array(n).fill(0);
    const validSeeds = seeds.filter(s => index.has(s));
    if (validSeeds.length > 0) {
      const w = 1 / validSeeds.length;
      for (const s of validSeeds) seed[index.get(s)!] = w;
    } else {
      for (let i = 0; i < n; i++) seed[i] = 1 / n;
    }

    let rank = seed.slice();
    for (let iter = 0; iter < maxIter; iter++) {
      const next = new Array(n).fill(0);
      const danglingMass = d * rank.reduce((acc, v, i) => (out[i].length === 0 ? acc + v : acc), 0);

      for (let i = 0; i < n; i++) {
        const deg = out[i].length;
        if (deg === 0) continue;
        const contrib = (d * rank[i]) / deg;
        for (const t of out[i]) next[t] += contrib;
      }

      const uniform = danglingMass / n;
      for (let i = 0; i < n; i++) {
        next[i] = next[i] + uniform + (1 - d) * seed[i];
      }

      let delta = 0;
      for (let i = 0; i < n; i++) delta += Math.abs(next[i] - rank[i]);
      rank = next;
      if (delta < tol) break;
    }

    const result = new Map<string, number>();
    for (let i = 0; i < n; i++) {
      if (rank[i] > 0) result.set(ids[i], rank[i]);
    }
    return result;
  }

  /** Top-N ordenado descendente: [{id, score}]. */
  top(graph: GraphSnapshot | { nodes: Map<string, GraphNode> }, seeds: string[] = [], topN = 10, params?: PPRParams): { id: string; score: number }[] {
    const scores = this.rank(graph, seeds, params);
    return [...scores.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, topN)
      .map(([id, score]) => ({ id, score }));
  }
}
