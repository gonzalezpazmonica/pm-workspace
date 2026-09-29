// SE-410 S1 — almacén flat por generación
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  FlatVectorStore, generationId, ensureSafeHome, readActive, writeActive, gcGeneration, domeDir,
} from '../../../src/rag/store.js';
import { HashEmbedder } from '../../../src/rag/embedder.js';
import type { Chunk, Manifest } from '../../../src/rag/types.js';

function chunk(p: string, ordinal: number, text: string): Chunk {
  return { id: `${p}#${ordinal}`, path: p, ordinal, heading: 'T', text, embedText: `T\n\n${text}`, hash: `h-${p}-${ordinal}`, meta: { title: 'T', modified: '2026-09-01' } };
}

describe('FlatVectorStore', () => {
  let home: string;
  beforeEach(() => { home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-rag-store-')); });
  afterEach(() => { fs.rmSync(home, { recursive: true, force: true }); });

  async function build(seq = 1) {
    const e = new HashEmbedder(32);
    const contract = await e.contract();
    const gen = generationId(contract);
    const chunks = [chunk('a.md', 0, 'merge sin permiso expreso'), chunk('b.md', 0, 'receta de tortilla')];
    const vectors = await e.embed(chunks.map(c => c.embedText), 'doc');
    const manifest: Manifest = {
      version: 1, dome: 'D', generation: gen, contract, seq, createdAt: 'x', updatedAt: 'x',
      docs: { 'a.md': { hash: 'ha', mtimeMs: 1, chunkIds: ['a.md#0'] }, 'b.md': { hash: 'hb', mtimeMs: 1, chunkIds: ['b.md#0'] } },
      chunkCount: 2, fingerprint: 'f',
    };
    const dir = path.join(domeDir(home, 'D'), gen);
    FlatVectorStore.write(dir, manifest, chunks, vectors);
    return { e, contract, gen, dir };
  }

  it('generationId es estable e independiente del orden de claves', async () => {
    const c = await new HashEmbedder(32).contract();
    const reordered = Object.fromEntries(Object.entries(c).reverse()) as typeof c;
    expect(generationId(c)).toBe(generationId(reordered));
    expect(generationId(c)).toHaveLength(12);
    expect(generationId({ ...c, modelDigest: 'otro' })).not.toBe(generationId(c));
  });

  it('round-trip y topK por coseno', async () => {
    const { e, contract, dir } = await build();
    const store = FlatVectorStore.load(dir, contract);
    expect(store.size).toBe(2);
    const [q] = await e.embed(['merge permiso'], 'query');
    const top = store.topK(q, 1);
    expect(store.chunks[top[0].index].path).toBe('a.md');
  });

  it('contrato distinto → CONTRACT_MISMATCH (AC4)', async () => {
    const { contract, dir } = await build();
    expect(() => FlatVectorStore.load(dir, { ...contract, model: 'otro' })).toThrow(/CONTRACT_MISMATCH/);
  });

  it('vectores truncados → CORRUPT_INDEX', async () => {
    const { contract, dir } = await build();
    const vf = fs.readdirSync(dir).find(f => f.endsWith('.f32'))!;
    fs.truncateSync(path.join(dir, vf), 10);
    expect(() => FlatVectorStore.load(dir, contract)).toThrow(/CORRUPT_INDEX/);
  });

  it('ficheros 0600 y directorios 0700 (AC11)', async () => {
    const { dir } = await build();
    for (const f of fs.readdirSync(dir)) {
      expect(fs.statSync(path.join(dir, f)).mode & 0o777).toBe(0o600);
    }
    expect(fs.statSync(dir).mode & 0o777).toBe(0o700);
  });

  it('una escritura nueva no pisa el snapshot anterior hasta el rename del manifest', async () => {
    const { contract, dir } = await build(1);
    const reader = FlatVectorStore.load(dir, contract);
    await build(2);
    expect(reader.size).toBe(2);
    const files = fs.readdirSync(dir);
    expect(files.some(f => f === 'vectors-1.f32')).toBe(true);
    expect(files.some(f => f === 'vectors-2.f32')).toBe(true);
    expect(FlatVectorStore.readManifest(dir)!.seq).toBe(2);
  });

  it('gc borra seq no referenciados pasado el periodo de gracia', async () => {
    const { dir } = await build(1);
    await build(2);
    expect(gcGeneration(dir, 60_000)).toBe(0);
    expect(gcGeneration(dir, 0)).toBe(2);
    expect(fs.existsSync(path.join(dir, 'vectors-1.f32'))).toBe(false);
    expect(fs.existsSync(path.join(dir, 'vectors-2.f32'))).toBe(true);
  });

  it('puntero active/previous atómico', () => {
    writeActive(home, 'D', { active: 'g2', previous: 'g1' });
    expect(readActive(home, 'D')).toMatchObject({ active: 'g2', previous: 'g1' });
    expect(readActive(home, 'otra')).toEqual({ updatedAt: '' });
  });
});

describe('ensureSafeHome', () => {
  it('se niega dentro de un repo git (AC11)', () => {
    const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-rag-git-'));
    fs.mkdirSync(path.join(repo, '.git')); fs.writeFileSync(path.join(repo, '.git', 'HEAD'), 'ref: refs/heads/main\n');
    expect(() => ensureSafeHome(path.join(repo, 'sub', 'rag'))).toThrow(/UNSAFE_HOME/);
    fs.rmSync(repo, { recursive: true, force: true });
  });

  it('crea el home con 0700 fuera de git', () => {
    const base = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-rag-home-'));
    const h = path.join(base, 'rag');
    ensureSafeHome(h);
    expect(fs.statSync(h).mode & 0o777).toBe(0o700);
    fs.rmSync(base, { recursive: true, force: true });
  });
});
