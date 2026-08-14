import * as crypto from 'node:crypto';
import { VaultStorage } from '../storage/index.js';
import { Introspector } from './introspector.js';
import { PPRRanker } from './ppr.js';
import type { VaultConfig } from '../types.js';

export interface Relation {
  type: string;
  target: string;
  since?: string;
  until?: string;
}

export interface GraphNode {
  id: string;
  type: string;
  path: string;
  outgoing: Relation[];
  incoming: Relation[];
}

export interface GraphSnapshot {
  nodes: Map<string, GraphNode>;
  hash: string;
  relationTypes: string[];
}

export class KnowledgeGraph {
  private storage: VaultStorage;
  private introspector: Introspector;
  private snapshot: GraphSnapshot | null = null;

  private static readonly RELATION_DEFAULTS: Record<string, string> = {
    DEPENDS_ON: 'REQUIRED_BY',
    PART_OF: 'CONTAINS',
    REPLACES: 'REPLACED_BY',
    CITES: 'CITED_BY',
    CONTRADICTS: 'CONTRADICTED_BY',
    SUPERSEDES: 'SUPERSEDED_BY',
    MENTIONS: 'MENTIONED_BY',
  };

  constructor(config: VaultConfig) {
    this.storage = new VaultStorage(config);
    this.introspector = new Introspector(config);
  }

  async build(): Promise<GraphSnapshot> {
    const files = await this.storage.list();
    const nodes = new Map<string, GraphNode>();
    const relationTypes = new Set<string>();

    for (const f of files) {
      try {
        const note = await this.storage.read(f);
        const entity = note.frontmatter.entity as Record<string, unknown> | undefined;
        const id = (entity?.id as string) || f;
        const type = (entity?.type as string) || 'document';

        const outgoing: Relation[] = [];
        if (Array.isArray(note.frontmatter.relations)) {
          for (const r of note.frontmatter.relations as Relation[]) {
            if (r.type && r.target) {
              outgoing.push(r);
              relationTypes.add(r.type);
            }
          }
        }

        // Derive MENTIONS from wikilinks in content
        const wikiLinks = note.content.match(/\[\[([^\]]+)\]\]/g);
        if (wikiLinks) {
          for (const link of wikiLinks) {
            const target = link.slice(2, -2).split('|')[0];
            if (!outgoing.some(r => r.target === target)) {
              outgoing.push({ type: 'MENTIONS', target });
              relationTypes.add('MENTIONS');
            }
          }
        }

        nodes.set(id, { id, type, path: f, outgoing, incoming: [] });
      } catch {}
    }

    // Compute incoming relations
    for (const [, node] of nodes) {
      for (const rel of node.outgoing) {
        const target = nodes.get(rel.target);
        if (target) {
          const inverseType = KnowledgeGraph.RELATION_DEFAULTS[rel.type] || `INVERSE_${rel.type}`;
          target.incoming.push({ type: inverseType, target: node.id, since: rel.since, until: rel.until });
          relationTypes.add(inverseType);
        }
      }
    }

    const hash = crypto.createHash('sha256')
      .update(JSON.stringify([...nodes.entries()].map(([k, v]) => [k, v.outgoing])))
      .digest('hex');

    this.snapshot = { nodes, hash, relationTypes: [...relationTypes] };
    return this.snapshot;
  }

  getNode(id: string): GraphNode | undefined {
    return this.snapshot?.nodes.get(id);
  }

  getOutgoing(id: string): Relation[] {
    return this.snapshot?.nodes.get(id)?.outgoing || [];
  }

  getIncoming(id: string): Relation[] {
    return this.snapshot?.nodes.get(id)?.incoming || [];
  }

  traverse(startId: string, maxDepth = 3, maxNodes = 100): { nodes: GraphNode[]; relations: { from: string; to: string; type: string }[] } {
    if (!this.snapshot) return { nodes: [], relations: [] };

    const visited = new Set<string>();
    const resultNodes: GraphNode[] = [];
    const resultRelations: { from: string; to: string; type: string }[] = [];
    let frontier = [startId];

    for (let depth = 0; depth < maxDepth && frontier.length > 0 && resultNodes.length < maxNodes; depth++) {
      const nextFrontier: string[] = [];
      for (const id of frontier) {
        if (visited.has(id)) continue;
        visited.add(id);
        const node = this.snapshot!.nodes.get(id);
        if (!node || resultNodes.length >= maxNodes) continue;
        resultNodes.push(node);

        for (const rel of node.outgoing) {
          if (!rel.until) {
            resultRelations.push({ from: id, to: rel.target, type: rel.type });
            if (!visited.has(rel.target)) nextFrontier.push(rel.target);
          }
        }
        for (const rel of node.incoming) {
          if (!rel.until) {
            if (!resultRelations.some(r => r.from === rel.target && r.to === id && r.type === rel.type)) {
              resultRelations.push({ from: rel.target, to: id, type: rel.type });
            }
            if (!visited.has(rel.target)) nextFrontier.push(rel.target);
          }
        }
      }
      frontier = nextFrontier;
    }

    // SE-327: ordenar nodos visitados por PPR (semilla = startId) — el más
    // relevante primero. No cambia el conjunto, solo el orden.
    if (resultNodes.length > 1) {
      const ranker = new PPRRanker();
      const scores = ranker.rank(this.snapshot, [startId]);
      resultNodes.sort((a, b) => (scores.get(b.id) ?? 0) - (scores.get(a.id) ?? 0));
    }

    return { nodes: resultNodes, relations: resultRelations };
  }

  searchNodes(query: string): GraphNode[] {
    if (!this.snapshot) return [];
    const q = query.toLowerCase();
    return [...this.snapshot.nodes.values()].filter(n =>
      n.id.toLowerCase().includes(q) || n.type.toLowerCase().includes(q)
    );
  }

  getStats(): { nodeCount: number; relationCount: number; relationTypes: string[] } {
    if (!this.snapshot) return { nodeCount: 0, relationCount: 0, relationTypes: [] };
    let relationCount = 0;
    for (const [, node] of this.snapshot.nodes) {
      relationCount += node.outgoing.length;
    }
    return { nodeCount: this.snapshot.nodes.size, relationCount, relationTypes: this.snapshot.relationTypes };
  }

  /** SE-327: expone el snapshot actual (para PPR ranking externo). */
  getSnapshot(): { nodes: Map<string, GraphNode> } | null {
    return this.snapshot;
  }
}
