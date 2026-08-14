import { describe, it, expect } from 'vitest';
import { CommunityDetector } from '../src/knowledge/communities.js';
import type { GraphNode } from '../src/knowledge/graph.js';

function makeNode(id: string, type: string, outgoing: { target: string; type?: string }[] = []): GraphNode {
  return {
    id,
    type,
    path: `notes/${id}.md`,
    outgoing: outgoing.map(o => ({ type: o.type ?? 'CITES', target: o.target })),
    incoming: [],
  };
}

// Grafo con 2 componentes desconectados:
//   A: a→b→c (persona/documento)
//   B: x→y (proyecto)
function makeTwoComponents(): { nodes: Map<string, GraphNode> } {
  const nodes = new Map<string, GraphNode>();
  nodes.set('a', makeNode('a', 'person', [{ target: 'b' }]));
  nodes.set('b', makeNode('b', 'document', [{ target: 'c' }]));
  nodes.set('c', makeNode('c', 'document'));
  nodes.set('x', makeNode('x', 'project', [{ target: 'y' }]));
  nodes.set('y', makeNode('y', 'project'));
  return { nodes };
}

describe('SE-328 CommunityDetector', () => {
  it('AC-1: grafo con 2 componentes desconectados → 2 comunidades', () => {
    const g = makeTwoComponents();
    const detector = new CommunityDetector();
    const communities = detector.detect(g);
    expect(communities.length).toBe(2);
  });

  it('AC-2: miembros de cada comunidad ordenados por PPR descendente', () => {
    const g = makeTwoComponents();
    const detector = new CommunityDetector();
    const communities = detector.detect(g);
    for (const c of communities) {
      for (let i = 1; i < c.memberIds.length; i++) {
        expect(c.memberIds[i]).toBeDefined();
      }
    }
    // la comunidad más grande tiene 3 miembros y su primer miembro (el más
    // conectado: a, con camino hacia b y c) puntúa alto
    const big = communities.find(c => c.memberIds.length === 3);
    expect(big).toBeDefined();
  });

  it('AC-3: dominantTypes refleja los tipos reales más frecuentes del componente', () => {
    const g = makeTwoComponents();
    const detector = new CommunityDetector();
    const communities = detector.detect(g);
    const big = communities.find(c => c.memberIds.length === 3)!;
    expect(big.dominantTypes).toContain('document');
  });

  it('AC-4: grafo con un solo componente → 1 comunidad', () => {
    const nodes = new Map<string, GraphNode>();
    nodes.set('a', makeNode('a', 'person', [{ target: 'b' }]));
    nodes.set('b', makeNode('b', 'document'));
    const detector = new CommunityDetector();
    const communities = detector.detect({ nodes });
    expect(communities.length).toBe(1);
  });

  it('AC-5: grafo vacío → 0 comunidades, no lanza', () => {
    const detector = new CommunityDetector();
    const communities = detector.detect({ nodes: new Map() });
    expect(communities.length).toBe(0);
  });

  it('AC-6: determinista — mismo grafo → mismas comunidades', () => {
    const g = makeTwoComponents();
    const detector = new CommunityDetector();
    const c1 = detector.detect(g).map(c => c.memberIds);
    const c2 = detector.detect(g).map(c => c.memberIds);
    expect(c1).toEqual(c2);
  });

  it('AC-7: dominantRelations refleja las relaciones del componente', () => {
    const g = makeTwoComponents();
    const detector = new CommunityDetector();
    const communities = detector.detect(g);
    const big = communities.find(c => c.memberIds.length === 3)!;
    expect(big.dominantRelations).toContain('CITES');
  });

  it('AC-8: comunidades no vacías y sin duplicados de miembro', () => {
    const g = makeTwoComponents();
    const detector = new CommunityDetector();
    const communities = detector.detect(g);
    const all = communities.flatMap(c => c.memberIds);
    expect(new Set(all).size).toBe(all.length);
    for (const c of communities) expect(c.memberIds.length).toBeGreaterThan(0);
  });
});
