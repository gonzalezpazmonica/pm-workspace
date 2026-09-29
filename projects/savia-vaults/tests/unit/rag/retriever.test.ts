// SE-410 S2 — retriever híbrido, RRF, frescura y presupuesto de caracteres
import { describe, it, expect, beforeAll } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { rrf, searchStore, fuseAcross, applyCharBudget, processTerm } from '../../../src/rag/retriever.js';
import { HashEmbedder } from '../../../src/rag/embedder.js';
import { FlatVectorStore, generationId } from '../../../src/rag/store.js';
import { chunkMarkdown } from '../../../src/rag/chunker.js';
import { RAG_DEFAULTS, type Chunk, type Manifest, type RagHit } from '../../../src/rag/types.js';

const e = new HashEmbedder(128);
const cfg = { ...RAG_DEFAULTS, enabled: true };
const long = (s: string) => `${s} `.repeat(15);

let store: FlatVectorStore;

beforeAll(async () => {
  const docs: Record<string, string> = {
    'rules/merge.md': `# Merge\n\n## Permiso\n${long('nunca merge sin permiso expreso de la operadora')}\n\n## Ramas\n${long('rama agent para cada cambio autonomo')}\n\n## Otra\n${long('merge merge merge permiso otra seccion')}`,
    'rules/pat.md': `# PAT\n\n${long('el token PAT se lee siempre desde fichero nunca hardcodeado')}`,
    'rules/old.md': `---\nstatus: deprecated\nsuperseded_by: rules/merge.md\n---\n# Vieja\n\n${long('merge sin permiso antigua regla')}`,
    'labs/exp.md': `---\nsuperseded_by: labs/exp2.md\n---\n# Exp\n\n${long('experimento de recuperacion hibrida')}`,
  };
  const chunks: Chunk[] = [];
  for (const [p, raw] of Object.entries(docs)) chunks.push(...chunkMarkdown(p, raw, { chunkChars: 300, overlap: 0.1 }));
  const contract = await e.contract();
  const manifest: Manifest = {
    version: 1, dome: 'D', generation: generationId(contract), contract, seq: 1, createdAt: '', updatedAt: '',
    docs: {}, chunkCount: chunks.length, fingerprint: '',
  };
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-rag-ret-'));
  FlatVectorStore.write(dir, manifest, chunks, await e.embed(chunks.map(c => c.embedText), 'doc'));
  store = FlatVectorStore.load(dir, contract);
});

describe('rrf', () => {
  it('suma 1/(k+rank) y premia aparecer en ambas listas', () => {
    const s = rrf([['a', 'b', 'c'], ['b', 'a', 'd']], 60);
    expect(s.get('a')).toBeCloseTo(1 / 61 + 1 / 62);
    expect([...s.entries()].sort((x, y) => y[1] - x[1]).slice(0, 2).map(x => x[0]).sort()).toEqual(['a', 'b']);
    expect(s.get('d')).toBeCloseTo(1 / 63);
  });
});

describe('processTerm (higiene BM25)', () => {
  it('descarta stopwords es/en y pliega acentos', () => {
    expect(processTerm('de')).toBeNull();
    expect(processTerm('The')).toBeNull();
    expect(processTerm('Política')).toBe('politica');
    expect(processTerm('SPEC')).toBe('spec');
  });
});

describe('searchStore', () => {
  const run = async (query: string, extra: Partial<Parameters<typeof searchStore>[0]> = {}) => {
    const [q] = await e.embed([query], 'query');
    return searchStore({ store, query, queryVec: q, mode: 'hybrid', k: 5, cfg, ...extra });
  };

  it('híbrido recupera el documento correcto primero', async () => {
    const hits = await run('merge permiso operadora');
    expect(hits[0].path).toBe('rules/merge.md');
    expect(hits[0].signals.bm25Rank).toBeDefined();
    expect(hits[0].signals.denseRank).toBeDefined();
  });

  it('excluye deprecados salvo includeStale (AC5)', async () => {
    expect((await run('merge sin permiso antigua')).some(h => h.path === 'rules/old.md')).toBe(false);
    expect((await run('merge sin permiso antigua', { includeStale: true })).some(h => h.path === 'rules/old.md')).toBe(true);
  });

  it('anota superseded_by sin excluir si el status no está en la lista', async () => {
    const hit = (await run('experimento recuperacion hibrida')).find(h => h.path === 'labs/exp.md');
    expect(hit?.freshness.supersededBy).toBe('labs/exp2.md');
  });

  it('máximo 2 chunks por documento', async () => {
    const hits = await run('merge permiso', { k: 10 });
    expect(hits.filter(h => h.path === 'rules/merge.md').length).toBeLessThanOrEqual(2);
  });

  it('modos bm25 y dense usan una sola señal', async () => {
    const b = await run('token PAT fichero', { mode: 'bm25' });
    expect(b[0].path).toBe('rules/pat.md');
    expect(b[0].signals.denseRank).toBeUndefined();
    const d = await run('token PAT fichero', { mode: 'dense' });
    expect(d[0].signals.bm25Rank).toBeUndefined();
  });

  it('stopwords de la consulta no arrastran documentos (prefijo solo ≥ 4)', async () => {
    const b = await run('de la que el en', { mode: 'bm25' });
    expect(b).toHaveLength(0);
  });

  it('pathPrefix filtra', async () => {
    const hits = await run('merge experimento', { pathPrefix: 'labs/' });
    expect(hits.every(h => h.path.startsWith('labs/'))).toBe(true);
  });

  it('decaimiento reduce el score con halfLifeDays', async () => {
    const base = await run('token PAT fichero');
    const decayed = await run('token PAT fichero', { cfg: { ...cfg, halfLifeDays: 1 } });
    expect(decayed[0].score).toBeLessThan(base[0].score);
    expect(decayed[0].freshness.decay).toBeLessThan(1);
  });
});

describe('fuseAcross y presupuesto', () => {
  const hit = (dome: string, p: string, text = 'x'): RagHit => ({
    dome, confidentiality: 'N2', path: p, heading: 'h', text, score: 0, signals: {}, generation: 'g',
    freshness: { modified: '', decay: 1 }, chunkId: `${p}#0`,
  });

  it('fusiona por rango entre cúpulas, no por score', () => {
    const a = [{ ...hit('A', 'a1'), score: 100 }, { ...hit('A', 'a2'), score: 99 }];
    const b = [{ ...hit('B', 'b1'), score: 0.001 }];
    const merged = fuseAcross([a, b], 3);
    expect(merged.slice(0, 2).map(h => h.path).sort()).toEqual(['a1', 'b1']);
  });

  it('recorta texto sin omitir hits', () => {
    const hits = [hit('A', 'a', 'y'.repeat(5000)), hit('A', 'b', 'z'.repeat(5000))];
    const out = applyCharBudget(hits, 2000);
    expect(out).toHaveLength(2);
    expect(out.reduce((s, h) => s + h.text.length, 0)).toBeLessThanOrEqual(2002);
  });
});
