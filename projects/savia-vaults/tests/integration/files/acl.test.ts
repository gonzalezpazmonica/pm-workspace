// SE-419 — permisos por documento de extremo a extremo (FilesService + Savia RAG): nivel del
// documento (AC1), listas (AC2), acción policy (AC3), efecto inmediato en vault_rag (AC4), put
// (AC5), modo local (AC6) y cúpula cifrada (AC7).
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { execFileSync } from 'node:child_process';
import { FilesService, callFilesTool } from '../../../src/files/service.js';
import { RagService, type RagDomeRef } from '../../../src/rag/service.js';
import { HashEmbedder } from '../../../src/rag/embedder.js';
import { Journal } from '../../../src/files/journal.js';
import type { Principal } from '../../../src/files/policy.js';
import type { ResolvedRagConfig } from '../../../src/rag/types.js';

const b64 = (s: string) => Buffer.from(s).toString('base64');
const MARK = 'alcaudon-8812';
type Who = Principal | undefined;
const reader = (username: string): Principal => ({ username, role: 'reader' });
const writer = (username: string): Principal => ({ username, role: 'writer' });
const admin: Principal = { username: 'root', role: 'admin' };

describe('SE-419 permisos por documento', () => {
  let root: string;
  let env: NodeJS.ProcessEnv;
  let domes: RagDomeRef[];
  let who: Who;
  let files: FilesService;
  let rag: RagService;

  const as = async <T>(p: Who, fn: () => Promise<T>): Promise<T> => { who = p; try { return await fn(); } finally { who = undefined; } };
  const ragHits = async (p: Who, q: string, dome = 'D') => as(p, async () => {
    const r = await rag.search({ queries: [q], domes: [dome], k: 5, mode: 'bm25' });
    return { hits: r.results[0].hits.filter((h) => h.source).map((h) => h.source!.documentId), outcome: r.domes[0] };
  });
  const listIds = async (p: Who, dome = 'D') => (await as(p, () => files.list({ dome }))).documents.map((d) => d.id);

  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-acl-'));
    env = { SAVIA_FILES_HOME: path.join(root, 'files'), SAVIA_FILES_KEYS_HOME: path.join(root, 'keys'), SAVIA_RAG_HOME: path.join(root, 'rag'), HOME: root, PATH: process.env.PATH };
    domes = ['D', 'S'].map((name) => {
      fs.mkdirSync(path.join(root, name));
      fs.writeFileSync(path.join(root, name, 'nota.md'), '# Nota\n\nNota de la cúpula.\n');
      return { name, path: path.join(root, name), confidentiality: name === 'S' ? 'N3' : 'N2', rag: { enabled: true, model: 'h' }, files: { enabled: true } } as RagDomeRef;
    });
    who = undefined;
    const authorize = async () => who;
    const emb = new HashEmbedder(64, { chunkChars: 1200, overlap: 180 } as ResolvedRagConfig, 'h');
    rag = new RagService({ domes: () => domes, home: env.SAVIA_RAG_HOME, env, embedderFactory: () => emb, authorize });
    files = new FilesService({
      domes: () => domes.map((d) => ({ name: d.name, confidentiality: d.confidentiality, files: d.files })),
      env, scanMode: 'off', authorize, onChange: () => undefined,
      onEncrypted: (d) => rag.sealIndex(d), resealIndex: (d) => rag.resealIndex(d),
    });
  });
  afterEach(() => { Journal.closeAll(); fs.rmSync(root, { recursive: true, force: true }); });

  it('AC1: cúpula reclasificada N3→N2: un reader no ve sus documentos N3 en list, get, text, download ni vault_rag; un writer sí', async () => {
    domes[0] = { ...domes[0], confidentiality: 'N3' };
    const secret = await as(writer('eva'), () => files.put({ dome: 'D', name: 'secreto.txt', contentBase64: b64(`informe ${MARK} reservado`), confidentiality: 'N3' }));
    domes[0] = { ...domes[0], confidentiality: 'N2' }; // reclasificación a la baja en el registro
    const open = await as(writer('eva'), () => files.put({ dome: 'D', name: 'abierto.txt', contentBase64: b64('informe público') }));
    expect(await listIds(reader('ana'))).toEqual([open.documentId]);
    for (const action of ['get', 'text', 'download'] as const) {
      await expect(as(reader('ana'), () => callFilesTool(files, { action, dome: 'D', id: secret.documentId }))).rejects.toThrow(/NOT_FOUND/);
    }
    expect((await ragHits(reader('ana'), MARK)).hits).not.toContain(secret.documentId);
    // En RAG, el indexador ya omite para todos lo que supera el nivel de la cúpula (SE-410)
    expect((await ragHits(writer('eva'), MARK)).hits).not.toContain(secret.documentId);
    expect((await listIds(writer('eva'))).sort()).toEqual([open.documentId, secret.documentId].sort());
    expect((await as(writer('eva'), () => files.text({ dome: 'D', id: secret.documentId }))).units[0].text).toContain(MARK);
  });

  it('AC2: listas readers/writers restringen; [] solo admin; null hereda', async () => {
    const d = await as(admin, () => files.put({ dome: 'D', name: 'a.txt', contentBase64: b64(`texto ${MARK}`) }));
    await as(admin, () => files.policy({ dome: 'D', id: d.documentId, readers: ['ana'], writers: ['eva'] }));
    expect(await listIds(reader('ana'))).toEqual([d.documentId]);
    expect(await listIds(reader('luis'))).toEqual([]);
    const hidden = await ragHits(reader('luis'), MARK);
    expect(hidden.hits).toEqual([]);
    expect(hidden.outcome.filtered).toBeGreaterThan(0); // solo el número, sin ids
    expect(JSON.stringify(hidden.outcome)).not.toContain(d.documentId);
    expect((await ragHits(reader('ana'), MARK)).hits).toEqual([d.documentId]);
    // eva escribe; otro writer lo lee (no está en readers ⇒ no) y no escribe
    await as(writer('eva'), () => files.reprocess({ dome: 'D', id: d.documentId }));
    await expect(as(writer('otro'), () => files.delete({ dome: 'D', id: d.documentId }))).rejects.toThrow(/NOT_FOUND/);
    await as(admin, () => files.policy({ dome: 'D', id: d.documentId, readers: null }));
    await expect(as(writer('otro'), () => files.delete({ dome: 'D', id: d.documentId }))).rejects.toThrow(/POLICY_DENIED/);
    expect(await listIds(reader('luis'))).toEqual([d.documentId]); // readers null: hereda
    await as(admin, () => files.policy({ dome: 'D', id: d.documentId, readers: [], writers: [] }));
    expect(await listIds(writer('eva'))).toEqual([]);
    expect(await listIds(admin)).toEqual([d.documentId]);
    expect((await as(admin, () => files.get({ dome: 'D', id: d.documentId }))).acl).toEqual({ readers: [], writers: [] });
  });

  it('AC3: policy — receipt y commit sin nombres de usuario; versión; errores', async () => {
    const d = await as(writer('eva'), () => files.put({ dome: 'D', name: 'a.txt', contentBase64: b64('a') }));
    const r = await as(writer('eva'), () => files.policy({ dome: 'D', id: d.documentId, confidentiality: 'N2', readers: ['ana-lopez'], writers: ['eva'], expectedPolicyVersion: 0 }));
    expect(r).toMatchObject({ policyVersion: 1, readers: ['ana-lopez'], writers: ['eva'], receipt: { kind: 'policy', status: 'committed' } });
    const history = execFileSync('git', ['-C', path.join(env.SAVIA_FILES_HOME!, 'D', 'ledger'), 'log', '-p', '--all'], { encoding: 'utf-8' });
    expect(history).toContain(`policy ${r.operationId}`);
    expect(history).not.toContain('ana-lopez');
    await expect(as(writer('eva'), () => files.policy({ dome: 'D', id: d.documentId, readers: null, expectedPolicyVersion: 0 }))).rejects.toThrow(/CONFLICT/);
    await expect(as(writer('eva'), () => files.policy({ dome: 'D', id: d.documentId, confidentiality: 'N3' }))).rejects.toThrow(/INVALID_INPUT/);
    await expect(as(writer('eva'), () => files.policy({ dome: 'D', id: d.documentId, readers: ['../x'] }))).rejects.toThrow(/INVALID_INPUT/);
    await expect(as(reader('ana-lopez'), () => files.policy({ dome: 'D', id: d.documentId, readers: null }))).rejects.toThrow(/POLICY_DENIED/);
    await expect(as(writer('luis'), () => files.policy({ dome: 'D', id: d.documentId, readers: null }))).rejects.toThrow(/NOT_FOUND/); // readers: [ana-lopez] ⇒ ni lo ve
    // Quien solo lee no ve las listas
    const seen = await as(reader('ana-lopez'), () => files.get({ dome: 'D', id: d.documentId }));
    expect(seen.acl).toBeUndefined();
    expect(seen.policyVersion).toBeUndefined();
  });

  it('AC4: endurecer vale en la siguiente vault_rag sin sync; un borrado desaparece antes del sync', async () => {
    const d = await as(writer('eva'), () => files.put({ dome: 'D', name: 'a.txt', contentBase64: b64(`texto ${MARK}`) }));
    expect((await ragHits(reader('ana'), MARK)).hits).toEqual([d.documentId]);
    await as(writer('eva'), () => files.policy({ dome: 'D', id: d.documentId, confidentiality: 'N2', readers: ['eva'] }));
    expect((await ragHits(reader('ana'), MARK)).hits).toEqual([]);
    expect((await ragHits(writer('eva'), MARK)).hits).toEqual([d.documentId]);
    // Borrado sin sync de RAG: el hit ya no sale ni en modo local
    const e = await files.put({ dome: 'D', name: 'b.txt', contentBase64: b64(`otro ${MARK} más`) });
    await ragHits(undefined, MARK); // indexa
    const syncs: string[] = [];
    const quiet = new FilesService({ domes: () => domes.map((x) => ({ name: x.name, confidentiality: x.confidentiality, files: x.files })), env, scanMode: 'off', onChange: (x) => syncs.push(x) });
    await quiet.delete({ dome: 'D', id: e.documentId });
    const r = await as(undefined, async () => rag.search({ queries: [MARK], domes: ['D'], k: 5, mode: 'bm25', includeStale: true }));
    expect(r.results[0].hits.map((h) => h.source?.documentId)).not.toContain(e.documentId);
  });

  it('AC5: un writer no crea N4 ni sustituye/borra/reprocesa lo que no puede escribir', async () => {
    domes[0] = { ...domes[0], confidentiality: 'N4' };
    await expect(as(writer('eva'), () => files.put({ dome: 'D', name: 'x.txt', contentBase64: b64('x') }))).rejects.toThrow(/POLICY_DENIED/);
    domes[0] = { ...domes[0], confidentiality: 'N2' };
    const d = await as(admin, () => files.put({ dome: 'D', name: 'x.txt', contentBase64: b64('x') }));
    await as(admin, () => files.policy({ dome: 'D', id: d.documentId, writers: ['eva'] }));
    await expect(as(writer('luis'), () => files.put({ dome: 'D', name: 'x.txt', contentBase64: b64('y'), replaces: d.documentId }))).rejects.toThrow(/POLICY_DENIED/);
    await expect(as(writer('luis'), () => files.reprocess({ dome: 'D', id: d.documentId }))).rejects.toThrow(/POLICY_DENIED/);
    await expect(as(writer('luis'), () => files.delete({ dome: 'D', id: d.documentId }))).rejects.toThrow(/POLICY_DENIED/);
    expect((await as(admin, () => files.get({ dome: 'D', id: d.documentId }))).revisions).toHaveLength(1);
    const ok = await as(writer('eva'), () => files.put({ dome: 'D', name: 'x.txt', contentBase64: b64('y'), replaces: d.documentId }));
    expect(ok.documentId).toBe(d.documentId);
  });

  it('AC6: sin usuarios (modo local) todo permitido; las listas se guardan y se aplican después', async () => {
    const d = await files.put({ dome: 'D', name: 'a.txt', contentBase64: b64(`texto ${MARK}`), confidentiality: 'N2' });
    await files.policy({ dome: 'D', id: d.documentId, readers: [] });
    expect(await listIds(undefined)).toEqual([d.documentId]);
    expect((await ragHits(undefined, MARK)).hits).toEqual([d.documentId]);
    expect(await listIds(reader('ana'))).toEqual([]);
  });

  it('AC7: en una cúpula cifrada las listas no quedan en claro; editarlas a mano ⇒ INTEGRITY', async () => {
    const d = await as(writer('eva'), () => files.put({ dome: 'S', name: 'a.txt', contentBase64: b64('a') }));
    await as(writer('eva'), () => files.policy({ dome: 'S', id: d.documentId, readers: ['usuaria-oculta'] }));
    const walk = (dir: string): string[] => fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]));
    const leaks = walk(path.join(env.SAVIA_FILES_HOME!, 'S')).filter((f) => fs.readFileSync(f).includes(Buffer.from('usuaria-oculta')));
    expect(leaks).toEqual([]);
    const plain = path.join(env.SAVIA_FILES_HOME!, 'D', 'docs');
    const dd = await files.put({ dome: 'D', name: 'b.txt', contentBase64: b64('b') });
    await files.policy({ dome: 'D', id: dd.documentId, readers: ['ana'] });
    const p = path.join(plain, `${dd.documentId}.json`);
    const j = JSON.parse(fs.readFileSync(p, 'utf-8'));
    fs.writeFileSync(p, JSON.stringify({ ...j, acl: { readers: ['ana', 'intrusa'] } }));
    await expect(as(reader('intrusa'), () => files.get({ dome: 'D', id: dd.documentId }))).rejects.toThrow(/INTEGRITY/);
  });
});
