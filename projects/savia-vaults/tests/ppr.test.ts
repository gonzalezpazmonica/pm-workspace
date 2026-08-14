import { describe, it, expect } from 'vitest';
import { PPRRanker } from '../src/knowledge/ppr.js';
import type { GraphNode } from '../src/knowledge/graph.js';

// ── Fixtures ────────────────────────────────────────────────────────────────

function makeNode(id: string, type = 'document', outgoing: { target: string; type?: string }[] = []): GraphNode {
  return {
    id,
    type,
    path: `notes/${id}.md`,
    outgoing: outgoing.map(o => ({ type: o.type ?? 'CITES', target: o.target })),
    incoming: [],
  };
}

/** Grafo: a → b → c, a → d, d aislado hacia sí mismo vía ciclo a→d→a. */
function makeGraph(): { nodes: Map<string, GraphNode> } {
  const nodes = new Map<string, GraphNode>();
  nodes.set('a', makeNode('a', 'person', [{ target: 'b' }, { target: 'd' }]));
  nodes.set('b', makeNode('b', 'person', [{ target: 'c' }]));
  nodes.set('c', makeNode('c', 'document'));
  nodes.set('d', makeNode('d', 'project', [{ target: 'a' }]));
  return { nodes };
}

// ── AC-1..AC-8 (SE-327) ────────────────────────────────────────────────────

describe('SE-327 PPRRanker', () => {
  it('AC-1: nodo semilla único tiene el score máximo', () => {
    const g = makeGraph();
    const r = new PPRRanker();
    const scores = r.rank(g, ['a']);
    const max = Math.max(...scores.values());
    expect(scores.get('a')).toBeCloseTo(max, 8);
  });

  it('AC-2: nodos con más caminos desde la semilla puntúan más que aislados', () => {
    const g = makeGraph();
    // añadimos un nodo aislado
    g.nodes.set('iso', makeNode('iso', 'document'));
    const r = new PPRRanker();
    const scores = r.rank(g, ['a']);
    expect((scores.get('b') ?? 0)).toBeGreaterThan(scores.get('iso') ?? 0);
    expect((scores.get('c') ?? 0)).toBeGreaterThan(scores.get('iso') ?? 0);
  });

  it('AC-3: determinista — dos llamadas con mismo input dan mismo output', () => {
    const g = makeGraph();
    const r = new PPRRanker();
    const s1 = r.rank(g, ['a']);
    const s2 = r.rank(g, ['a']);
    expect([...s1.entries()]).toEqual([...s2.entries()]);
  });

  it('AC-4: grafo vacío → Map vacío, no lanza', () => {
    const r = new PPRRanker();
    const scores = r.rank({ nodes: new Map() }, ['a']);
    expect(scores.size).toBe(0);
  });

  it('AC-5: semilla inexistente → comportamiento global uniforme, no lanza', () => {
    const g = makeGraph();
    const r = new PPRRanker();
    const scores = r.rank(g, ['no-existe']);
    expect(scores.size).toBe(g.nodes.size);
  });

  it('AC-6: sin seeds → PageRank global (no lanza, todos con score)', () => {
    const g = makeGraph();
    const r = new PPRRanker();
    const scores = r.rank(g, []);
    expect(scores.size).toBe(g.nodes.size);
  });

  it('AC-7: grafo cíclico converge (no diverge), maxIterations acotado', () => {
    const g = makeGraph(); // a→b→c, a→d→a (ciclo)
    const r = new PPRRanker({ maxIterations: 50, tolerance: 1e-10 });
    const scores = r.rank(g, ['a']);
    expect(scores.size).toBe(4);
    expect(scores.get('a')).toBeGreaterThan(0);
    // suma de scores ≈ 1 (distribución de probabilidad)
    const total = [...scores.values()].reduce((a, b) => a + b, 0);
    expect(total).toBeCloseTo(1, 6);
  });

  it('AC-8: top() ordena descendente y respeta topN', () => {
    const g = makeGraph();
    const r = new PPRRanker();
    const top = r.top(g, ['a'], 2);
    expect(top.length).toBe(2);
    expect(top[0].score).toBeGreaterThanOrEqual(top[1].score);
  });

  it('AC-9: relaciones caducadas (until) no cuentan en la transición', () => {
    const nodes = new Map<string, GraphNode>();
    nodes.set('a', {
      id: 'a', type: 'document', path: 'a.md',
      outgoing: [
        { type: 'CITES', target: 'b' },
        { type: 'CITES', target: 'old', since: '2020-01-01', until: '2021-01-01' },
      ],
      incoming: [],
    });
    nodes.set('b', makeNode('b', 'document'));
    nodes.set('old', makeNode('old', 'document'));
    const r = new PPRRanker();
    const scores = r.rank({ nodes }, ['a']);
    // 'old' es target de una relación caducada → no recibe masa directa de a
    expect(scores.get('old') ?? 0).toBeLessThan(scores.get('b') ?? 1);
  });
});
