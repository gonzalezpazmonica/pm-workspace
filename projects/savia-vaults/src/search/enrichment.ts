import type { GraphNode } from '../knowledge/graph.js';
import type { PPRRanker } from '../knowledge/ppr.js';
import type { SearchResult } from '../types.js';

/**
 * SE-330 — Context enrichment: fusión BM25 + grafo.
 *
 * Referente: GraphRAG local search dataflow — los hits léxicos se expanden con
 * entidades y relaciones vecinas del grafo antes de devolver contexto.
 * Determinista, sin LLM en el hot path.
 */

export interface EnrichedResult {
  path: string;
  title: string;
  score: number;
  bm25Score: number;
  graphScore: number;
  entities: string[];
  neighbors: { from: string; to: string; type: string }[];
}

const WIKILINK_RX = /\[\[([^\]|]+)(?:\|[^\]]+)?\]\]/g;

/** Entidades del grafo cuya nota vive en el path dado (entity-text-unit mapping). */
function entitiesForPath(graph: { nodes: Map<string, GraphNode> }, path: string): string[] {
  const ids: string[] = [];
  for (const [id, node] of graph.nodes) {
    if (node.path === path) ids.push(id);
  }
  return ids;
}

/** Entidades extra de wikilinks del snippet (resueltas contra el grafo). */
function wikilinkEntities(graph: { nodes: Map<string, GraphNode> }, snippet: string): string[] {
  const ids: string[] = [];
  const wl = snippet.matchAll(WIKILINK_RX);
  for (const w of wl) {
    const t = w[1].trim();
    if (graph.nodes.has(t)) ids.push(t);
  }
  return [...new Set(ids)];
}

export class ContextEnricher {
  /**
   * Enriquecer resultados de búsqueda con score del grafo.
   * score = bm25Score * (1 + alpha * graphScore). Sin entidades → graphScore 0.
   */
  enrich(
    results: SearchResult[],
    graph: { nodes: Map<string, GraphNode> },
    ppr: PPRRanker,
    options?: { alpha?: number },
  ): EnrichedResult[] {
    const alpha = options?.alpha ?? 0.3;
    if (results.length === 0) return [];

    const enriched: EnrichedResult[] = [];
    for (const r of results) {
      // entidades = las que viven en esta nota (mapping por path) + wikilinks
      const entities = [
        ...entitiesForPath(graph, r.path),
        ...wikilinkEntities(graph, r.snippet || ''),
      ];
      let graphScore = 0;
      const neighbors: { from: string; to: string; type: string }[] = [];

      if (entities.length > 0) {
        const scores = ppr.rank(graph, entities);
        // graphScore = max score entre entidades de la nota y sus vecinos
        const related = new Set<string>(entities);
        for (const e of entities) {
          for (const rel of graph.nodes.get(e)?.outgoing ?? []) {
            if (rel.until) continue;
            related.add(rel.target);
            neighbors.push({ from: e, to: rel.target, type: rel.type });
          }
        }
        graphScore = Math.max(...[...related].map(id => scores.get(id) ?? 0));
      }

      const bm25Score = r.score ?? 0;
      const score = bm25Score * (1 + alpha * graphScore);
      enriched.push({
        path: r.path,
        title: r.path.split('/').pop() ?? r.path,
        score,
        bm25Score,
        graphScore,
        entities,
        neighbors,
      });
    }

    return enriched.sort((a, b) => b.score - a.score);
  }
}
