import { KnowledgeGraph } from './graph.js';
import { Introspector } from './introspector.js';
import { CommunityDetector } from './communities.js';
import { EntityResolver } from './entity-resolution.js';
import { SearchEngine } from '../search/index.js';
import { SchemaRegistry } from '../schema/registry.js';
import type { VaultConfig } from '../types.js';

interface QueryResult {
  entity: string;
  property?: string;
  value: unknown;
  source: string;
  confidence: 'EXACT' | 'FUZZY' | 'INFERRED';
}

interface QueryPlan {
  type: 'property' | 'relation' | 'metric' | 'search';
  entity?: string;
  property?: string;
  relation?: string;
  filter?: Record<string, string>;
  fromDate?: string;
  toDate?: string;
}

export class QueryEngine {
  private graph: KnowledgeGraph;
  private introspector: Introspector;
  private search: SearchEngine;
  private registry: SchemaRegistry;

  constructor(config: VaultConfig) {
    this.graph = new KnowledgeGraph(config);
    this.introspector = new Introspector(config);
    this.search = new SearchEngine(config);
    this.registry = new SchemaRegistry(config.schemaDir || '');
  }

  async ensureLoaded(): Promise<void> {
    await this.graph.build();
  }

  async query(expression: string): Promise<{ results: QueryResult[]; plan: QueryPlan; outputMarkdown: string; outputRows: Record<string, unknown>[] }> {
    const plan = this.parse(expression);
    const results = await this.execute(plan);
    const outputMarkdown = this.formatMarkdown(plan, results);
    const outputRows = results.map(r => ({ entity: r.entity, property: r.property || '', value: r.value, source: r.source, confidence: r.confidence }));

    return { results, plan, outputMarkdown, outputRows };
  }

  private parse(expr: string): QueryPlan {
    const trimmed = expr.trim();

    if (trimmed.includes('.From=') || trimmed.includes('.To=')) {
      const parts = trimmed.split('.');
      const entityPart = parts[0];
      const metricPart = parts.slice(1).join('.');
      const fromMatch = metricPart.match(/From=([^.\s]+)/);
      const toMatch = metricPart.match(/To=([^\s]+)/);
      const metric = metricPart.split('.')[0];

      return {
        type: 'metric',
        entity: entityPart,
        property: metric,
        fromDate: fromMatch?.[1],
        toDate: toMatch?.[1],
      };
    }

    if (trimmed.includes('.')) {
      const parts = trimmed.split('.');
      if (parts.length === 2) {
        return { type: 'property', entity: parts[0], property: parts[1] };
      }
      if (parts.length === 3) {
        return { type: 'relation', entity: parts[0], relation: parts[1], property: parts[2] };
      }
    }

    return { type: 'search', property: trimmed };
  }

  private async execute(plan: QueryPlan): Promise<QueryResult[]> {
    const results: QueryResult[] = [];

    if (plan.type === 'search' && plan.property) {
      this.search.buildIndex();
      const searchResults = this.search.search({ query: plan.property, maxResults: 20 });
      for (const r of searchResults) {
        results.push({
          entity: r.path,
          value: r.snippet,
          source: r.path,
          confidence: 'EXACT',
        });
      }
    }

    if (plan.type === 'property' && plan.entity && plan.property) {
      const node = this.fuzzyFindNode(plan.entity);
      if (node) {
        results.push({
          entity: node.id,
          property: plan.property,
          value: `node:${node.id}`,
          source: node.path,
          confidence: 'EXACT',
        });
      }
    }

    if (plan.type === 'metric' && plan.entity) {
      const node = this.fuzzyFindNode(plan.entity);
      if (node) {
        results.push({
          entity: node.id,
          property: plan.property,
          value: { from: plan.fromDate, to: plan.toDate },
          source: node.path,
          confidence: 'INFERRED',
        });
      }
    }

    return results;
  }

  private fuzzyFindNode(name: string): { id: string; path: string; type: string } | null {
    const lower = name.toLowerCase();

    // SE-329: entity resolution — alias/canonical → id real
    const entities = this.graph.searchNodes(lower);
    const entityList = entities.map(n => ({ id: n.id, alias: [] as string[] }));
    const resolver = new EntityResolver();
    resolver.build(entityList);
    const resolvedId = resolver.resolve(lower);
    if (resolvedId) {
      const resolved = this.graph.getNode(resolvedId);
      if (resolved) return { id: resolved.id, path: resolved.path, type: resolved.type };
    }

    const nodes = this.graph.searchNodes(lower);
    if (nodes.length > 0) {
      const exact = nodes.find(n => n.id.toLowerCase() === lower);
      const match = exact || nodes[0];
      return { id: match.id, path: match.path, type: match.type };
    }
    return null;
  }

  private formatMarkdown(plan: QueryPlan, results: QueryResult[]): string {
    const lines: string[] = [];
    lines.push(`## Query: \`${plan.type}\``);
    if (plan.entity) lines.push(`**Entity:** ${plan.entity}`);
    if (plan.property) lines.push(`**Property:** ${plan.property}`);
    if (plan.fromDate) lines.push(`**From:** ${plan.fromDate}`);
    if (plan.toDate) lines.push(`**To:** ${plan.toDate}`);
    lines.push('');

    if (results.length === 0) {
      lines.push('*(no results)*');
    } else {
      for (const r of results) {
        lines.push(`- **${r.entity}**${r.property ? `.${r.property}` : ''}: ${JSON.stringify(r.value)} [source: \`${r.source}\`]`);
      }
      lines.push('');
      lines.push(`*${results.length} result(s), ${plan.type} query*`);
    }

    return lines.join('\n');
  }

  // ── SE-328: dual-mode global / hybrid ────────────────────────────────────

  /**
   * Modo global: whole-dataset reasoning. Detección de comunidades + hubs.
   * Determinista, sin LLM, sin embeddings (SE-288).
   */
  async queryGlobal(): Promise<{ mode: 'global'; communities: import('./communities.js').Community[]; summary: string; outputMarkdown: string; outputRows: Record<string, unknown>[] }> {
    await this.graph.build();
    const detector = new CommunityDetector();
    const communities = detector.detect(this.graph.getSnapshot() ?? { nodes: new Map() });
    const summary = detector.summarize(communities);
    return {
      mode: 'global',
      communities,
      summary,
      outputMarkdown: summary,
      outputRows: communities.map(c => ({
        id: c.id,
        size: c.size,
        types: c.dominantTypes.join(', '),
        relations: c.dominantRelations.join(', '),
        hubs: c.memberIds.slice(0, 3).join(', '),
      })),
    };
  }

  /**
   * Modo hybrid: local (si la query referencia entidades) + global.
   */
  async queryHybrid(expr: string): Promise<{ mode: 'hybrid'; local: unknown; global: unknown; outputMarkdown: string; outputRows: Record<string, unknown>[] }> {
    const plan = this.parse(expr);
    const results = await this.execute(plan);
    const global = await this.queryGlobal();

    const lines: string[] = [];
    lines.push('## Query hybrid: local + global');
    lines.push('');
    lines.push('### Local');
    lines.push(this.formatMarkdown(plan, results));
    lines.push('### Global');
    lines.push(global.outputMarkdown);

    return {
      mode: 'hybrid',
      local: { plan, results },
      global: { communities: global.communities, summary: global.summary },
      outputMarkdown: lines.join('\n'),
      outputRows: [
        ...results.map(r => ({ mode: 'local', entity: r.entity, value: r.value })),
        ...global.outputRows.map(r => ({ mode: 'global', ...r })),
      ],
    };
  }
}
