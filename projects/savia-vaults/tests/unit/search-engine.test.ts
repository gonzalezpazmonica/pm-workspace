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

// SE-412 — higiene de vault_search: solo markdown, tags reales, caché persistente para la CLI
describe('SearchEngine — SE-412', () => {
  let tmp: string;
  let cacheRoot: string;
  let config: VaultConfig;

  beforeEach(() => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-se412-'));
    cacheRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-se412-cache-'));
    config = { name: 'vault', path: tmp, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 1024 * 1024 };
    fs.writeFileSync(path.join(tmp, 'nota.md'), '# Nota\narquitectura hexagonal #arquitectura ver PR #648');
    fs.writeFileSync(path.join(tmp, 'datos.json'), '{"arquitectura": "hexagonal"}');
    fs.writeFileSync(path.join(tmp, 'llms.txt'), 'arquitectura hexagonal duplicada');
    fs.mkdirSync(path.join(tmp, 'node_modules', 'x'), { recursive: true });
    fs.writeFileSync(path.join(tmp, 'node_modules', 'x', 'README.md'), '# ruido arquitectura');
    fs.mkdirSync(path.join(tmp, '.oculto'));
    fs.writeFileSync(path.join(tmp, '.oculto', 'y.md'), '# oculto arquitectura');
  });

  afterEach(() => {
    fs.rmSync(tmp, { recursive: true, force: true });
    fs.rmSync(cacheRoot, { recursive: true, force: true });
  });

  it('AC1: solo indexa markdown visible fuera de node_modules', () => {
    const se = new SearchEngine(config);
    se.buildIndex();
    expect(se.search({ query: 'arquitectura', maxResults: 10 }).map(r => r.path)).toEqual(['nota.md']);
  });

  it('AC1: allowedExtensions de la cúpula manda sobre el default', () => {
    const se = new SearchEngine({ ...config, allowedExtensions: ['.txt'] });
    se.buildIndex();
    expect(se.search({ query: 'arquitectura', maxResults: 10 }).map(r => r.path)).toEqual(['llms.txt']);
  });

  it('AC2: #648 no es tag; #arquitectura sí', () => {
    const se = new SearchEngine(config);
    const tags = se.getTags();
    expect(tags.has('arquitectura')).toBe(true);
    expect(tags.has('648')).toBe(false);
  });

  it('AC3: la caché persistente evita releer el vault y se invalida con cambios', () => {
    const first = new SearchEngine(config, { cacheDir: cacheRoot });
    first.buildIndex();
    const files = fs.readdirSync(cacheRoot, { recursive: true }).map(String).filter(f => f.endsWith('.json'));
    expect(files).toHaveLength(1);

    // Mismo contenido indexado sin leer notas: se sustituye la nota en disco
    // conservando el mtime; si la caché se usa, el índice no ve el cambio.
    const p = path.join(tmp, 'nota.md');
    const st = fs.statSync(p);
    fs.writeFileSync(p, '# Nota\ncontenido distinto');
    fs.utimesSync(p, st.atime, st.mtime);
    const cached = new SearchEngine(config, { cacheDir: cacheRoot });
    cached.buildIndex();
    expect(cached.search({ query: 'hexagonal', maxResults: 5 }).map(r => r.path)).toEqual(['nota.md']);

    // Un fichero nuevo cambia el fingerprint: se reconstruye.
    fs.writeFileSync(path.join(tmp, 'nueva.md'), '# Nueva\nhexagonal también');
    const rebuilt = new SearchEngine(config, { cacheDir: cacheRoot });
    rebuilt.buildIndex();
    expect(rebuilt.search({ query: 'hexagonal', maxResults: 5 }).map(r => r.path)).toContain('nueva.md');
  });

  it('AC4: ficheros de caché 0600 y negativa dentro de un repo git', () => {
    new SearchEngine(config, { cacheDir: cacheRoot }).buildIndex();
    const f = fs.readdirSync(cacheRoot, { recursive: true }).map(String).find(x => x.endsWith('.json'))!;
    expect(fs.statSync(path.join(cacheRoot, f)).mode & 0o777).toBe(0o600);

    const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-se412-git-'));
    fs.mkdirSync(path.join(repo, '.git'));
    fs.writeFileSync(path.join(repo, '.git', 'HEAD'), 'ref: refs/heads/main\n');
    const se = new SearchEngine(config, { cacheDir: path.join(repo, 'cache') });
    expect(() => se.buildIndex()).not.toThrow(); // la caché es opcional: se indexa sin ella
    expect(fs.existsSync(path.join(repo, 'cache'))).toBe(false);
    expect(se.search({ query: 'arquitectura', maxResults: 5 }).length).toBe(1);
    fs.rmSync(repo, { recursive: true, force: true });
  });
});

describe('SearchEngine — SE-412 snippet sin contenido almacenado', () => {
  it('el snippet se lee del fichero y la caché no guarda el texto completo', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-se412-snip-'));
    const cache = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-se412-snipc-'));
    const cfg: VaultConfig = { name: 'v', path: tmp, allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 1e6 };
    const secret = 'frase-centinela-que-no-debe-duplicarse';
    fs.writeFileSync(path.join(tmp, 'n.md'), `---\ntitle: Nota\n---\n# Nota\nintroducción larga ${'relleno '.repeat(30)} copias de seguridad cifradas ${secret}`);
    const se = new SearchEngine(cfg, { cacheDir: cache });
    se.buildIndex();
    const [hit] = se.search({ query: 'cifradas', maxResults: 5 });
    expect(hit.snippet).toContain('cifradas');
    expect(hit.snippet).not.toContain('title: Nota');
    const idx = fs.readdirSync(cache, { recursive: true }).map(String).find(f => f.endsWith('.json'))!;
    expect(fs.readFileSync(path.join(cache, idx), 'utf-8')).not.toContain(secret);
    fs.rmSync(tmp, { recursive: true, force: true });
    fs.rmSync(cache, { recursive: true, force: true });
  });
});
