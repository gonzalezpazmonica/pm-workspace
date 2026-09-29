// SE-410 — integración del servicio RAG: fan-out, ACL, degradación, generaciones (AC3-AC9)
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import * as http from 'node:http';
import type { AddressInfo } from 'node:net';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { RagService, type RagDomeRef } from '../../../src/rag/service.js';
import { HashEmbedder, OllamaEmbedder, type Embedder } from '../../../src/rag/embedder.js';
import { readActive, FlatVectorStore } from '../../../src/rag/store.js';
import { RagError, type ResolvedRagConfig } from '../../../src/rag/types.js';

const long = (s: string) => `${s}. `.repeat(12);

function writeDome(root: string, name: string, docs: Record<string, string>): string {
  const dir = path.join(root, name);
  for (const [p, c] of Object.entries(docs)) {
    fs.mkdirSync(path.dirname(path.join(dir, p)), { recursive: true });
    fs.writeFileSync(path.join(dir, p), c);
  }
  return dir;
}

class CountingEmbedder extends HashEmbedder {
  queryCalls = 0;
  async embed(texts: string[], kind: 'query' | 'doc' = 'doc'): Promise<Float32Array[]> {
    if (kind === 'query') this.queryCalls++;
    return super.embed(texts);
  }
}

class SlowEmbedder extends HashEmbedder {
  async embed(texts: string[]): Promise<Float32Array[]> {
    await new Promise(r => setTimeout(r, 400));
    return super.embed(texts);
  }
}

class DeadEmbedder implements Embedder {
  async contract(): Promise<never> { throw new RagError('EMBEDDER_UNAVAILABLE', 'ollama caído'); }
  async embed(): Promise<never> { throw new RagError('EMBEDDER_UNAVAILABLE', 'ollama caído'); }
}

describe('RagService', () => {
  let root: string;
  let home: string;
  let domes: RagDomeRef[];
  const embedders = new Map<string, Embedder>();
  const factory = (cfg: ResolvedRagConfig): Embedder => {
    if (!embedders.has(cfg.model)) {
      embedders.set(cfg.model, cfg.model === 'slow' ? new SlowEmbedder(64, cfg, 'slow') : new CountingEmbedder(64, cfg, cfg.model));
    }
    return embedders.get(cfg.model)!;
  };

  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-rag-svc-'));
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-rag-svc-home-'));
    embedders.clear();
    domes = [
      { name: 'Docs', confidentiality: 'N2', path: writeDome(root, 'Docs', {
        'rules/merge.md': `# Merge\n\n${long('nunca merge sin permiso expreso de la operadora')}`,
        'rules/pat.md': `# PAT\n\n${long('el token PAT se lee desde fichero')}`,
        'rules/old.md': `---\nstatus: deprecated\n---\n# Old\n\n${long('merge sin permiso regla antigua')}`,
      }), rag: { enabled: true, model: 'm1' } },
      { name: 'Learn', confidentiality: 'N2', path: writeDome(root, 'Learn', {
        'l/merge-lesson.md': `# Lección\n\n${long('aprendimos que merge sin permiso rompe la confianza')}`,
      }), rag: { enabled: true, model: 'm2' } },
      { name: 'Secret', confidentiality: 'N4', path: writeDome(root, 'Secret', {
        's.md': `# Secreto\n\n${long('merge secreto de cliente')}`,
      }), rag: { enabled: true, model: 'm1' } },
      { name: 'Plain', confidentiality: 'N2', path: writeDome(root, 'Plain', { 'p.md': '# p\n\ntexto' }) },
    ];
  });
  afterEach(() => {
    fs.rmSync(root, { recursive: true, force: true });
    fs.rmSync(home, { recursive: true, force: true });
  });

  const service = (extra: Partial<ConstructorParameters<typeof RagService>[0]> = {}) =>
    new RagService({ domes: () => domes, home, embedderFactory: factory, ...extra });

  it('"*" expande a cúpulas habilitadas sin N4 y sincroniza inline la primera vez', async () => {
    const res = await service().search({ queries: ['merge sin permiso'], domes: '*' });
    expect(res.domes.map(d => d.name).sort()).toEqual(['Docs', 'Learn']);
    expect(res.domes.every(d => d.status === 'ok')).toBe(true);
    const paths = res.results[0].hits.map(h => `${h.dome}:${h.path}`);
    expect(paths).toContain('Docs:rules/merge.md');
    expect(paths).toContain('Learn:l/merge-lesson.md');
    expect(paths.some(p => p.startsWith('Secret'))).toBe(false);
  });

  it('N4 solo entra nombrada explícitamente', async () => {
    const res = await service().search({ queries: ['merge secreto'], domes: ['Secret'] });
    expect(res.domes[0]).toMatchObject({ name: 'Secret', status: 'ok' });
    expect(res.results[0].hits[0].confidentiality).toBe('N4');
  });

  it('cúpula sin bloque rag → not_indexed; desconocida → error', async () => {
    const res = await service().search({ queries: ['texto'], domes: ['Plain', 'Docs'] });
    expect(res.domes.find(d => d.name === 'Plain')?.status).toBe('not_indexed');
    await expect(service().search({ queries: ['x'], domes: ['Nope'] })).rejects.toMatchObject({ code: 'UNKNOWN_DOME' });
  });

  it('valida límites de entrada', async () => {
    const s = service();
    await expect(s.search({ queries: [] })).rejects.toMatchObject({ code: 'INVALID_INPUT' });
    await expect(s.search({ queries: Array(9).fill('q') })).rejects.toMatchObject({ code: 'INVALID_INPUT' });
    await expect(s.search({ queries: ['x'.repeat(1001)] })).rejects.toMatchObject({ code: 'INVALID_INPUT' });
    await expect(s.search({ queries: ['q'], k: 51 })).rejects.toMatchObject({ code: 'INVALID_INPUT' });
  });

  it('ACL: cúpula denegada figura denied con 0 hits (AC7)', async () => {
    const s = service({ authorize: async (dome) => { if (dome === 'Learn') throw new Error('sin permiso'); } });
    const res = await s.search({ queries: ['merge sin permiso'], domes: ['Docs', 'Learn'] });
    expect(res.domes.find(d => d.name === 'Learn')).toMatchObject({ status: 'denied' });
    expect(res.results[0].hits.some(h => h.dome === 'Learn')).toBe(false);
  });

  it('paralelo con timeout parcial y un embed de consultas por contrato (AC4, AC6)', async () => {
    domes.push({ name: 'Slow', confidentiality: 'N2', path: writeDome(root, 'Slow', { 'x.md': `# X\n\n${long('merge lento')}` }), rag: { enabled: true, model: 'slow' } });
    const s = service();
    const res = await s.search({ queries: ['merge sin permiso', 'token PAT', 'lección'], domes: ['Docs', 'Learn', 'Slow'], timeoutMs: 150 });
    expect(res.results).toHaveLength(3);
    expect(res.merged?.length).toBeGreaterThan(0);
    expect(res.domes.find(d => d.name === 'Slow')?.status).toBe('timeout');
    expect(res.domes.filter(d => d.status === 'ok').map(d => d.name).sort()).toEqual(['Docs', 'Learn']);
    expect((embedders.get('m1') as CountingEmbedder).queryCalls).toBe(1);
    expect((embedders.get('m2') as CountingEmbedder).queryCalls).toBe(1);
  });

  it('borrado desaparece en la siguiente búsqueda (AC3) y deprecado se excluye (AC5)', async () => {
    const s = service();
    await s.search({ queries: ['merge'], domes: ['Docs'] });
    fs.rmSync(path.join(domes[0].path, 'rules', 'merge.md'));
    const res = await s.search({ queries: ['merge sin permiso'], domes: ['Docs'] });
    expect(res.results[0].hits.some(h => h.path === 'rules/merge.md')).toBe(false);
    expect(res.results[0].hits.some(h => h.path === 'rules/old.md')).toBe(false);
    const stale = await s.search({ queries: ['merge sin permiso'], domes: ['Docs'], includeStale: true });
    expect(stale.results[0].hits.some(h => h.path === 'rules/old.md')).toBe(true);
  });

  it('más pendientes que el presupuesto → stale sin sync inline', async () => {
    domes[0].rag = { enabled: true, model: 'm1', inlineSyncBudget: 1 };
    const s = service();
    const res = await s.search({ queries: ['merge'], domes: ['Docs'] });
    expect(res.domes[0].status).toBe('not_indexed');
    await s.sync('Docs');
    for (const f of ['a.md', 'b.md']) fs.writeFileSync(path.join(domes[0].path, f), `# ${f}\n\n${long('nuevo')}`);
    const res2 = await s.search({ queries: ['merge'], domes: ['Docs'] });
    expect(res2.domes[0].status).toBe('stale');
    expect(res2.results[0].hits.length).toBeGreaterThan(0);
  });

  it('Ollama caído → BM25 degraded (AC8)', async () => {
    await service().sync('Docs');
    const dead = new RagService({ domes: () => domes, home, embedderFactory: () => new DeadEmbedder() });
    const res = await dead.search({ queries: ['token PAT fichero'], domes: ['Docs'] });
    expect(res.domes[0].status).toBe('degraded');
    expect(res.domes[0].detail).toMatch(/EMBEDDER_UNAVAILABLE/);
    expect(res.results[0].hits[0].path).toBe('rules/pat.md');
    expect(res.results[0].hits[0].signals.denseRank).toBeUndefined();
  });

  it('generación sombra: gate con banco de eval, promote --force y rollback (AC9)', async () => {
    fs.writeFileSync(path.join(domes[0].path, 'eval.json'), JSON.stringify([
      { query: 'merge sin permiso operadora', relevantPaths: ['rules/merge.md'] },
      { query: 'token PAT fichero', relevantPaths: ['rules/pat.md'] },
    ]));
    domes[0].rag = { enabled: true, model: 'm1', evalSet: 'eval.json' };
    const s = service();
    const first = await s.sync('Docs');
    expect(first.promoted).toBe(true);

    // P4: el modelo de la activa ya no está disponible (el servicio "bad" no puede
    // embeber con él) ⇒ el gate compara contra la línea base registrada al activarla.
    const ptr = readActive(home, 'Docs');
    expect(ptr.metrics?.[first.generation]).toBeDefined();
    fs.writeFileSync(path.join(home, 'Docs', 'active.json'), JSON.stringify({
      ...ptr, metrics: { [first.generation]: { recallAt10: 1, mrr: 1, at: 'x' } },
    }));
    fs.writeFileSync(path.join(domes[0].path, 'eval.json'), JSON.stringify([
      { query: 'merge sin permiso operadora', relevantPaths: ['rules/merge.md'] },
      { query: 'zzzz qqqq', relevantPaths: ['rules/pat.md'] },
    ]));
    const bad = new RagService({ domes: () => domes, home, embedderFactory: (cfg) => new HashEmbedder(64, cfg, 'bad') });
    domes[0].rag = { enabled: true, model: 'bad', evalSet: 'eval.json' };
    const shadow = await bad.sync('Docs');
    expect(shadow.shadow).toBe(true);
    expect(shadow.promoted).toBe(false);
    expect(shadow.gate?.promote).toBe(false);
    expect(shadow.gate?.reason).toMatch(/recall@10|MRR/);
    expect(readActive(home, 'Docs').active).toBe(first.generation);

    await expect(bad.promote('Docs', shadow.generation)).rejects.toMatchObject({ code: 'PROMOTION_REJECTED' });
    await bad.promote('Docs', shadow.generation, true);
    expect(readActive(home, 'Docs')).toMatchObject({ active: shadow.generation, previous: first.generation });

    await bad.rollback('Docs');
    expect(readActive(home, 'Docs')).toMatchObject({ active: first.generation, previous: shadow.generation });
    domes[0].rag = { enabled: true, model: 'm1', evalSet: 'eval.json' };
    const res = await s.search({ queries: ['token PAT'], domes: ['Docs'] });
    expect(res.domes[0].generation).toBe(first.generation);
  });

  it('status y check de SLO (P7)', async () => {
    const s = service();
    let st = await s.status(['Docs']);
    expect(st[0].slo.ok).toBe(false);
    await s.sync('Docs');
    st = await s.status(['Docs']);
    expect(st[0]).toMatchObject({ enabled: true, pendingDocs: 0, staleRatio: 0 });
    expect(st[0].slo.ok).toBe(true);
    expect(st[0].chunks).toBeGreaterThan(0);
  });

  it('eval devuelve recall@k, MRR y latencias', async () => {
    const s = service();
    await s.sync('Docs');
    const r = await s.evaluate('Docs', [{ query: 'token PAT fichero', relevantPaths: ['rules/pat.md'] }], { mode: 'hybrid' });
    expect(r.mrr).toBe(1);
    expect(r.recallAt10).toBe(1);
    expect(r.p95Ms).toBeGreaterThanOrEqual(0);
  });

  it('gc conserva activa, anterior y sombra', async () => {
    const s = service();
    await s.sync('Docs');
    fs.mkdirSync(path.join(home, 'Docs', 'deadbeef0000'), { recursive: true });
    expect(await s.gc('Docs')).toBeGreaterThanOrEqual(1);
    expect(fs.existsSync(path.join(home, 'Docs', 'deadbeef0000'))).toBe(false);
    expect(fs.existsSync(path.join(home, 'Docs', readActive(home, 'Docs').active!))).toBe(true);
  });

  it('búsqueda concurrente con sync ve un snapshot completo', async () => {
    const s = service();
    await s.sync('Docs');
    fs.writeFileSync(path.join(domes[0].path, 'rules', 'nuevo.md'), `# Nuevo\n\n${long('contenido nuevo')}`);
    const [a] = await Promise.all([s.search({ queries: ['token PAT'], domes: ['Docs'] }), s.sync('Docs').catch(() => undefined)]);
    expect(['ok', 'stale']).toContain(a.domes[0].status);
    expect(a.results[0].hits.length).toBeGreaterThan(0);
  });

  // ── SE-411 ────────────────────────────────────────────────────────────
  it('G1: la fusión entre cúpulas no depende del orden de la lista (AC1)', async () => {
    for (const d of domes) d.rag = { enabled: true, model: 'm1' };
    const s = service();
    const q = { queries: ['merge sin permiso de la operadora'], k: 6 };
    const a = await s.search({ ...q, domes: ['Docs', 'Learn', 'Secret'] });
    const b = await s.search({ ...q, domes: ['Secret', 'Learn', 'Docs'] });
    const c = await s.search({ ...q, domes: ['Learn', 'Docs', 'Secret'] });
    const ids = (r: typeof a) => r.results[0].hits.map(h => `${h.dome}:${h.chunkId}`);
    expect(ids(b)).toEqual(ids(a));
    expect(ids(c)).toEqual(ids(a));
    expect(a.fusion).toBe('cosine');
    // orden por coseno descendente
    const cos = a.results[0].hits.map(h => h.signals.dense!);
    expect([...cos].sort((x, y) => y - x)).toEqual(cos);
  });

  it('G1: con contratos distintos la fusión es por rango pero sigue siendo determinista', async () => {
    const s = service();
    const a = await s.search({ queries: ['merge sin permiso'], domes: ['Docs', 'Learn'] });
    const b = await s.search({ queries: ['merge sin permiso'], domes: ['Learn', 'Docs'] });
    expect(a.fusion).toBe('rank');
    expect(b.results[0].hits.map(h => `${h.dome}:${h.chunkId}`)).toEqual(a.results[0].hits.map(h => `${h.dome}:${h.chunkId}`));
  });

  it('G2: con 5 cúpulas no se recarga ningún índice en caliente (AC2)', async () => {
    for (const n of ['E1', 'E2']) domes.push({ name: n, confidentiality: 'N2', path: writeDome(root, n, { 'x.md': `# ${n}\n\n${long('contenido extra de prueba')}` }), rag: { enabled: true, model: 'm1' } });
    for (const d of domes) if (d.name !== 'Plain') d.rag = { enabled: true, model: 'm1' };
    const s = service();
    await s.search({ queries: ['merge'], domes: '*' });
    const spy = vi.spyOn(FlatVectorStore, 'load');
    await s.search({ queries: ['merge'], domes: '*' });
    await s.search({ queries: ['token'], domes: '*' });
    expect(spy).not.toHaveBeenCalled();
    spy.mockRestore();
  });

  it('G2: el presupuesto de memoria desaloja el índice menos usado', async () => {
    for (const d of domes) if (d.name !== 'Plain') d.rag = { enabled: true, model: 'm1' };
    const s = service({ env: { SAVIA_RAG_MEMORY_MB: '0' } });
    await s.search({ queries: ['merge'], domes: ['Docs'] });
    await s.search({ queries: ['merge'], domes: ['Learn'] });
    const spy = vi.spyOn(FlatVectorStore, 'load');
    await s.search({ queries: ['merge'], domes: ['Docs'] });
    expect(spy).toHaveBeenCalledTimes(1);
    spy.mockRestore();
  });

  it('G5: una búsqueda hace un solo embedding (sin sondeo de dimensiones)', async () => {
    const calls: string[] = [];
    const server = http.createServer((req, res) => {
      let data = '';
      req.on('data', (c) => { data += c; });
      req.on('end', () => {
        calls.push(req.url || '');
        res.setHeader('content-type', 'application/json');
        if (req.url === '/api/tags') return res.end(JSON.stringify({ models: [{ name: 'fake:latest', digest: 'd1' }] }));
        const input: string[] = JSON.parse(data).input;
        res.end(JSON.stringify({ embeddings: input.map(t => [t.length % 7, (t.length % 5) + 1, 1]) }));
      });
    });
    await new Promise<void>(r => server.listen(0, '127.0.0.1', () => r()));
    const url = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    try {
      domes[0].rag = { enabled: true, model: 'fake' };
      await new RagService({ domes: () => domes, home, embedderFactory: (cfg) => new OllamaEmbedder({ baseUrl: url, model: cfg.model }) }).sync('Docs');
      const fresh = new RagService({ domes: () => domes, home, embedderFactory: (cfg) => new OllamaEmbedder({ baseUrl: url, model: cfg.model }) });
      calls.length = 0;
      const r = await fresh.search({ queries: ['merge sin permiso', 'token'], domes: ['Docs'] });
      expect(r.domes[0].status).toBe('ok');
      expect(calls.filter(c => c === '/api/embed')).toHaveLength(1);
    } finally {
      await new Promise<void>(r => server.close(() => r()));
    }
  });
});
