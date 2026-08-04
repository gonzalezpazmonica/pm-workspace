import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { VaultStorage } from '../src/storage/index.js';
import type { VaultConfig } from '../src/types.js';
import { checkOkfConformance } from '../src/knowledge/okf-conformance.js';

function makeConfig(vaultPath: string): VaultConfig {
  return { name: 'test', path: vaultPath, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 10 * 1024 * 1024 };
}

function writeNote(dir: string, relPath: string, content: string) {
  const full = path.join(dir, relPath);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, content);
}

describe('OKF Conformance', () => {
  let tmpDir: string;
  let vaultPath: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-okf-conf-'));
    vaultPath = path.join(tmpDir, 'vault');
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('reports conformant for a vault with type fields', async () => {
    writeNote(vaultPath, 'tables/orders.md', '---\ntype: BigQuery Table\ntitle: Orders\n---\n# Orders\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    const report = await checkOkfConformance(storage);
    expect(report.conformant).toBe(true);
    expect(report.noteCount).toBe(1);
  });

  it('reports violations for notes missing type', async () => {
    writeNote(vaultPath, 'notes/foo.md', '---\ntitle: Foo\n---\n# Foo\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    const report = await checkOkfConformance(storage);
    expect(report.conformant).toBe(false);
    expect(report.violations.length).toBeGreaterThan(0);
  });

  it('exempts index.md and log.md files', async () => {
    writeNote(vaultPath, 'sales/index.md', '---\ntitle: Sales Index\n---\n# Sales\n');
    writeNote(vaultPath, 'sales/log.md', '---\ntitle: Changelog\n---\n# Log\n');
    const storage = new VaultStorage(makeConfig(vaultPath));
    const report = await checkOkfConformance(storage);
    expect(report.conformant).toBe(true);
  });
});
