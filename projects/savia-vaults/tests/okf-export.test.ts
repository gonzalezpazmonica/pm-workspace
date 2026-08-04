import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { VaultStorage } from '../src/storage/index.js';
import type { VaultConfig } from '../src/types.js';
import { exportOkfBundle } from '../src/knowledge/okf-export.js';

function makeConfig(vaultPath: string): VaultConfig {
  return { name: 'test', path: vaultPath, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 10 * 1024 * 1024 };
}

function writeNote(dir: string, relPath: string, content: string) {
  const full = path.join(dir, relPath);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, content);
}

describe('OKF Export', () => {
  let tmpDir: string;
  let vaultPath: string;
  let outputDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-okf-exp-'));
    vaultPath = path.join(tmpDir, 'vault');
    outputDir = path.join(tmpDir, 'export');
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('exports a note with wikilinks converted to markdown links', async () => {
    writeNote(vaultPath, 'tables/orders.md', '---\ntype: BigQuery Table\n---\n# Orders\nSee [[tables/customers|customers]].\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    const { exported } = await exportOkfBundle(storage, outputDir, { includeIndexFiles: false, includeLogFiles: false });
    expect(exported).toBe(1);
    const exportedContent = fs.readFileSync(path.join(outputDir, 'tables/orders.md'), 'utf-8');
    expect(exportedContent).toContain('[customers](tables/customers.md)');
    expect(exportedContent).toContain('type: BigQuery Table');
  });

  it('infers type when missing and records the skip reason', async () => {
    writeNote(vaultPath, 'metrics/wau.md', '---\ntags: [metric]\n---\n# WAU\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    const { exported, skipped } = await exportOkfBundle(storage, outputDir, { includeIndexFiles: false, includeLogFiles: false });
    expect(exported).toBe(1);
    expect(skipped.some(s => s.includes('type inferido'))).toBe(true);
    const exportedContent = fs.readFileSync(path.join(outputDir, 'metrics/wau.md'), 'utf-8');
    expect(exportedContent).toContain('type: Metric');
  });

  it('uses modified timestamp for timestamp field', async () => {
    writeNote(vaultPath, 'notes/x.md', '---\ntype: Concept\n---\n# X\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    await exportOkfBundle(storage, outputDir, { includeIndexFiles: false, includeLogFiles: false });
    const exportedContent = fs.readFileSync(path.join(outputDir, 'notes/x.md'), 'utf-8');
    expect(exportedContent).toContain('timestamp:');
  });
});
