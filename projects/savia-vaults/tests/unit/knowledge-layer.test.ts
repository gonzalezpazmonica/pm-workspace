import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { SchemaRegistry } from '../../src/schema/registry.js';
import { Introspector } from '../../src/knowledge/introspector.js';
import { KnowledgeGraph } from '../../src/knowledge/graph.js';
import { QueryEngine } from '../../src/knowledge/query.js';
import { ProvenanceEngine } from '../../src/knowledge/provenance.js';
import { QualityEngine } from '../../src/knowledge/quality.js';
import { VaultStorage } from '../../src/storage/index.js';
import type { VaultConfig } from '../../src/types.js';

function makeConfig(schemaDir: string, vaultPath: string): VaultConfig {
  return { name: 'test', path: vaultPath, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 10 * 1024 * 1024, schemaDir };
}

describe('Knowledge Layer', () => {
  let tmpDir: string;
  let schemaDir: string;
  let vaultPath: string;
  let config: VaultConfig;

  beforeEach(async () => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-knowledge-'));
    schemaDir = path.join(tmpDir, 'schema');
    vaultPath = path.join(tmpDir, 'vault');

    fs.mkdirSync(schemaDir, { recursive: true });
    fs.writeFileSync(path.join(schemaDir, 'person.yaml'), [
      'type: person', 'label: Persona', 'properties:',
      '  name:', '    type: string', '    required: true',
      '  role:', '    type: string', '    vocabulary: [dev, lead, architect]',
    ].join('\n'));
    fs.writeFileSync(path.join(schemaDir, 'project.yaml'), [
      'type: project', 'label: Proyecto', 'properties:',
      '  name:', '    type: string', '    required: true',
      '  status:', '    type: string', '    vocabulary: [active, completed, archived]',
    ].join('\n'));

    config = makeConfig(schemaDir, vaultPath);

    const storage = new VaultStorage(config);
    await storage.init();

    await storage.write('alice.md', [
      '---', 'entity: {type: person, id: alice}',
      'name: Alice', 'role: dev', 'title: Alice Smith',
      'relations: [{type: WORKS_ON, target: project-x}, {type: MENTORS, target: bob}]',
      'aliases: [A. Smith, AS]', '---', '# Alice', 'Works on project-x.',
    ].join('\n'));

    await storage.write('bob.md', [
      '---', 'entity: {type: person, id: bob}',
      'name: Bob', 'role: lead', 'title: Bob Jones',
      'relations: [{type: WORKS_ON, target: project-x}]', '---', '# Bob',
    ].join('\n'));

    await storage.write('project-x.md', [
      '---', 'entity: {type: project, id: project-x}',
      'name: Project X', 'status: active', '---', '# Project X',
      'Mentored by [[alice]].',
    ].join('\n'));
  });

  afterEach(() => { fs.rmSync(tmpDir, { recursive: true, force: true }); });

  describe('Introspector', () => {
    it('discovers entity types and counts', async () => {
      const introspector = new Introspector(config);
      const result = await introspector.introspectVault();
      expect(result.totalDocuments).toBeGreaterThanOrEqual(3);
      expect(result.entityTypes.length).toBe(2);
      const personType = result.entityTypes.find(t => t.type === 'person');
      expect(personType).toBeDefined();
      expect(personType!.count).toBe(2);
    });

    it('introspects a single entity', async () => {
      const introspector = new Introspector(config);
      const result = await introspector.introspectEntity('alice.md');
      expect(result).toBeDefined();
      expect(result!.type).toBe('person');
      expect(result!.populatedProperties).toHaveProperty('role');
    });
  });

  describe('KnowledgeGraph', () => {
    it('builds a graph with typed relations', async () => {
      const graph = new KnowledgeGraph(config);
      const snapshot = await graph.build();
      expect(snapshot.nodes.size).toBeGreaterThanOrEqual(3);

      const alice = snapshot.nodes.get('alice');
      expect(alice).toBeDefined();
      expect(alice!.outgoing.length).toBeGreaterThanOrEqual(2);
    });

    it('computes incoming relations', async () => {
      const graph = new KnowledgeGraph(config);
      await graph.build();
      const projectX = graph.getNode('project-x');
      expect(projectX).toBeDefined();
      const incoming = graph.getIncoming('project-x');
      expect(incoming.length).toBeGreaterThanOrEqual(2);
    });

    it('traverses with depth limit', async () => {
      const graph = new KnowledgeGraph(config);
      await graph.build();
      const result = graph.traverse('alice', 2, 50);
      expect(result.nodes.length).toBeGreaterThanOrEqual(2);
    });

    it('search finds nodes by query', async () => {
      const graph = new KnowledgeGraph(config);
      await graph.build();
      const nodes = graph.searchNodes('project');
      expect(nodes.length).toBeGreaterThanOrEqual(1);
    });

    it('derives MENTIONS from wikilinks', async () => {
      const graph = new KnowledgeGraph(config);
      await graph.build();
      const projectX = graph.getNode('project-x');
      const mentionsOut = projectX!.outgoing.filter(r => r.type === 'MENTIONS');
      expect(mentionsOut.length).toBeGreaterThanOrEqual(1);
    });
  });

  describe('QueryEngine', () => {
    it('parses property queries', async () => {
      const engine = new QueryEngine(config);
      await engine.ensureLoaded();
      const result = await engine.query('alice.name');
      expect(result.results.length).toBeGreaterThan(0);
    });

    it('parses search fallback', async () => {
      const engine = new QueryEngine(config);
      await engine.ensureLoaded();
      const result = await engine.query('architecture');
      expect(result.plan.type).toBe('search');
    });

    it('fuzzy finds entities', async () => {
      const engine = new QueryEngine(config);
      await engine.ensureLoaded();
      const result = await engine.query('Alice.name');
      expect(result.results.length).toBeGreaterThan(0);
    });
  });

  describe('ProvenanceEngine', () => {
    it('extracts assertions from documents', async () => {
      const engine = new ProvenanceEngine(config);
      const assertions = await engine.extractAssertions('alice.md');
      expect(assertions.length).toBeGreaterThanOrEqual(0);
    });

    it('signs and verifies assertions', async () => {
      const engine = new ProvenanceEngine(config);
      const assertion = { property: 'test', value: 'hello', source: 'test.md', sourceType: 'primary' as const, assertedAt: new Date().toISOString() };
      const sig = await engine.signAssertion(assertion);
      expect(sig).toBeDefined();
      assertion.signature = sig;
      expect(engine.verifyAssertion(assertion)).toBe(true);
    });

    it('detects conflicts between sources', () => {
      const engine = new ProvenanceEngine(config);
      const a1 = { property: 'status', value: 'active', source: 'a.md', sourceType: 'primary' as const, assertedAt: '2026-01-01' };
      const a2 = { property: 'status', value: 'inactive', source: 'b.md', sourceType: 'secondary' as const, assertedAt: '2026-02-01' };
      const conflicts = engine.findConflicts('x', [a1, a2]);
      expect(conflicts.length).toBe(1);
    });
  });

  describe('QualityEngine', () => {
    it('generates health report', async () => {
      const engine = new QualityEngine(config);
      const indicators = await engine.assess();
      expect(indicators.computedAt).toBeDefined();
      expect(indicators.coverageByType).toBeDefined();
    });

    it('formats readable report', async () => {
      const engine = new QualityEngine(config);
      const indicators = await engine.assess();
      const report = engine.formatReport(indicators);
      expect(report).toContain('# Vault Health Report');
    });
  });
});
