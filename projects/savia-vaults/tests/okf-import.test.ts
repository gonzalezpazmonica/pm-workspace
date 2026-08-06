import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { VaultStorage } from '../src/storage/index.js';
import type { VaultConfig } from '../src/types.js';
import { importOkfBundle } from '../src/knowledge/okf-import.js';

function makeConfig(vaultPath: string): VaultConfig {
  return { name: 'test', path: vaultPath, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 10 * 1024 * 1024 };
}

function writeNote(dir: string, relPath: string, content: string) {
  const full = path.join(dir, relPath);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, content);
}

describe('OKF Import', () => {
  let tmpDir: string;
  let vaultPath: string;
  let sourceDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-okf-imp-'));
    vaultPath = path.join(tmpDir, 'vault');
    sourceDir = path.join(tmpDir, 'bundle');
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('imports an OKF bundle converting markdown links to wikilinks', async () => {
    writeNote(sourceDir, 'tables/orders.md', '---\ntype: BigQuery Table\ntitle: Orders\n---\n# Orders\nSee [customers](tables/customers.md).\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    const { imported } = await importOkfBundle(storage, { sourceDir });
    expect(imported).toBe(1);
    const note = await storage.read('tables/orders.md');
    expect(note.content).toContain('[[tables/customers|customers]]');
    expect(note.frontmatter.type).toBe('BigQuery Table');
  });

  it('rejects non-conformant notes when validateFirst', async () => {
    writeNote(sourceDir, 'notes/bad.md', '---\ntitle: No type\n---\n# Bad\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    const { imported, rejected } = await importOkfBundle(storage, { sourceDir });
    expect(imported).toBe(0);
    expect(rejected.length).toBeGreaterThan(0);
  });

  it('skips index.md and log.md', async () => {
    writeNote(sourceDir, 'sales/index.md', '---\ntype: Concept\n---\n# Index\n');
    writeNote(sourceDir, 'sales/orders.md', '---\ntype: Concept\n---\n# Orders\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    const { imported } = await importOkfBundle(storage, { sourceDir });
    expect(imported).toBe(1);
    await expect(storage.read('sales/index.md')).rejects.toThrow();
  });

  it('rejects overwriting existing notes without force', async () => {
    writeNote(sourceDir, 'notes/x.md', '---\ntype: Concept\n---\n# New\n');
    writeNote(vaultPath, 'notes/x.md', '---\ntype: Concept\n---\n# Old\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    const { imported, rejected } = await importOkfBundle(storage, { sourceDir });
    expect(imported).toBe(0);
    expect(rejected.some(r => r.includes('already exists'))).toBe(true);
  });

  it('overwrites existing notes with force', async () => {
    writeNote(sourceDir, 'notes/x.md', '---\ntype: Concept\n---\n# New\n');
    writeNote(vaultPath, 'notes/x.md', '---\ntype: Concept\n---\n# Old\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    const { imported } = await importOkfBundle(storage, { sourceDir, force: true });
    expect(imported).toBe(1);
    const note = await storage.read('notes/x.md');
    expect(note.content).toContain('# New');
  });

  it('honors stripPrefix', async () => {
    writeNote(sourceDir, 'sales/tables/orders.md', '---\ntype: Concept\n---\n# Orders\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    const { imported } = await importOkfBundle(storage, { sourceDir, stripPrefix: 'sales/' });
    expect(imported).toBe(1);
    await storage.read('tables/orders.md');
  });

  it('round-trip preserves the body content', async () => {
    const body = '## Schema\n\n| col | type |\n|-----|------|\n| id | STRING |\n\nFK to [[tables/customers|customers]].';
    writeNote(sourceDir, 'tables/orders.md', `---\ntype: BigQuery Table\n---\n${body}\n`);
    const storage = new VaultStorage(makeConfig(vaultPath));
    await importOkfBundle(storage, { sourceDir });

    const roundTripDir = path.join(tmpDir, 'roundtrip');
    const { exportOkfBundle } = await import('../src/knowledge/okf-export.js');
    const { exported } = await exportOkfBundle(storage, roundTripDir, { includeIndexFiles: false, includeLogFiles: false });
    expect(exported).toBe(1);

    const exportedContent = fs.readFileSync(path.join(roundTripDir, 'tables/orders.md'), 'utf-8');
    expect(exportedContent).toContain('| id | STRING |');
    expect(exportedContent).toContain('[customers](tables/customers.md)');
  });
});
