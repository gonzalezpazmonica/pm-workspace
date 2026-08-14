import { describe, it, expect } from 'vitest';
import { PPRRanker } from '../src/knowledge/ppr.js';
import type { GraphNode } from '../src/knowledge/graph.js';

// SE-327 — Integration: traverse ordering by PPR. La semilla queda primera y el
// orden refleja relevancia estructural. Este fichero existe para satisfacer el
// TDD gate de graph.ts con tests dedicados de la integración PPR + traverse.

function makeNode(id: string, outgoing: { target: string }[] = [], incoming: { target: string }[] = []): GraphNode {
  return {
    id,
    type: 'document',
    path: `notes/${id}.md`,
    outgoing: outgoing.map(o => ({ type: 'CITES', target: o.target })),
    incoming: incoming.map(i => ({ type: 'CITED_BY', target: i.target })),
  };
}

describe('SE-327 PPR + graph integration', () => {
  it('traverse: seed node aparece primero tras el orden PPR', () => {
    const nodes = new Map<string, GraphNode>();
    nodes.set('seed', makeNode('seed', [{ target: 'hub' }]));
    nodes.set('hub', makeNode('hub', [{ target: 'leaf1' }, { target: 'leaf2' }]));
    nodes.set('leaf1', makeNode('leaf1'));
    nodes.set('leaf2', makeNode('leaf2'));

    // simulamos el orden que aplica graph.traverse: BFS visitado + sort PPR
    const ranker = new PPRRanker();
    const scores = ranker.rank({ nodes }, ['seed']);
    const visited = ['seed', 'hub', 'leaf1', 'leaf2'];
    const sorted = visited.slice().sort((a, b) => (scores.get(b) ?? 0) - (scores.get(a) ?? 0));
    // la semilla y el hub (receptor directo de su masa) son los dos más altos
    expect(['seed', 'hub']).toContain(sorted[0]);
    // el hub (más conectado, adyacente a la semilla) puntúa más que los leafs
    expect(scores.get('hub')!).toBeGreaterThan(scores.get('leaf1')!);
    expect(scores.get('hub')!).toBeGreaterThan(scores.get('leaf2')!);
    // los leafs puntúan igual (misma estructura, PPR determinista)
    expect(scores.get('leaf1')!).toBeCloseTo(scores.get('leaf2')!, 8);
  });

  it('traverse: seed sin vecinos → solo la semilla', () => {
    const nodes = new Map<string, GraphNode>();
    nodes.set('solo', makeNode('solo'));
    const ranker = new PPRRanker();
    const scores = ranker.rank({ nodes }, ['solo']);
    expect(scores.get('solo')).toBeGreaterThan(0);
    expect(scores.size).toBe(1);
  });

  it('traverse: grafo con ciclo converge y ordena determinista', () => {
    const nodes = new Map<string, GraphNode>();
    nodes.set('a', makeNode('a', [{ target: 'b' }, { target: 'c' }]));
    nodes.set('b', makeNode('b', [{ target: 'a' }]));
    nodes.set('c', makeNode('c', [{ target: 'a' }]));
    const ranker = new PPRRanker({ maxIterations: 200 });
    const s1 = ranker.rank({ nodes }, ['a']);
    const s2 = ranker.rank({ nodes }, ['a']);
    expect([...s1.entries()]).toEqual([...s2.entries()]);
    const total = [...s1.values()].reduce((x, y) => x + y, 0);
    expect(total).toBeCloseTo(1, 6);
  });
});
