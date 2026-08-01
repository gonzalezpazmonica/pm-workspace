import { VaultStorage } from '../storage/index.js';
import { Introspector } from './introspector.js';
import { KnowledgeGraph } from './graph.js';
import { ProvenanceEngine } from './provenance.js';
import type { VaultConfig } from '../types.js';

export interface QualityIndicators {
  coverageByType: Record<string, { populated: number; total: number; pct: number }>;
  assertionsWithSource: { withSource: number; total: number; pct: number };
  authorityDistribution: Record<string, number>;
  expiredAssertions: number;
  openConflicts: number;
  orphanEntities: number;
  pendingRelations: number;
  freshnessByType: Record<string, { avgDays: number; count: number }>;
  computedAt: string;
}

export class QualityEngine {
  private storage: VaultStorage;
  private introspector: Introspector;
  private graph: KnowledgeGraph;
  private provenance: ProvenanceEngine;

  constructor(config: VaultConfig) {
    this.storage = new VaultStorage(config);
    this.introspector = new Introspector(config);
    this.graph = new KnowledgeGraph(config);
    this.provenance = new ProvenanceEngine(config);
  }

  async assess(): Promise<QualityIndicators> {
    const introspection = await this.introspector.introspectVault();
    const graphSnapshot = await this.graph.build();
    const files = await this.storage.list();

    // Coverage by type
    const coverageByType: Record<string, { populated: number; total: number; pct: number }> = {};
    for (const t of introspection.entityTypes) {
      const total = Object.keys(t.properties).length * t.count;
      const populated = Object.values(t.properties).reduce((sum, p) => sum + p.populated, 0);
      coverageByType[t.type] = {
        populated,
        total,
        pct: total > 0 ? Math.round((populated / total) * 100) : 0,
      };
    }

    // Assertions with source
    let withSource = 0;
    let totalAssertions = 0;
    const authorityDist: Record<string, number> = {};
    let expiredCount = 0;
    const freshnessByType: Record<string, { sum: number; count: number }> = {};

    for (const f of files.slice(0, 500)) {
      try {
        const assertions = await this.provenance.extractAssertions(f);
        totalAssertions += assertions.length;

        for (const a of assertions) {
          if (a.source && a.source !== f) withSource++;
          authorityDist[a.sourceType] = (authorityDist[a.sourceType] || 0) + 1;

          if (a.validUntil && new Date(a.validUntil) < new Date()) {
            expiredCount++;
          }

          const note = await this.storage.read(f);
          const entity = note.frontmatter.entity as Record<string, unknown> | undefined;
          const type = (entity?.type as string) || 'document';
          if (!freshnessByType[type]) freshnessByType[type] = { sum: 0, count: 0 };
          const age = (Date.now() - new Date(a.assertedAt).getTime()) / (1000 * 60 * 60 * 24);
          freshnessByType[type].sum += age;
          freshnessByType[type].count++;
        }
      } catch {}
    }

    // Conflicts
    let conflictCount = 0;
    for (const f of files.slice(0, 200)) {
      try {
        const assertions = await this.provenance.extractAssertions(f);
        const conflicts = this.provenance.findConflicts(f, assertions);
        conflictCount += conflicts.length;
      } catch {}
    }

    // Orphan entities and pending relations
    let orphanCount = 0;
    let pendingCount = 0;
    for (const [, node] of graphSnapshot.nodes) {
      if (node.outgoing.length === 0 && node.incoming.length === 0) orphanCount++;
      for (const rel of node.outgoing) {
        if (!graphSnapshot.nodes.has(rel.target)) pendingCount++;
      }
    }

    // Freshness
    const freshnessResult: Record<string, { avgDays: number; count: number }> = {};
    for (const [type, data] of Object.entries(freshnessByType)) {
      freshnessResult[type] = {
        avgDays: data.count > 0 ? Math.round(data.sum / data.count) : 0,
        count: data.count,
      };
    }

    return {
      coverageByType,
      assertionsWithSource: { withSource, total: totalAssertions, pct: totalAssertions > 0 ? Math.round((withSource / totalAssertions) * 100) : 0 },
      authorityDistribution: authorityDist,
      expiredAssertions: expiredCount,
      openConflicts: conflictCount,
      orphanEntities: orphanCount,
      pendingRelations: pendingCount,
      freshnessByType: freshnessResult,
      computedAt: new Date().toISOString(),
    };
  }

  formatReport(indicators: QualityIndicators): string {
    const lines: string[] = [];
    lines.push('# Vault Health Report');
    lines.push(`Computed: ${indicators.computedAt}`);
    lines.push('');

    lines.push('## Coverage by Entity Type');
    for (const [type, cov] of Object.entries(indicators.coverageByType)) {
      lines.push(`- **${type}**: ${cov.pct}% (${cov.populated}/${cov.total} populated)`);
    }
    lines.push('');

    lines.push('## Provenance');
    lines.push(`- Assertions with source: ${indicators.assertionsWithSource.pct}%`);
    lines.push('- Authority distribution:');
    for (const [level, count] of Object.entries(indicators.authorityDistribution)) {
      lines.push(`  - ${level}: ${count}`);
    }
    lines.push('');

    lines.push('## Health');
    lines.push(`- Expired assertions: ${indicators.expiredAssertions}`);
    lines.push(`- Open conflicts: ${indicators.openConflicts}`);
    lines.push(`- Orphan entities: ${indicators.orphanEntities}`);
    lines.push(`- Pending relations: ${indicators.pendingRelations}`);
    lines.push('');

    lines.push('## Freshness (avg days since assertion)');
    for (const [type, fresh] of Object.entries(indicators.freshnessByType)) {
      lines.push(`- ${type}: ${fresh.avgDays}d (${fresh.count} assertions)`);
    }

    return lines.join('\n');
  }
}
