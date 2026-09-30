// SE-418 — ledger git privado + journal + receipts de extremo a extremo con FilesService:
// contenido del ledger (AC1), idempotencia (AC2), recuperación tras caídas y fallo de git (AC3),
// autoridad del ledger (AC4), outbox (AC5), receipts (AC6), migración (AC7) y restauración (AC9).
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { FilesService, type FilesDomeRef } from '../../../src/files/service.js';
import { FileStore } from '../../../src/files/store.js';
import { ReceiptSigner } from '../../../src/files/receipts.js';
import { Journal } from '../../../src/files/journal.js';
import { sodiumReady } from '../../../src/files/crypto.js';

const b64 = (s: string) => Buffer.from(s).toString('base64');
const sha = (b: Buffer | string) => createHash('sha256').update(b).digest('hex');
const git = (dir: string, ...args: string[]) => execFileSync('git', ['-C', dir, ...args], { encoding: 'utf-8', maxBuffer: 64 * 1024 * 1024 });
const MARK = 'cormoran-5521';

describe('SE-418 ledger, journal y receipts', () => {
  let root: string;
  let env: NodeJS.ProcessEnv;
  let domes: FilesDomeRef[];
  let changed: string[];
  let svc: FilesService;

  const ledgerDir = (d: string) => path.join(env.SAVIA_FILES_HOME!, d, 'ledger');
  const store = (d: string, extra: { leaseMs?: number } = {}) => new FileStore({
    home: env.SAVIA_FILES_HOME, dome: d, keysHome: env.SAVIA_FILES_KEYS_HOME, domeLevel: d === 'S' ? 'N3' : 'N2', encrypt: d === 'S', ...extra,
  });
  const history = (d: string) => git(ledgerDir(d), 'log', '-p', '--all', '--format=%H %s');
  const snapshot = (dir: string) => Object.fromEntries(
    (fs.existsSync(dir) ? fs.readdirSync(dir) : []).sort().map((f) => [f, sha(fs.readFileSync(path.join(dir, f)))]));

  beforeEach(async () => {
    await sodiumReady();
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-ledger-e2e-'));
    env = { SAVIA_FILES_HOME: path.join(root, 'files'), SAVIA_FILES_KEYS_HOME: path.join(root, 'keys'), HOME: root, PATH: process.env.PATH };
    domes = [
      { name: 'P', confidentiality: 'N2', files: { enabled: true } },
      { name: 'S', confidentiality: 'N3', files: { enabled: true } },
    ];
    changed = [];
    svc = new FilesService({ domes: () => domes, env, scanMode: 'off', onChange: (d) => changed.push(d), authorizeAdmin: async () => undefined });
  });
  afterEach(() => { Journal.closeAll(); fs.rmSync(root, { recursive: true, force: true }); });

  it('AC1: un commit por lote con sus manifiestos e intent; nada sensible en toda la historia; sin remoto', async () => {
    for (const d of ['P', 'S']) {
      const [a, b] = await svc.putMany({
        dome: d, tags: [`etiqueta-${MARK}`],
        files: [{ name: `informe-${MARK}.txt`, bytes: Buffer.from(`texto ${MARK} uno`) }, { name: 'otro.md', bytes: Buffer.from(`# ${MARK}\n\ndos`) }],
      });
      expect(a.receipt).toMatchObject({ status: 'committed', kind: 'put', dome: d });
      expect(a.receipt).toEqual(b.receipt);
      expect(a.receipt!.refs).toEqual([{ documentId: a.documentId, revisionId: a.revisionId }, { documentId: b.documentId, revisionId: b.revisionId }]);
      const sha1 = a.receipt!.commitSha!;
      expect(git(ledgerDir(d), 'cat-file', '-t', sha1).trim()).toBe('commit');
      const files = git(ledgerDir(d), 'show', '--name-only', '--format=', sha1).trim().split('\n').sort();
      expect(files).toEqual([`intents/${a.operationId}.json`, `manifests/${a.documentId}.json`, `manifests/${b.documentId}.json`].sort());
      expect(git(ledgerDir(d), 'remote').trim()).toBe('');
      const h = history(d);
      for (const needle of [MARK, 'informe', 'otro.md', 'etiqueta', root]) expect(h, `${d}: ${needle}`).not.toContain(needle);
      if (d === 'S') {
        expect(h).not.toContain(a.sha256);
        expect(h).not.toContain('"type"');
      } else {
        expect(h).toContain(a.sha256); // en claras el blob es el SHA-256 del original (documentado)
      }
    }
  });

  it('AC2: idempotencia en put y delete; otra petición con la misma clave ⇒ IDEMPOTENCY_CONFLICT', async () => {
    const first = await svc.put({ dome: 'P', name: 'a.txt', contentBase64: b64('uno'), idempotencyKey: 'k-1' });
    const again = await svc.put({ dome: 'P', name: 'a.txt', contentBase64: b64('uno'), idempotencyKey: 'k-1' });
    expect(again.documentId).toBe(first.documentId);
    expect(again.revisionId).toBe(first.revisionId);
    expect(again.receipt).toEqual(first.receipt);
    expect((await svc.list({ dome: 'P' })).documents).toHaveLength(1);
    await expect(svc.put({ dome: 'P', name: 'a.txt', contentBase64: b64('dos'), idempotencyKey: 'k-1' })).rejects.toThrow(/IDEMPOTENCY_CONFLICT/);
    const del = await svc.delete({ dome: 'P', id: first.documentId, idempotencyKey: 'k-2' });
    const delAgain = await svc.delete({ dome: 'P', id: first.documentId, idempotencyKey: 'k-2' });
    expect(delAgain.receipt).toEqual(del.receipt);
    expect(fs.existsSync(path.join(ledgerDir('P'), 'tombstones', `${first.documentId}.json`))).toBe(true);
  });

  it('AC3a: caída tras escribir el payload y antes del commit ⇒ el siguiente acceso completa el commit', async () => {
    await svc.put({ dome: 'P', name: 'base.txt', contentBase64: b64('base') }); // crea ledger y journal
    const crashed = store('P', { leaseMs: 1 });
    const { operationId } = crashed.beginOperation('put');
    const { document } = crashed.add({ name: 'cortado.txt', bytes: Buffer.from(`cortado ${MARK}`) });
    // "muere": no hay finishOperation. Mientras tanto, los lectores lo ven (operación pendiente).
    expect(store('P').get(document.id).name).toBe('cortado.txt');
    await new Promise((r) => setTimeout(r, 5));
    const r = await svc.recover({ dome: 'P' });
    expect(r.pending).toBe(0);
    const op = await svc.operation({ dome: 'P', operationId });
    expect(op.operation.status).toBe('committed');
    expect(op.receipt).toMatchObject({ status: 'committed', kind: 'put' });
    expect(git(ledgerDir('P'), 'log', '--format=%s')).toContain(`put ${operationId} (recuperada)`);
    // AC5: la revisión quedó PENDING ⇒ el outbox la extrae una vez
    expect(store('P').revision(document.id).extraction.status).toBe('READY');
    expect((await svc.log({ dome: 'P' })).operations.filter((o) => o.kind === 'extract')).toHaveLength(1);
    expect(changed).toContain('P');
    expect((await svc.verify({ dome: 'P', deep: true })).problems).toEqual([]);
  });

  it('AC3b: caída antes de escribir el payload ⇒ operación failed, nada visible, blob huérfano fuera tras gc', async () => {
    await svc.put({ dome: 'P', name: 'base.txt', contentBase64: b64('base') });
    const crashed = store('P', { leaseMs: 1 });
    const { operationId } = crashed.beginOperation('put');
    const orphan = path.join(env.SAVIA_FILES_HOME!, 'P', 'blobs', sha('huérfano'));
    fs.writeFileSync(orphan, 'huérfano');
    await new Promise((r) => setTimeout(r, 5));
    await svc.recover({ dome: 'P' });
    const op = await svc.operation({ dome: 'P', operationId });
    expect(op.operation).toMatchObject({ status: 'failed', errorCode: 'ABORTED' });
    expect(op.receipt).toMatchObject({ status: 'failed', errorCode: 'ABORTED' });
    expect(op.receipt!.commitSha).toBeUndefined();
    expect((await svc.list({ dome: 'P' })).documents).toHaveLength(1);
    expect((await svc.gc({ dome: 'P' })).blobs).toBe(1);
    expect(fs.existsSync(orphan)).toBe(false);
  });

  it('AC3c: git falla ⇒ COMMIT_PENDING con operationId, nunca READY; al volver git, el reintento completa', async () => {
    await svc.put({ dome: 'P', name: 'base.txt', contentBase64: b64('base') });
    const lock = path.join(ledgerDir('P'), '.git', 'index.lock');
    fs.writeFileSync(lock, '');
    const err = await svc.put({ dome: 'P', name: 'b.txt', contentBase64: b64('bbb'), idempotencyKey: 'k-git' }).catch((e: Error) => e);
    expect(String(err)).toMatch(/COMMIT_PENDING.*operación o_[0-9a-f]{16} pendiente/);
    const opId = String(err).match(/o_[0-9a-f]{16}/)![0];
    expect((await svc.operation({ dome: 'P', operationId: opId })).operation.status).toBe('pending');
    fs.renameSync(lock, `${lock}.apartado`);
    const retry = await svc.put({ dome: 'P', name: 'b.txt', contentBase64: b64('bbb'), idempotencyKey: 'k-git' });
    expect(retry.operationId).toBe(opId);
    expect(retry.receipt).toMatchObject({ status: 'committed' });
    expect(retry.status).toBe('READY');
    expect((await svc.list({ dome: 'P' })).documents).toHaveLength(2);
  });

  it('AC4: payload tocado ⇒ INTEGRITY; payload sin manifiesto no se lista; verify los informa; remoto ⇒ UNSAFE_HOME', async () => {
    const a = await svc.put({ dome: 'P', name: 'a.txt', contentBase64: b64('aaa') });
    const docs = path.join(env.SAVIA_FILES_HOME!, 'P', 'docs');
    const payload = JSON.parse(fs.readFileSync(path.join(docs, `${a.documentId}.json`), 'utf-8'));
    fs.writeFileSync(path.join(docs, `${a.documentId}.json`), JSON.stringify({ ...payload, name: 'cambiado-a-mano.txt' }));
    await expect(svc.get({ dome: 'P', id: a.documentId })).rejects.toThrow(/INTEGRITY/);
    const intruso = 'f_00000000000000ff';
    fs.writeFileSync(path.join(docs, `${intruso}.json`), JSON.stringify({ ...payload, id: intruso }));
    expect((await svc.list({ dome: 'P' })).documents.map((d) => d.id)).not.toContain(intruso);
    const report = await svc.verify({ dome: 'P' });
    expect(report.ok).toBe(false);
    expect(report.problems).toEqual(expect.arrayContaining([{ code: 'PAYLOAD_MISMATCH', id: a.documentId }, { code: 'UNTRACKED_PAYLOAD', id: intruso }]));
    git(ledgerDir('P'), 'remote', 'add', 'origin', 'https://example.invalid/ledger.git');
    await expect(svc.put({ dome: 'P', name: 'c.txt', contentBase64: b64('c') })).rejects.toThrow(/UNSAFE_HOME/);
  });

  it('AC5: un rag-sync por operación y ningún efecto duplicado al repetir el outbox', async () => {
    await svc.put({ dome: 'P', name: 'a.txt', contentBase64: b64('aaa') });
    expect(changed).toEqual(['P']);
    await svc.recover({ dome: 'P' });
    expect(changed).toEqual(['P']);
    const s = store('P');
    s.beginOperation('put');
    const { document, revision } = s.add({ name: 'pendiente.txt', bytes: Buffer.from('pendiente') });
    s.finishOperation({ refs: [{ documentId: document.id, revisionId: revision.id }] }); // confirmado con la revisión PENDING
    expect(s.dueEvents('extract')).toHaveLength(1);
    await svc.recover({ dome: 'P' });
    await svc.recover({ dome: 'P' });
    expect(store('P').revision(document.id).extraction.status).toBe('READY');
    expect(store('P').dueEvents()).toEqual([]);
    expect((await svc.log({ dome: 'P' })).operations.filter((o) => o.kind === 'extract')).toHaveLength(1);
  });

  it('AC6: receipts verificables con el registro; la clave de firma es propia y 0600', async () => {
    const r = await svc.put({ dome: 'S', name: 'a.txt', contentBase64: b64('aaa') });
    const signer = new ReceiptSigner(env.SAVIA_FILES_KEYS_HOME!);
    expect(signer.verify(r.receipt!)).toBe(true);
    expect(signer.verify({ ...r.receipt!, commitSha: 'f'.repeat(40) })).toBe(false);
    const pem = path.join(signer.dir, `${r.receipt!.keyId}.pem`);
    expect(fs.statSync(pem).mode & 0o777).toBe(0o600);
    await svc.rotateSigningKey();
    expect(signer.verify(r.receipt!)).toBe(true);
    const later = await svc.put({ dome: 'S', name: 'b.txt', contentBase64: b64('bbb') });
    expect(later.receipt!.keyId).not.toBe(r.receipt!.keyId);
    expect((await svc.verify({ dome: 'S' })).problems).toEqual([]);
  });

  it('AC7: una cúpula de SE-417 sin ledger (clara y cifrada) se importa sin tocar bytes; el journal se reconstruye', async () => {
    const ids: Record<string, string> = {};
    for (const d of ['P', 'S']) {
      ids[d] = (await svc.put({ dome: d, name: 'viejo.txt', contentBase64: b64(`viejo ${d}`) })).documentId;
      // Estado anterior a SE-418: sin ledger, sin marca y sin journal.
      const dir = path.join(env.SAVIA_FILES_HOME!, d);
      Journal.closeAll();
      for (const f of ['ledger', 'ledger.json', 'journal.db', 'journal.db-wal', 'journal.db-shm']) {
        if (fs.existsSync(path.join(dir, f))) fs.renameSync(path.join(dir, f), path.join(root, `${d}-${f}.antes`));
      }
      const before = { docs: snapshot(path.join(dir, 'docs')), blobs: snapshot(path.join(dir, 'blobs')) };
      // Lectura sin ledger: sigue funcionando
      expect((await svc.get({ dome: d, id: ids[d] })).name).toBe('viejo.txt');
      await svc.recover({ dome: d }); // primera escritura ⇒ import
      expect(git(ledgerDir(d), 'log', '--format=%s').trim().split('\n')).toEqual([expect.stringMatching(/^import o_/)]);
      expect(fs.existsSync(path.join(ledgerDir(d), 'manifests', `${ids[d]}.json`))).toBe(true);
      expect({ docs: snapshot(path.join(dir, 'docs')), blobs: snapshot(path.join(dir, 'blobs')) }).toEqual(before);
      // Journal borrado ⇒ se reconstruye desde los intents
      await svc.put({ dome: d, name: 'nuevo.txt', contentBase64: b64('nuevo') });
      Journal.closeAll();
      for (const f of ['journal.db', 'journal.db-wal', 'journal.db-shm']) {
        if (fs.existsSync(path.join(dir, f))) fs.renameSync(path.join(dir, f), path.join(root, `${d}-${f}.borrado`));
      }
      const log = (await svc.log({ dome: d })).operations.map((o) => o.kind).sort();
      expect(log).toEqual(['import', 'put']);
      expect((await svc.verify({ dome: d, deep: true })).problems).toEqual([]);
      expect((await svc.readBytes({ dome: d, id: ids[d] })).bytes.toString()).toBe(`viejo ${d}`);
    }
  });

  it('AC9: el tar del almacén restaurado en un directorio vacío pasa verify y descarga bytes idénticos', async () => {
    const put = { P: await svc.put({ dome: 'P', name: 'a.txt', contentBase64: b64('clara') }), S: await svc.put({ dome: 'S', name: 'b.txt', contentBase64: b64('cifrada') }) };
    Journal.closeAll();
    const tarFile = path.join(root, 'files.tar.gz');
    execFileSync('tar', ['-czf', tarFile, '--exclude=files.lock', '--exclude=.work', '--exclude=*.tmp-*', '-C', root, 'files', 'keys']);
    const restored = path.join(root, 'restaurado');
    fs.mkdirSync(restored);
    execFileSync('tar', ['-xzf', tarFile, '-C', restored]);
    const env2 = { ...env, SAVIA_FILES_HOME: path.join(restored, 'files'), SAVIA_FILES_KEYS_HOME: path.join(restored, 'keys') };
    const svc2 = new FilesService({ domes: () => domes, env: env2, scanMode: 'off' });
    for (const [d, text] of [['P', 'clara'], ['S', 'cifrada']] as const) {
      expect((await svc2.verify({ dome: d, deep: true })).problems).toEqual([]);
      expect((await svc2.readBytes({ dome: d, id: put[d].documentId })).bytes.toString()).toBe(text);
    }
  });
});
