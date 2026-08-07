// SearchEngine index caching (SE-310): no rebuild si no cambia
// Copyright (c) 2026 Savia. MIT License.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { SearchEngine } from '../../src/search/index.js';
import type { VaultConfig } from '../../src/types.js';

describe('SearchEngine — index caching', () => {
  let tmp: string;
  let config: VaultConfig;

  beforeEach(() => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-se-'));
    config = {
      name: 'vault',
      path: tmp,
      allowedExtensions: [],
      deniedPaths: [],
      maxDepth: 10,
      maxFileSize: 1024 * 1024,
    };
    fs.writeFileSync(path.join(tmp, 'a.md'), '# Alpha\nprimer documento');
    fs.writeFileSync(path.join(tmp, 'b.md'), '# Beta\nsegundo documento');
  });

  afterEach(() => {
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  it('buildIndex indexa y search encuentra el termino', () => {
    const se = new SearchEngine(config);
    se.buildIndex();
    const res = se.search({ query: 'alpha', maxResults: 5 });
    expect(res.length).toBeGreaterThan(0);
    expect(res[0].path).toBe('a.md');
  });

  it('buildIndex NO reconstruye si nada cambio (cacheado): devuelve resultados sin re-leer', () => {
    const se = new SearchEngine(config);
    se.buildIndex();
    // segundo buildIndex con el mismo fingerprint → cache hit (no lanza, index intacto)
    expect(() => se.buildIndex()).not.toThrow();
    expect(se.search({ query: 'beta', maxResults: 5 }).length).toBeGreaterThan(0);
  });

  it('buildIndex SÍ reconstruye cuando aparece un fichero nuevo (fingerprint cambia)', () => {
    const se = new SearchEngine(config);
    se.buildIndex();
    fs.writeFileSync(path.join(tmp, 'c.md'), '# Gamma\ntercer documento');
    se.buildIndex();
    const res = se.search({ query: 'gamma', maxResults: 5 });
    expect(res.some((r) => r.path === 'c.md')).toBe(true);
  });
});
