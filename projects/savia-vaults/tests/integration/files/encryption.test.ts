// SE-417 — cifrado en reposo de extremo a extremo: Savia Files + Savia RAG en una cúpula N3.
// Nada en claro en el almacén ni en el índice (tampoco el BM25 persistido), búsqueda con cita,
// rotación sin re-embeber, migración de una cúpula en claro y borrado.
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash } from 'node:crypto';
import { RagService, type RagDomeRef } from '../../../src/rag/service.js';
import { HashEmbedder } from '../../../src/rag/embedder.js';
import { FilesService, type FilesDomeRef } from '../../../src/files/service.js';
import { importRecovery, sealKeyBackup } from '../../../src/files/keys.js';
import { execFileSync } from 'node:child_process';
import type { ResolvedRagConfig } from '../../../src/rag/types.js';

class CountingEmbedder extends HashEmbedder {
  docCalls = 0;
  async embed(texts: string[], kind: 'query' | 'doc' = 'doc'): Promise<Float32Array[]> {
    if (kind === 'doc') this.docCalls += texts.length;
    return super.embed(texts);
  }
}

const MARK = 'albatros-7731';
const b64 = (s: string) => Buffer.from(s).toString('base64');
const walk = (d: string): string[] => (fs.existsSync(d) ? fs.readdirSync(d, { withFileTypes: true })
  .flatMap((e) => (e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)])) : []);

describe('SE-417 cifrado de extremo a extremo', () => {
  let root: string;
  let env: NodeJS.ProcessEnv;
  let domes: (RagDomeRef & FilesDomeRef)[];
  let embedder: CountingEmbedder;
  let rag: RagService;
  let files: FilesService;

  const leaks = (needles: string[]) => [...walk(env.SAVIA_FILES_HOME!), ...walk(env.SAVIA_RAG_HOME!)]
    .filter((f) => { const b = fs.readFileSync(f); return needles.some((n) => b.includes(Buffer.from(n))); });
  const search = async (dome: string, q: string) => (await rag.search({ queries: [q], domes: [dome], k: 5, mode: 'bm25' })).results[0].hits;

  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-e2e-enc-'));
    env = {
      SAVIA_FILES_HOME: path.join(root, 'files'), SAVIA_FILES_KEYS_HOME: path.join(root, 'keys'),
      SAVIA_RAG_HOME: path.join(root, 'rag'), HOME: root, PATH: process.env.PATH,
    };
    for (const d of ['S', 'P']) {
      fs.mkdirSync(path.join(root, d));
      fs.writeFileSync(path.join(root, d, 'nota.md'), '# Nota\n\nNota pública de la cúpula.\n');
    }
    domes = [
      { name: 'S', path: path.join(root, 'S'), confidentiality: 'N3', rag: { enabled: true, model: 'h' }, files: { enabled: true } },
      { name: 'P', path: path.join(root, 'P'), confidentiality: 'N2', rag: { enabled: true, model: 'h' }, files: { enabled: true } },
    ];
    embedder = new CountingEmbedder(64, { chunkChars: 1200, overlap: 180 } as ResolvedRagConfig, 'h');
    rag = new RagService({ domes: () => domes, home: env.SAVIA_RAG_HOME, env, embedderFactory: () => embedder });
    files = new FilesService({
      domes: () => domes, env, scanMode: 'off',
      onEncrypted: (d) => rag.sealIndex(d), resealIndex: (d) => rag.resealIndex(d),
    });
  });
  afterEach(() => fs.rmSync(root, { recursive: true, force: true }));

  it('AC1: N3 — nada en claro en disco (almacén e índice); búsqueda con cita y descarga idéntica', async () => {
    const csv = `equipo,ubicación\n${MARK},sala norte\n`;
    const put = await files.put({ dome: 'S', name: `inventario-${MARK}.csv`, contentBase64: b64(csv) });
    const hits = await search('S', `${MARK} sala norte`);
    const hit = hits.find((h) => h.source);
    expect(hit?.source).toMatchObject({ documentId: put.documentId, locator: { type: 'row', row: 2 } });
    expect(hit?.text).toContain(MARK);
    const sha = createHash('sha256').update(csv).digest('hex');
    expect(leaks([MARK, 'sala norte', sha])).toEqual([]);
    const dl = await files.download({ dome: 'S', id: put.documentId });
    expect(Buffer.from(dl.contentBase64, 'base64').toString()).toBe(csv);
  });

  it('AC4: rotar la clave re-sella el índice sin re-embeber; todo sigue funcionando', async () => {
    const put = await files.put({ dome: 'S', name: 'a.txt', contentBase64: b64(`texto ${MARK}`) });
    await search('S', MARK);
    const before = embedder.docCalls;
    const kek = fs.readFileSync(path.join(root, 'keys', 'S', 'kek'));
    await files.rotateKeys({ dome: 'S' });
    expect(fs.readFileSync(path.join(root, 'keys', 'S', 'kek')).equals(kek)).toBe(false);
    const rag2 = new RagService({ domes: () => domes, home: env.SAVIA_RAG_HOME, env, embedderFactory: () => embedder });
    const hits = (await rag2.search({ queries: [MARK], domes: ['S'], k: 5, mode: 'bm25' })).results[0].hits;
    expect(hits.some((h) => h.source?.documentId === put.documentId)).toBe(true);
    expect(embedder.docCalls).toBe(before);
    expect(leaks([MARK])).toEqual([]);
  });

  it('AC5: migrar una cúpula N2 en claro con índice ya construido: sin restos en claro ni re-embebido', async () => {
    const put = await files.put({ dome: 'P', name: 'plan.txt', contentBase64: b64(`plan ${MARK}`) });
    expect((await search('P', MARK)).some((h) => h.source)).toBe(true);
    expect(leaks([MARK]).length).toBeGreaterThan(0); // en claro antes de cifrar
    const before = embedder.docCalls;
    domes[1].files = { enabled: true, encryption: true };
    expect(await files.encrypt({ dome: 'P' })).toMatchObject({ documents: 1, revisions: 1 });
    expect(leaks([MARK])).toEqual([]);
    expect(embedder.docCalls).toBe(before);
    expect((await search('P', MARK)).some((h) => h.source?.documentId === put.documentId)).toBe(true);
    expect(leaks([MARK])).toEqual([]);
  });

  it('borrar en una cúpula cifrada lo saca del índice en el siguiente sync', async () => {
    const put = await files.put({ dome: 'S', name: 'a.txt', contentBase64: b64(`borrar ${MARK}`) });
    expect((await search('S', MARK)).some((h) => h.source)).toBe(true);
    await files.delete({ dome: 'S', id: put.documentId });
    expect((await search('S', MARK)).some((h) => h.source?.documentId === put.documentId)).toBe(false);
  });

  it('AC7: restauración desde el tar nocturno + fichero de recuperación + copia sellada de claves', async () => {
    const svc = new FilesService({ domes: () => domes, env, scanMode: 'off', authorizeAdmin: async () => undefined });
    const put = await svc.put({ dome: 'S', name: 'contrato.txt', contentBase64: b64(`original ${MARK}`) });
    const rec = await svc.exportRecovery({ dir: path.join(root, 'rec') });
    const put2 = await svc.put({ dome: 'S', name: 'posterior.txt', contentBase64: b64('después de exportar') });
    // Lo que hace el backup nocturno: tar del almacén (sin locks) + copia sellada de claves.
    const tarFile = path.join(root, 'savia-files.tar.gz');
    execFileSync('tar', ['-czf', tarFile, '--exclude=files.lock', '-C', root, 'files']);
    const sealed = sealKeyBackup(env.SAVIA_FILES_KEYS_HOME!);
    // Disco perdido: almacén y claves desaparecen.
    fs.rmSync(env.SAVIA_FILES_HOME!, { recursive: true, force: true });
    fs.rmSync(env.SAVIA_FILES_KEYS_HOME!, { recursive: true, force: true });
    // Restauración en directorios vacíos.
    const restored = path.join(root, 'restaurado');
    fs.mkdirSync(restored);
    execFileSync('tar', ['-xzf', tarFile, '-C', restored]);
    const phrase = fs.readFileSync(path.join(rec.dir, 'frase-de-recuperacion.txt'), 'utf-8').trim();
    importRecovery(path.join(restored, 'keys'), fs.readFileSync(path.join(rec.dir, 'savia-claves.recovery')), phrase, sealed);
    const env2 = { ...env, SAVIA_FILES_HOME: path.join(restored, 'files'), SAVIA_FILES_KEYS_HOME: path.join(restored, 'keys') };
    const svc2 = new FilesService({ domes: () => domes, env: env2, scanMode: 'off' });
    for (const [p, text] of [[put, `original ${MARK}`], [put2, 'después de exportar']] as const) {
      const dl = await svc2.download({ dome: 'S', id: p.documentId });
      expect(Buffer.from(dl.contentBase64, 'base64').toString()).toBe(text);
    }
  }, 60_000);
});

