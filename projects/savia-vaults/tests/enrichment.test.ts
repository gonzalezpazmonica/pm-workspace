import { describe, it, expect } from 'vitest';
import { ContextEnricher } from '../src/search/enrichment.js';
import { PPRRanker } from '../src/knowledge/ppr.js';
import type { GraphNode } from '../src/knowledge/graph.js';
import type { SearchResult } from '../src/types.js';

function makeNode(id: string, outgoing: { target: string }[] = []): GraphNode {
  return {
    id,
    type: 'document',
    path: `notes/${id}.md`,
    outgoing: outgoing.map(o => ({ type: 'CITES', target: o.target })),
    incoming: [],
  };
}

function makeGraph(): { nodes: Map<string, GraphNode> } {
  const nodes = new Map<string, GraphNode>();
  nodes.set('alice', makeNode('alice', [{ target: 'project-x' }]));
  nodes.set('project-x', makeNode('project-x', [{ target: 'doc-b' }]));
  nodes.set('doc-b', makeNode('doc-b'));
  return { nodes };
}

function makeResults(): SearchResult[] {
  return [
    { path: 'notes/alice.md', score: 0.8, snippet: 'alice', tags: [] },
    { path: 'notes/no-entity.md', score: 0.5, snippet: 'sin entidad', tags: [] },
  ];
}

describe('SE-330 ContextEnricher', () => {
  it('AC-2: nota con entidad → graphScore > 0 y score final > bm25', () => {
    const graph = makeGraph();
    const ppr = new PPRRanker();
    const enricher = new ContextEnricher();
    const enriched = enricher.enrich(makeResults(), graph, ppr, { alpha: 0.3 });
    const alice = enriched.find(r => r.path.includes('alice'))!;
    expect(alice.graphScore).toBeGreaterThan(0);
    expect(alice.score).toBeGreaterThan(alice.bm25Score);
  });

  it('AC-3: nota sin entidades → graphScore 0, score == bm25', () => {
    const graph = makeGraph();
    const ppr = new PPRRanker();
    const enricher = new ContextEnricher();
    const enriched = enricher.enrich(makeResults(), graph, ppr, { alpha: 0.3 });
    const noEntity = enriched.find(r => r.path.includes('no-entity'))!;
    expect(noEntity.graphScore).toBe(0);
    expect(noEntity.score).toBeCloseTo(noEntity.bm25Score, 8);
  });

  it('AC-4: neighbors incluye solo primer grado', () => {
    const graph = makeGraph();
    const ppr = new PPRRanker();
    const enricher = new ContextEnricher();
    const enriched = enricher.enrich(makeResults(), graph, ppr, { alpha: 0.3 });
    const alice = enriched.find(r => r.path.includes('alice'))!;
    // alice → project-x (primer grado); doc-b es segundo grado (no debe aparecer)
    expect(alice.neighbors.some(n => n.to === 'project-x')).toBe(true);
    expect(alice.neighbors.some(n => n.to === 'doc-b')).toBe(false);
  });

  it('AC-5: orden final determinista y estable', () => {
    const graph = makeGraph();
    const ppr = new PPRRanker();
    const enricher = new ContextEnricher();
    const r1 = enricher.enrich(makeResults(), graph, ppr, { alpha: 0.3 });
    const r2 = enricher.enrich(makeResults(), graph, ppr, { alpha: 0.3 });
    expect(r1.map(x => x.path)).toEqual(r2.map(x => x.path));
    expect(r1.map(x => x.score)).toEqual(r2.map(x => x.score));
  });

  it('AC-6: sin resultados → array vacío, no lanza', () => {
    const graph = makeGraph();
    const ppr = new PPRRanker();
    const enricher = new ContextEnricher();
    expect(enricher.enrich([], graph, ppr)).toEqual([]);
  });

  it('AC-1: alpha=0 → score == bm25 (enrich neutro)', () => {
    const graph = makeGraph();
    const ppr = new PPRRanker();
    const enricher = new ContextEnricher();
    const enriched = enricher.enrich(makeResults(), graph, ppr, { alpha: 0 });
    const alice = enriched.find(r => r.path.includes('alice'))!;
    expect(alice.score).toBeCloseTo(alice.bm25Score, 8);
  });

  it('AC: entities extraídas del frontmatter/wikilinks de la nota', () => {
    const graph = makeGraph();
    const ppr = new PPRRanker();
    const enricher = new ContextEnricher();
    // la nota alice.md declara entidad alice + wikilink a project-x
    const results: SearchResult[] = [
      {
        path: 'notes/alice.md',
        score: 0.8,
        snippet: '[[project-x]] alice',
        tags: [],
      },
    ];
    const enriched = enricher.enrich(results, graph, ppr, { alpha: 0.3 });
    const alice = enriched[0];
    expect(alice.entities).toContain('alice');
    expect(alice.entities).toContain('project-x');
  });
});
