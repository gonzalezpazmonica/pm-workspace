// SE-410 S1 — indexer incremental (AC2, AC3) y lock entre procesos
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { RagIndexer, listIndexable, acquireLock, releaseLock } from '../../../src/rag/indexer.js';
import { HashEmbedder } from '../../../src/rag/embedder.js';
import { FlatVectorStore, readActive, domeDir } from '../../../src/rag/store.js';
import { RAG_DEFAULTS } from '../../../src/rag/types.js';

const body = (topic: string) => `# ${topic}\n\n## Uno\n${`${topic} contenido relevante sobre el tema. `.repeat(12)}\n\n## Dos\n${`más detalle de ${topic}. `.repeat(12)}`;

describe('RagIndexer', () => {
  let vault: string;
  let home: string;
  const cfg = { ...RAG_DEFAULTS, enabled: true };

  beforeEach(() => {
    vault = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-rag-vault-'));
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-rag-home-'));
    fs.mkdirSync(path.join(vault, 'rules'));
    fs.writeFileSync(path.join(vault, 'rules', 'merge.md'), body('merge'));
    fs.writeFileSync(path.join(vault, 'rules', 'pat.md'), body('pat'));
    fs.writeFileSync(path.join(vault, 'notes.txt'), 'no indexable');
    fs.mkdirSync(path.join(vault, 'node_modules', 'x'), { recursive: true });
    fs.writeFileSync(path.join(vault, 'node_modules', 'x', 'README.md'), '# ruido');
    fs.mkdirSync(path.join(vault, '.trash'));
    fs.writeFileSync(path.join(vault, '.trash', 'old.md'), '# borrado');
  });
  afterEach(() => {
    fs.rmSync(vault, { recursive: true, force: true });
    fs.rmSync(home, { recursive: true, force: true });
  });

  const indexer = () => new RagIndexer({ dome: 'D', vaultPath: vault, home, cfg, embedder: new HashEmbedder(64) });

  it('solo indexa .md fuera de dot-dirs y node_modules, ≤ 1 MB', () => {
    fs.writeFileSync(path.join(vault, 'big.md'), 'x'.repeat(1024 * 1024 + 1));
    expect(listIndexable(vault).map(f => f.path).sort()).toEqual(['rules/merge.md', 'rules/pat.md']);
  });

  it('primera sync crea y activa la generación', async () => {
    const r = await indexer().sync();
    expect(r.promoted).toBe(true);
    expect(r.docs.added).toBe(2);
    expect(r.chunks.embedded).toBe(r.chunks.total);
    expect(readActive(home, 'D').active).toBe(r.generation);
  });

  it('segunda sync sin cambios no embebe nada', async () => {
    await indexer().sync();
    const r = await indexer().sync();
    expect(r.chunks.embedded).toBe(0);
    expect(r.docs.unchanged).toBe(2);
  });

  it('editar un documento embebe solo sus chunks nuevos (AC2)', async () => {
    const first = await indexer().sync();
    const p = path.join(vault, 'rules', 'merge.md');
    fs.writeFileSync(p, body('merge') + '\n\n## Tres\nNueva sección añadida con contenido suficiente para ser un chunk propio del documento editado.'.repeat(3));
    const future = new Date(Date.now() + 5000);
    fs.utimesSync(p, future, future);
    const r = await indexer().sync();
    expect(r.docs.updated).toBe(1);
    expect(r.chunks.embedded).toBeGreaterThan(0);
    expect(r.chunks.embedded).toBeLessThan(r.chunks.total);
    expect(r.chunks.reused).toBeGreaterThan(0);
    expect(r.generation).toBe(first.generation);
  });

  it('borrar un documento purga sus chunks (AC3)', async () => {
    const r1 = await indexer().sync();
    fs.rmSync(path.join(vault, 'rules', 'pat.md'));
    const r = await indexer().sync();
    expect(r.docs.deleted).toBe(1);
    const store = FlatVectorStore.load(path.join(domeDir(home, 'D'), r1.generation));
    expect(store.chunks.every(c => c.path !== 'rules/pat.md')).toBe(true);
  });

  it('pendingDocs detecta nuevos, borrados y modificados', async () => {
    const ix = indexer();
    expect((await ix.pending()).pendingDocs).toBe(2);
    await ix.sync();
    expect((await ix.pending()).pendingDocs).toBe(0);
    fs.writeFileSync(path.join(vault, 'rules', 'nuevo.md'), body('nuevo'));
    fs.rmSync(path.join(vault, 'rules', 'pat.md'));
    expect((await ix.pending()).pendingDocs).toBe(2);
  });

  it('contrato distinto construye generación sombra sin tocar la activa (P4)', async () => {
    const r1 = await indexer().sync();
    const other = new RagIndexer({ dome: 'D', vaultPath: vault, home, cfg, embedder: new HashEmbedder(64, undefined, 'hash-bow-v2') });
    const r2 = await other.sync();
    expect(r2.generation).not.toBe(r1.generation);
    expect(r2.shadow).toBe(true);
    expect(r2.promoted).toBe(false);
    const ptr = readActive(home, 'D');
    expect(ptr.active).toBe(r1.generation);
    expect(ptr.shadow).toBe(r2.generation);
  });

  it('no embebe notas con confidencialidad superior a la de la cúpula (CRIT-001)', async () => {
    fs.writeFileSync(path.join(vault, 'rules', 'secreta.md'), `---\nconfidentiality: N3\n---\n${body('secreta')}`);
    fs.writeFileSync(path.join(vault, 'rules', 'publica.md'), `---\nconfidentiality: N1\n---\n${body('publica')}`);
    const ix = new RagIndexer({ dome: 'D', vaultPath: vault, home, cfg, embedder: new HashEmbedder(64), domeLevel: 'N2' });
    const r = await ix.sync();
    expect(r.docs.skipped).toBe(1);
    const store = FlatVectorStore.load(path.join(domeDir(home, 'D'), r.generation));
    expect(store.chunks.some(c => c.path === 'rules/secreta.md')).toBe(false);
    expect(store.chunks.some(c => c.path === 'rules/publica.md')).toBe(true);
    // la nota omitida no queda pendiente para siempre
    expect((await ix.pending()).pendingDocs).toBe(0);
    // una cúpula N4 sí la indexa
    const n4 = new RagIndexer({ dome: 'E', vaultPath: vault, home, cfg, embedder: new HashEmbedder(64), domeLevel: 'N4' });
    expect((await n4.sync()).docs.skipped).toBe(0);
  });

  it('rebuild re-embebe todo', async () => {
    await indexer().sync();
    const r = await indexer().sync({ rebuild: true });
    expect(r.chunks.embedded).toBe(r.chunks.total);
  });
});

describe('lock de sync', () => {
  let dir: string;
  beforeEach(() => { dir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-rag-lock-')); });
  afterEach(() => { fs.rmSync(dir, { recursive: true, force: true }); });

  it('exclusivo mientras el dueño vive', () => {
    expect(acquireLock(dir)).toBe(true);
    expect(acquireLock(dir)).toBe(false);
    releaseLock(dir);
    expect(acquireLock(dir)).toBe(true);
    releaseLock(dir);
  });

  it('roba un lock huérfano (pid muerto)', () => {
    fs.writeFileSync(path.join(dir, 'sync.lock'), JSON.stringify({ pid: 999999, ts: Date.now() }));
    expect(acquireLock(dir)).toBe(true);
    releaseLock(dir);
  });

  it('roba un lock caducado (> 10 min)', () => {
    fs.writeFileSync(path.join(dir, 'sync.lock'), JSON.stringify({ pid: process.pid, ts: Date.now() - 11 * 60 * 1000 }));
    expect(acquireLock(dir)).toBe(true);
    releaseLock(dir);
  });
});
