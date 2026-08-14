import { describe, it, expect } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { QueryEngine } from '../src/knowledge/query.js';
import { VaultStorage } from '../src/storage/index.js';
import type { VaultConfig } from '../src/types.js';

function makeConfig(schemaDir: string, vaultPath: string): VaultConfig {
  return { name: 'test', path: vaultPath, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 10 * 1024 * 1024, schemaDir };
}

describe('SE-328 QueryEngine global/hybrid mode', () => {
  let tmpDir: string;
  let config: VaultConfig;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-query-global-'));
    const schemaDir = path.join(tmpDir, 'schema');
    const vaultPath = path.join(tmpDir, 'vault');
    fs.mkdirSync(schemaDir, { recursive: true });
    fs.mkdirSync(vaultPath, { recursive: true });
    fs.writeFileSync(path.join(schemaDir, 'person.yaml'), 'type: person\nlabel: Persona\nproperties:\n  name: {type: string, required: true}\n');
    fs.writeFileSync(path.join(schemaDir, 'document.yaml'), 'type: document\nlabel: Documento\nproperties:\n  title: {type: string, required: true}\n');

    // dos componentes desconectados
    fs.writeFileSync(path.join(vaultPath, 'a.md'), [
      '---',
      'entity: {type: person, id: alice}',
      'relations:',
      '  - {type: CITES, target: doc-b}',
      '---',
      'Nota de alice',
    ].join('\n'));
    fs.writeFileSync(path.join(vaultPath, 'b.md'), [
      '---',
      'entity: {type: document, id: doc-b}',
      '---',
      'Documento b',
    ].join('\n'));
    fs.writeFileSync(path.join(vaultPath, 'x.md'), [
      '---',
      'entity: {type: document, id: doc-x}',
      '---',
      'Documento x aislado',
    ].join('\n'));

    config = makeConfig(schemaDir, vaultPath);
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('AC: queryGlobal detecta 2 comunidades y devuelve summary', async () => {
    const engine = new QueryEngine(config);
    await engine.ensureLoaded();
    const result = await engine.queryGlobal();
    expect(result.communities.length).toBe(2);
    expect(result.summary).toContain('C1');
  });

  it('AC: queryGlobal markdown consumible', async () => {
    const engine = new QueryEngine(config);
    await engine.ensureLoaded();
    const result = await engine.queryGlobal();
    expect(result.outputMarkdown).toContain('Comunidades del vault');
    expect(result.outputRows.length).toBeGreaterThanOrEqual(2);
  });

  it('AC: queryHybrid incluye bloques local y global', async () => {
    const engine = new QueryEngine(config);
    await engine.ensureLoaded();
    const result = await engine.queryHybrid('alice');
    expect(result.local).toBeDefined();
    expect(result.global).toBeDefined();
    expect(result.outputMarkdown).toContain('local');
    expect(result.outputMarkdown).toContain('global');
  });

  it('AC: queryGlobal en vault vacío no lanza', async () => {
    const emptyTmp = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-empty-'));
    const cfg = makeConfig(path.join(emptyTmp, 'schema'), path.join(emptyTmp, 'vault'));
    fs.mkdirSync(cfg.schemaDir, { recursive: true });
    fs.mkdirSync(cfg.path, { recursive: true });
    const engine = new QueryEngine(cfg);
    await engine.ensureLoaded();
    const result = await engine.queryGlobal();
    expect(result.communities.length).toBe(0);
  });
});
