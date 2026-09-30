// SE-422 — área de subidas reanudables: estado en el journal (sobrevive a reinicios), trozos en
// claro o SVFU1 cifrado, offset estricto, checksum, límites, caducidad y lectura en streaming.
import { describe, it, expect, beforeAll, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash, randomBytes } from 'node:crypto';
import { Readable } from 'node:stream';
import { FileStore } from '../../../src/files/store.js';
import { UploadArea } from '../../../src/files/uploads.js';
import { Journal } from '../../../src/files/journal.js';
import { sodiumReady, FRAME_PLAIN_BYTES } from '../../../src/files/crypto.js';

const body = (b: Buffer, size = 64 * 1024) => Readable.from((function* () { for (let i = 0; i < b.length; i += size) yield b.subarray(i, i + size); })());
const collect = async (it: AsyncIterable<Uint8Array>) => { const out: Buffer[] = []; for await (const c of it) out.push(Buffer.from(c)); return Buffer.concat(out); };
const sha = (b: Buffer) => createHash('sha256').update(b).digest();

beforeAll(async () => { await sodiumReady(); });

describe('UploadArea', () => {
  let root: string;
  const store = (dome: string, encrypt: boolean, limits = {}) =>
    new FileStore({ home: path.join(root, 'files'), dome, keysHome: path.join(root, 'keys'), encrypt, domeLevel: encrypt ? 'N3' : 'N2', limits });
  beforeEach(() => { root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-uploads-')); });
  afterEach(() => { Journal.closeAll(); fs.rmSync(root, { recursive: true, force: true }); });

  for (const encrypt of [false, true]) {
    const label = encrypt ? 'N3 cifrada' : 'N2';
    it(`${label}: trozos en varias «sesiones» (reinicio entre medias) y lectura idéntica`, async () => {
      const data = randomBytes(2 * FRAME_PLAIN_BYTES + 4321);
      const a = new UploadArea(store('D', encrypt));
      const { uploadId } = a.create({ length: data.length, meta: { name: 'grande.bin', tags: ['t'] }, owner: 'eva' });
      const cut = FRAME_PLAIN_BYTES + 100;
      expect((await a.append(uploadId, 0, body(data.subarray(0, cut)), undefined, 'eva')).offset).toBe(cut);
      Journal.closeAll(); // «reinicio»
      const b = new UploadArea(store('D', encrypt));
      expect(b.info(uploadId, 'eva')).toMatchObject({ offset: cut, length: data.length, status: 'receiving', meta: { name: 'grande.bin', tags: ['t'] } });
      const r = await b.append(uploadId, cut, body(data.subarray(cut)), { algorithm: 'sha256', digest: sha(data.subarray(cut)) }, 'eva');
      expect(r).toMatchObject({ offset: data.length, complete: true });
      expect((await collect(b.read(uploadId))).equals(data)).toBe(true);
      if (encrypt) {
        const walk = (d: string): string[] => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)]));
        const probe = data.subarray(10, 74);
        expect(walk(path.join(root, 'files', 'D')).filter((f) => fs.readFileSync(f).includes(probe))).toEqual([]);
        expect(walk(path.join(root, 'files', 'D')).filter((f) => fs.readFileSync(f).includes(Buffer.from('grande.bin')))).toEqual([]);
      }
    });
  }

  it('offset erróneo ⇒ CONFLICT; checksum erróneo ⇒ CHECKSUM_MISMATCH sin avanzar; exceso ⇒ INVALID_INPUT', async () => {
    const a = new UploadArea(store('D', true));
    const data = randomBytes(1000);
    const { uploadId } = a.create({ length: 1000, meta: { name: 'x.bin' }, owner: 'eva' });
    await expect(a.append(uploadId, 5, body(data), undefined, 'eva')).rejects.toThrow(/CONFLICT/);
    await expect(a.append(uploadId, 0, body(data.subarray(0, 400)), { algorithm: 'sha256', digest: Buffer.alloc(32) }, 'eva')).rejects.toThrow(/CHECKSUM_MISMATCH/);
    expect(a.info(uploadId, 'eva').offset).toBe(0);
    await a.append(uploadId, 0, body(data.subarray(0, 400)), { algorithm: 'sha256', digest: sha(data.subarray(0, 400)) }, 'eva');
    await expect(a.append(uploadId, 400, body(randomBytes(700)), undefined, 'eva')).rejects.toThrow(/INVALID_INPUT/);
    expect(a.info(uploadId, 'eva').offset).toBe(400);
    await a.append(uploadId, 400, body(data.subarray(400)), undefined, 'eva');
    expect((await collect(a.read(uploadId))).equals(data)).toBe(true);
  });

  it('límite de tamaño, dueño, subida vacía, terminación y caducidad', async () => {
    const a = new UploadArea(store('D', false, { maxBytes: 100 }));
    expect(() => a.create({ length: 101, meta: { name: 'x' }, owner: 'eva' })).toThrow(/TOO_LARGE/);
    expect(() => a.create({ length: -1, meta: { name: 'x' }, owner: 'eva' })).toThrow(/INVALID_INPUT/);
    expect(() => a.create({ length: 1, meta: { name: '../x' }, owner: 'eva' })).toThrow(/INVALID_INPUT/);
    const empty = a.create({ length: 0, meta: { name: 'vacio.txt' }, owner: 'eva' });
    expect(a.info(empty.uploadId, 'eva')).toMatchObject({ offset: 0, length: 0, complete: true });
    expect((await collect(a.read(empty.uploadId))).length).toBe(0);
    const u = a.create({ length: 10, meta: { name: 'x.bin' }, owner: 'eva' });
    expect(() => a.info(u.uploadId, 'otro')).toThrow(/NOT_FOUND/); // de otro dueño: no existe
    a.terminate(u.uploadId, 'eva');
    expect(() => a.info(u.uploadId, 'eva')).toThrow(/NOT_FOUND/);
    const old = a.create({ length: 10, meta: { name: 'x.bin' }, owner: 'eva', expiresInMs: 1 });
    await new Promise((r) => setTimeout(r, 5));
    await expect(a.append(old.uploadId, 0, body(randomBytes(10)), undefined, 'eva')).rejects.toThrow(/EXPIRED/);
    expect(a.gcExpired()).toBe(1);
    // Solo queda la subida vacía (completa, pendiente de procesar); la terminada y la caducada, fuera
    expect(fs.readdirSync(path.join(root, 'files', 'D', 'uploads')).sort()).toEqual([`${empty.uploadId}.meta`, `${empty.uploadId}.part`]);
  });

  it('una subida manipulada en disco no se lee (cifrada ⇒ INTEGRITY)', async () => {
    const a = new UploadArea(store('D', true));
    const data = randomBytes(5000);
    const { uploadId } = a.create({ length: data.length, meta: { name: 'x.bin' }, owner: 'eva' });
    await a.append(uploadId, 0, body(data), undefined, 'eva');
    const f = fs.readdirSync(path.join(root, 'files', 'D', 'uploads')).find((x) => x.startsWith(uploadId) && x.endsWith('.svfu'))!;
    const p = path.join(root, 'files', 'D', 'uploads', f);
    const b = fs.readFileSync(p); b[b.length - 10] ^= 1; fs.writeFileSync(p, b);
    await expect(collect(a.read(uploadId))).rejects.toThrow(/INTEGRITY/);
  });
});
