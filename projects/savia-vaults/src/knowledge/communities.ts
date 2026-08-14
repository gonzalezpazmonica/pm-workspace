import type { GraphNode, GraphSnapshot } from './graph.js';
import { PPRRanker } from './ppr.js';

/**
 * SE-328 — Detección de comunidades + query global (whole-dataset reasoning).
 *
 * Referente: GraphRAG (Microsoft) distingue local vs global search; LightRAG
 * añade modos local/global/hybrid. Esta capa es determinista (sin LLM, sin
 * embeddings — alineado con SE-288).
 *
 * Comunidad = componente conexo del grafo (undirected derivado). Miembros
 * ordenados por PPR (SE-327). Tipos y relaciones dominantes por frecuencia.
 */

export interface Community {
  id: string;
  memberIds: string[];
  dominantTypes: string[];
  dominantRelations: string[];
  size: number;
}

export class CommunityDetector {
  private ppr: PPRRanker;

  constructor() {
    this.ppr = new PPRRanker();
  }

  /**
   * Detecta comunidades = componentes conexos (BFS/DFS sobre undirected).
   * Miembros ordenados por PPR global (sin seeds) descendente.
   */
  detect(graph: GraphSnapshot | { nodes: Map<string, GraphNode> }): Community[] {
    const nodes = graph.nodes;
    const ids = [...nodes.keys()];
    if (ids.length === 0) return [];

    // grafo undirected para componentes conexos
    const adj = new Map<string, Set<string>>();
    for (const id of ids) adj.set(id, new Set());
    for (const id of ids) {
      const node = nodes.get(id)!;
      for (const rel of node.outgoing) {
        if (rel.until) continue;
        if (!nodes.has(rel.target)) continue;
        adj.get(id)!.add(rel.target);
        if (!adj.has(rel.target)) adj.set(rel.target, new Set());
        adj.get(rel.target)!.add(id);
      }
    }

    const scores = this.ppr.rank(graph, []); // PageRank global
    const visited = new Set<string>();
    const communities: Community[] = [];
    let cid = 1;

    for (const start of ids) {
      if (visited.has(start)) continue;

      // BFS componente
      const members: string[] = [];
      const queue = [start];
      visited.add(start);
      while (queue.length > 0) {
        const cur = queue.shift()!;
        members.push(cur);
        for (const nb of adj.get(cur) ?? []) {
          if (!visited.has(nb)) {
            visited.add(nb);
            queue.push(nb);
          }
        }
      }

      // miembros ordenados por PPR descendente
      members.sort((a, b) => (scores.get(b) ?? 0) - (scores.get(a) ?? 0));

      // tipos dominantes (top 3 por frecuencia)
      const typeCount = new Map<string, number>();
      for (const m of members) {
        const t = nodes.get(m)?.type ?? 'document';
        typeCount.set(t, (typeCount.get(t) ?? 0) + 1);
      }
      const dominantTypes = [...typeCount.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(([t]) => t);

      // relaciones dominantes (top 3 por frecuencia entre miembros)
      const relCount = new Map<string, number>();
      for (const m of members) {
        for (const rel of nodes.get(m)?.outgoing ?? []) {
          if (rel.until) continue;
          if (!nodes.has(rel.target)) continue;
          relCount.set(rel.type, (relCount.get(rel.type) ?? 0) + 1);
        }
      }
      const dominantRelations = [...relCount.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(([t]) => t);

      communities.push({
        id: `C${cid++}`,
        memberIds: members,
        dominantTypes,
        dominantRelations,
        size: members.length,
      });
    }

    return communities;
  }

  /**
   * Resumen markdown para query global / health-report.
   */
  summarize(communities: Community[]): string {
    if (communities.length === 0) return '_Vault sin comunidades (grafo vacío)._';
    const lines = ['## Comunidades del vault', ''];
    for (const c of communities) {
      lines.push(`### ${c.id} (${c.size} entidades)`);
      lines.push(`- Tipos dominantes: ${c.dominantTypes.join(', ') || '—'}`);
      lines.push(`- Relaciones dominantes: ${c.dominantRelations.join(', ') || '—'}`);
      const hubs = c.memberIds.slice(0, 3).join(', ');
      lines.push(`- Hubs (top PPR): ${hubs}`);      lines.push('');
    }
    return lines.join('\n');
  }
}
