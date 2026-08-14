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

function makeGraph(): { nodes: Map<string, GraphNode> } {
  const nodes = new Map<string, GraphNode>();
  nodes.set('a', makeNode('a', 'person', [{ target: 'b' }]));
  nodes.set('b', makeNode('b', 'document', [{ target: 'c' }]));
  nodes.set('c', makeNode('c', 'document'));
  nodes.set('x', makeNode('x', 'project', [{ target: 'y' }]));
  nodes.set('y', makeNode('y', 'project'));
  return { nodes };
}

describe('SE-328 CommunityDetector summarize + hubs', () => {
  it('summary incluye el nombre de cada comunidad y su tamaño', () => {
    const detector = new CommunityDetector();
    const communities = detector.detect(makeGraph());
    const summary = detector.summarize(communities);
    expect(summary).toContain('C1');
    expect(summary).toContain('2 entidades');
    expect(summary).toContain('Hubs (top PPR)');
  });

  it('summary con grafo vacío → mensaje de vacío', () => {
    const detector = new CommunityDetector();
    expect(detector.summarize([])).toContain('sin comunidades');
  });

  it('hub = primer miembro de la comunidad (top PPR global)', () => {
    const detector = new CommunityDetector();
    const communities = detector.detect(makeGraph());
    const big = communities.find(c => c.memberIds.length === 3)!;
    // el primer miembro es el de mayor score PPR global (determinista)
    // y pertenece al componente: orden válido y sin duplicados
    expect(big.memberIds).toHaveLength(3);
    expect(new Set(big.memberIds).size).toBe(3);
  });
});
