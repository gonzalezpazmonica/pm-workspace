// SE-422 — subidas reanudables de Savia Files (base del servidor tus). Estado en el journal de la
// cúpula (sobrevive a reinicios), bytes en `<cúpula>/uploads/`: en claro (`.part`) en cúpulas
// claras y SVFU1 (trozos sellados, SE-421) en cifradas, con los metadatos también sellados. El
// dueño se guarda como hash. Un trozo interrumpido conserva lo recibido salvo si trae checksum.
import * as fs from 'node:fs';
import * as path from 'node:path';
import { createHash, randomBytes } from 'node:crypto';
import { FRAME_PLAIN_BYTES, UPLOAD_MAGIC, open, openUploadChunk, seal, sealUploadChunk } from './crypto.js';
import { sanitizeName, type FileStore } from './store.js';
import { FilesError } from './types.js';
import type { Journal, UploadRow } from './journal.js';

export interface UploadMeta {
  name: string;
  tags?: string[];
  confidentiality?: string;
  replaces?: string;
  idempotencyKey?: string;
  /** SE-422: `jti` de la autorización acotada que creó la subida (solo ella puede continuarla). */
  grant?: string;
}

export interface UploadInfo extends Omit<UploadRow, 'ownerHash' | 'fileSize' | 'chunkIndex'> {
  complete: boolean;
  meta: UploadMeta;
}

export const DEFAULT_UPLOAD_EXPIRY_MS = 24 * 3600_000;
const UPLOAD_ID_RE = /^u_[0-9a-f]{24}$/;
const DIR_MODE = 0o700;
const appending = new Set<string>();

const ownerHash = (owner: string) => createHash('sha256').update(`savia-files-owner\n${owner}`).digest('hex');

export class UploadArea {
  private readonly dir: string;

  constructor(private readonly store: FileStore) {
    this.dir = path.join(store.dir, 'uploads');
  }

  private get journal(): Journal { return this.store.uploadJournal(); }
  private encrypted(): boolean { return this.store.willEncrypt(); }
  private dataPath(id: string): string { return path.join(this.dir, `${id}${this.encrypted() ? '.svfu' : '.part'}`); }
  private metaPath(id: string): string { return path.join(this.dir, `${id}.meta`); }
  private metaAad(id: string) { return { schemaVersion: 1, domeId: this.store.dome, uploadId: id, artifactKind: 'upload-meta' }; }

  create(o: { length: number; meta: UploadMeta; owner: string; expiresInMs?: number }): { uploadId: string; expiresAt: number } {
    if (!Number.isSafeInteger(o.length) || o.length < 0) throw new FilesError('INVALID_INPUT', 'Upload-Length debe ser un entero ≥ 0');
    if (o.length > this.store.limits.maxBytes) throw new FilesError('TOO_LARGE', `${o.length} bytes > límite ${this.store.limits.maxBytes}`);
    const meta: UploadMeta = { ...o.meta, name: sanitizeName(o.meta.name) };
    if (this.encrypted()) {
      if (this.store.isEncrypted()) this.store.keys.kek(); // KEY_MISSING: nunca otra clave
      else this.store.keys.init();
    }
    fs.mkdirSync(this.dir, { recursive: true, mode: DIR_MODE });
    const uploadId = `u_${randomBytes(12).toString('hex')}`;
    const expiresAt = Date.now() + (o.expiresInMs ?? DEFAULT_UPLOAD_EXPIRY_MS);
    const metaBytes = Buffer.from(JSON.stringify(meta));
    fs.writeFileSync(this.metaPath(uploadId), this.encrypted() ? seal(this.store.keys.subkey('meta')!, metaBytes, this.metaAad(uploadId)) : metaBytes, { mode: 0o600 });
    let initial = Buffer.alloc(0);
    if (this.encrypted()) {
      initial = UPLOAD_MAGIC;
      if (o.length === 0) initial = Buffer.concat([UPLOAD_MAGIC, sealUploadChunk(this.store.uploadKey(uploadId), uploadId, 0, Buffer.alloc(0), true)]);
    }
    fs.writeFileSync(this.dataPath(uploadId), initial, { mode: 0o600 });
    this.journal.uploadCreate({ uploadId, ownerHash: ownerHash(o.owner), length: o.length, expiresAt });
    if (initial.length) this.journal.uploadAdvance(uploadId, 0, { offset: 0, fileSize: initial.length, chunkIndex: o.length === 0 ? 1 : 0 });
    return { uploadId, expiresAt };
  }

  /** Fila de la subida si existe y es de `owner` (si no, NOT_FOUND: no se revela que existe). */
  private row(id: string, owner?: string): UploadRow {
    const r = UPLOAD_ID_RE.test(id) ? this.journal.upload(id) : undefined;
    if (!r || (owner !== undefined && r.ownerHash !== ownerHash(owner)) || r.status === 'terminated') {
      throw new FilesError('NOT_FOUND', `subida ${String(id).slice(0, 40)} no existe`);
    }
    return r;
  }

  private meta(id: string): UploadMeta {
    const raw = fs.readFileSync(this.metaPath(id));
    const plain = this.encrypted() ? open(this.store.keys.subkey('meta')!, raw, this.metaAad(id)) : raw;
    return JSON.parse(plain.toString('utf-8')) as UploadMeta;
  }

  info(id: string, owner?: string): UploadInfo {
    const r = this.row(id, owner);
    const { ownerHash: _o, fileSize: _f, chunkIndex: _c, ...rest } = r;
    const alive = r.status === 'receiving' || r.status === 'processing';
    return { ...rest, complete: r.offset === r.length, meta: alive ? this.meta(id) : { name: '' } };
  }

  /**
   * Añade bytes en `offset` (debe ser el actual). Con checksum, el trozo entero se verifica y, si no
   * cuadra, se descarta. Sin checksum, si la conexión se corta se conserva lo recibido.
   */
  async append(id: string, offset: number, source: AsyncIterable<Uint8Array>, checksum: { algorithm: 'sha256'; digest: Buffer } | undefined, owner?: string): Promise<{ offset: number; complete: boolean }> {
    const r = this.row(id, owner);
    if (r.status !== 'receiving') throw new FilesError('CONFLICT', `la subida ${id} ya no admite datos (${r.status})`);
    if (r.expiresAt <= Date.now()) throw new FilesError('EXPIRED', `la subida ${id} caducó`);
    if (offset !== r.offset) throw new FilesError('CONFLICT', `Upload-Offset ${offset} no coincide con ${r.offset}`);
    if (appending.has(id)) throw new FilesError('LOCKED', `ya hay otra escritura en la subida ${id}`);
    appending.add(id);
    const enc = this.encrypted();
    const key = enc ? this.store.uploadKey(id) : undefined;
    const fd = fs.openSync(this.dataPath(id), 'r+');
    const hash = checksum ? createHash('sha256') : undefined;
    let pos = r.fileSize;
    let off = r.offset;
    let idx = r.chunkIndex;
    let pending: Buffer[] = [];
    let pendingBytes = 0;
    const write = (b: Buffer) => { fs.writeSync(fd, b, 0, b.length, pos); pos += b.length; };
    const sealTake = (n: number) => {
      const all = Buffer.concat(pending);
      const slice = all.subarray(0, n);
      write(sealUploadChunk(key!, id, idx, slice, off + n === r.length));
      idx++;
      off += n;
      pending = n < all.length ? [all.subarray(n)] : [];
      pendingBytes -= n;
    };
    const flush = () => { if (enc && pendingBytes > 0) sealTake(pendingBytes); };
    const rollback = () => { fs.ftruncateSync(fd, r.fileSize); };
    try {
      fs.ftruncateSync(fd, r.fileSize); // restos de un trozo anterior que no llegó a registrarse
      try {
        for await (const chunk of source) {
          const c = Buffer.from(chunk.buffer, chunk.byteOffset, chunk.byteLength);
          if (off + pendingBytes + c.length > r.length) throw new FilesError('INVALID_INPUT', `más bytes que Upload-Length (${r.length})`);
          hash?.update(c);
          if (!enc) { write(c); off += c.length; continue; }
          pending.push(c);
          pendingBytes += c.length;
          while (pendingBytes >= FRAME_PLAIN_BYTES) sealTake(FRAME_PLAIN_BYTES);
        }
      } catch (e) {
        if (checksum || (e instanceof FilesError && e.code === 'INVALID_INPUT')) { rollback(); throw e; }
        flush(); // corte de red sin checksum: se conserva lo recibido
        fs.fsyncSync(fd);
        this.journal.uploadAdvance(id, r.offset, { offset: off, fileSize: pos, chunkIndex: idx });
        throw e;
      }
      if (hash && !hash.digest().equals(checksum!.digest)) {
        rollback();
        throw new FilesError('CHECKSUM_MISMATCH', 'Upload-Checksum no coincide con el trozo recibido');
      }
      flush();
      fs.fsyncSync(fd);
      if (!this.journal.uploadAdvance(id, r.offset, { offset: off, fileSize: pos, chunkIndex: idx })) {
        rollback();
        throw new FilesError('CONFLICT', `la subida ${id} cambió durante la escritura`);
      }
      return { offset: off, complete: off === r.length };
    } finally {
      fs.closeSync(fd);
      appending.delete(id);
    }
  }

  /** Contenido completo en streaming (texto en claro; en cifradas, trozo a trozo verificando el orden y el final). */
  read(id: string): AsyncIterable<Uint8Array> {
    const r = this.row(id);
    if (r.offset !== r.length) throw new FilesError('CONFLICT', `la subida ${id} no está completa (${r.offset}/${r.length})`);
    const file = this.dataPath(id);
    if (!this.encrypted()) return fs.createReadStream(file);
    const key = this.store.uploadKey(id);
    return (async function* () {
      const fd = fs.openSync(file, 'r');
      try {
        const readExact = (n: number, at: number) => {
          const b = Buffer.alloc(n);
          const got = fs.readSync(fd, b, 0, n, at);
          if (got !== n) throw new FilesError('INTEGRITY', 'subida cifrada truncada');
          return b;
        };
        if (!readExact(UPLOAD_MAGIC.length, 0).equals(UPLOAD_MAGIC)) throw new FilesError('INTEGRITY', 'subida cifrada: cabecera no válida');
        const size = fs.fstatSync(fd).size;
        let p = UPLOAD_MAGIC.length;
        let index = 0;
        let final = false;
        while (p < size) {
          if (final) throw new FilesError('INTEGRITY', 'subida cifrada: datos tras el trozo final');
          const len = readExact(4, p).readUInt32BE(0);
          if (len > FRAME_PLAIN_BYTES + 64) throw new FilesError('INTEGRITY', 'subida cifrada: trozo demasiado grande');
          const c = openUploadChunk(key, id, index, readExact(len, p + 4));
          final = c.final;
          yield c.plain;
          index++;
          p += 4 + len;
        }
        if (!final) throw new FilesError('INTEGRITY', 'subida cifrada: sin trozo final');
      } finally {
        fs.closeSync(fd);
      }
    })();
  }

  processing(id: string): void { this.journal.uploadSet(id, { status: 'processing' }); }

  finish(id: string, o: { documentId: string; operationId?: string }): void {
    this.journal.uploadSet(id, { status: 'done', documentId: o.documentId, operationId: o.operationId });
    this.removeFiles(id);
  }

  fail(id: string, errorCode: string): void {
    this.journal.uploadSet(id, { status: 'failed', errorCode });
    this.removeFiles(id);
  }

  terminate(id: string, owner?: string): void {
    this.row(id, owner);
    this.journal.uploadSet(id, { status: 'terminated' });
    this.removeFiles(id);
  }

  /** Subidas caducadas sin completar: fuera sus bytes. Devuelve cuántas. */
  gcExpired(): number {
    if (!fs.existsSync(this.dir)) return 0;
    const ids = this.journal.expiredUploads();
    for (const id of ids) {
      this.journal.uploadSet(id, { status: 'expired' });
      this.removeFiles(id);
    }
    return ids.length;
  }

  activeFor(owner: string): number { return this.journal.activeUploads(ownerHash(owner)); }

  private removeFiles(id: string): void {
    for (const f of [`${id}.part`, `${id}.svfu`, `${id}.meta`]) fs.rmSync(path.join(this.dir, f), { force: true });
  }
}
