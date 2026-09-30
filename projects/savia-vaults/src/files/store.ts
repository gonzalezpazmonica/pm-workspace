// SE-413 F1 / SE-414 / SE-417 — almacén de ficheros por cúpula: originales inmutables, un
// manifiesto por documento (docs/<id>.json) con revisiones, extracciones ligadas a su revisión
// por digest, borrado real y lock entre procesos con espera. Cúpulas cifradas (SE-417): original
// y extracción con la DEK de la revisión, manifiesto sellado con la subclave `meta`, borrado
// criptográfico, sin deduplicación; nunca vuelven a claro.
// SE-418: el ledger git privado de la cúpula (`ledger/`) es la autoridad: cada sección de escritura
// es una operación del journal (node:sqlite) que termina en un commit con los manifiestos tocados y
// un receipt firmado. Un payload que no coincide con su manifiesto no se sirve (salvo que una
// operación pendiente lo esté escribiendo). Las operaciones cortadas se completan o cancelan al
// tomar el lock (reconciliador).
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash, randomBytes } from 'node:crypto';
import { ensureSafeHome, writeAtomic } from '../rag/store.js';
import { acquireLock, releaseLock, exceedsDomeLevel } from '../rag/indexer.js';
import { RagError } from '../rag/types.js';
import { KeyStore } from './keys.js';
import { canonicalJson, decryptStream, encryptStream, FRAME_PLAIN_BYTES, opaqueName, open, seal, StreamDecryptor, StreamEncryptor } from './crypto.js';
import { Readable, Transform } from 'node:stream';
import { Ledger, type LedgerManifest } from './ledger.js';
import { Journal, type OpRow, type OutboxEvent } from './journal.js';
import { ReceiptSigner, type Receipt, type ReceiptRef } from './receipts.js';
import {
  FilesError, type Confidentiality, type DocumentAcl, type Extraction, type ExtractionInfo, type FileDocument,
  type FileRevision, type FileType, type FilesLimits, type TextEncoding,
} from './types.js';

const LOCK_NAME = 'files.lock';
const DIR_MODE = 0o700;
const BLOB_MODE = 0o400;
const REVISION_RE = /^r_[0-9a-f]{16}$/;
const DOCUMENT_RE = /^f_[0-9a-f]{16}$/;
/** Controles, formato (bidi, zero-width, BOM) y separadores de línea/párrafo (SE-414 S3). */
const BAD_NAME_CHARS = /[/\\\p{Cc}\p{Cf}\u2028\u2029]/u;
const DOME_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
const LEVELS = ['N1', 'N2', 'N3', 'N4'];

const envInt = (name: string, def: number, env: NodeJS.ProcessEnv = process.env) => {
  const v = Number(env[name]);
  return Number.isFinite(v) && v > 0 ? v : def;
};

/** SE-421: tope absoluto de un fichero (10 GiB). */
export const MAX_BYTES_CAP = 10 * 1024 ** 3;

export function defaultLimits(env: NodeJS.ProcessEnv = process.env): FilesLimits {
  return {
    // SE-421: el almacén trabaja en streaming; por defecto 1 GiB, como mucho 10 GiB.
    maxBytes: Math.min(envInt('SAVIA_FILES_MAX_BYTES', 1024 ** 3, env), MAX_BYTES_CAP),
    maxDocuments: envInt('SAVIA_FILES_MAX_DOCS', 10_000, env),
    extractTimeoutMs: envInt('SAVIA_FILES_EXTRACT_TIMEOUT_MS', 300_000, env),
    maxTransferBytes: envInt('SAVIA_FILES_MAX_TRANSFER_BYTES', 20 * 1024 * 1024, env),
    maxUnzippedBytes: envInt('SAVIA_FILES_MAX_UNZIPPED_BYTES', 256 * 1024 * 1024, env),
    maxExtractBytes: envInt('SAVIA_FILES_MAX_EXTRACT_BYTES', 256 * 1024 * 1024, env),
    lockWaitMs: envInt('SAVIA_FILES_LOCK_WAIT_MS', 10_000, env),
  };
}

export function defaultFilesHome(): string {
  return process.env.SAVIA_FILES_HOME || path.join(os.homedir(), '.savia-vaults', 'files');
}

/** Nombre visible del fichero: nunca una ruta. La ruta física la decide el almacén. */
export function sanitizeName(name: string): string {
  const n = typeof name === 'string' ? name.normalize('NFC') : '';
  if (!n || n === '.' || n === '..' || BAD_NAME_CHARS.test(n) || Buffer.byteLength(n) > 255) {
    throw new FilesError('INVALID_INPUT', `nombre de fichero no válido: ${JSON.stringify(String(name).slice(0, 80))}`);
  }
  return n;
}

const MIME: Record<FileType, string> = {
  pdf: 'application/pdf',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  txt: 'text/plain', md: 'text/markdown', csv: 'text/csv', json: 'application/json',
  unknown: 'application/octet-stream',
};
const OOXML: Partial<Record<FileType, string>> = {
  docx: 'word/document.xml', pptx: 'ppt/presentation.xml', xlsx: 'xl/workbook.xml',
};
const TEXT_TYPES = new Set<FileType>(['txt', 'md', 'csv', 'json']);
const TEXT_EXT: Record<string, FileType> = { '.txt': 'txt', '.md': 'md', '.markdown': 'md', '.csv': 'csv', '.json': 'json' };

/** Bytes sin asignar en Windows-1252: si aparecen, no es ese juego de caracteres. */
const CP1252_UNDEFINED = new Set([0x81, 0x8d, 0x8f, 0x90, 0x9d]);

/**
 * SE-415 Q5: codificación de un fichero de texto. UTF-8 válido sin NUL; si no, Windows-1252
 * (exportaciones de Excel en español) cuando no hay NUL, controles salvo tab/salto/avance
 * de página, ni bytes sin asignar. En otro caso no es texto.
 */
export function textEncoding(bytes: Buffer): TextEncoding | undefined {
  if (bytes.includes(0)) return undefined;
  try { new TextDecoder('utf-8', { fatal: true }).decode(bytes); return 'utf-8'; } catch { /* no es UTF-8 */ }
  for (const b of bytes) {
    if ((b < 0x20 && b !== 0x09 && b !== 0x0a && b !== 0x0d && b !== 0x0c) || b === 0x7f || CP1252_UNDEFINED.has(b)) return undefined;
  }
  return 'windows-1252';
}

/** Tipo por extensión confirmado con la firma de los bytes; si no casan, 'unknown'. */
export function detectType(name: string, bytes: Buffer): FileType {
  const ext = path.extname(name).toLowerCase();
  if (ext === '.pdf') return bytes.subarray(0, 5).toString('latin1') === '%PDF-' ? 'pdf' : 'unknown';
  const office = ext.slice(1) as FileType;
  if (OOXML[office]) {
    const zip = bytes.subarray(0, 4).equals(Buffer.from([0x50, 0x4b, 0x03, 0x04]));
    return zip && bytes.includes(OOXML[office]!) ? office : 'unknown';
  }
  const text = TEXT_EXT[ext];
  if (text) return textEncoding(bytes) ? text : 'unknown';
  return 'unknown';
}

/**
 * SE-421: `detectType` + `textEncoding` sobre un stream, con el mismo resultado que sobre el
 * fichero entero (se prueba la equivalencia): cabecera, búsqueda de la entrada OOXML a través de
 * los trozos, UTF-8 incremental estricto y bytes prohibidos en Windows-1252.
 */
export class TypeSniffer {
  private readonly ext: string;
  private head = Buffer.alloc(0);
  private readonly needle: Buffer | undefined;
  private found = false;
  private tail = Buffer.alloc(0);
  private readonly text: boolean;
  private nul = false;
  private utf8 = true;
  private cp1252 = true;
  private readonly decoder = new TextDecoder('utf-8', { fatal: true });

  constructor(name: string) {
    this.ext = path.extname(name).toLowerCase();
    const office = OOXML[this.ext.slice(1) as FileType];
    this.needle = office ? Buffer.from(office) : undefined;
    this.text = !!TEXT_EXT[this.ext];
  }

  feed(chunk: Buffer): void {
    if (this.head.length < 8) this.head = Buffer.concat([this.head, chunk.subarray(0, 8 - this.head.length)]);
    if (this.needle && !this.found) {
      const window = Buffer.concat([this.tail, chunk]);
      if (window.includes(this.needle)) this.found = true;
      else this.tail = window.subarray(Math.max(0, window.length - (this.needle.length - 1)));
    }
    if (this.text) {
      if (!this.nul && chunk.includes(0)) this.nul = true;
      if (this.utf8) {
        try { this.decoder.decode(chunk, { stream: true }); } catch { this.utf8 = false; }
      }
      if (this.cp1252) {
        for (const b of chunk) {
          if ((b < 0x20 && b !== 0x09 && b !== 0x0a && b !== 0x0d && b !== 0x0c) || b === 0x7f || CP1252_UNDEFINED.has(b)) { this.cp1252 = false; break; }
        }
      }
    }
  }

  result(): { type: FileType; encoding?: TextEncoding } {
    if (this.ext === '.pdf') return { type: this.head.subarray(0, 5).toString('latin1') === '%PDF-' ? 'pdf' : 'unknown' };
    if (this.needle) {
      const zip = this.head.subarray(0, 4).equals(Buffer.from([0x50, 0x4b, 0x03, 0x04]));
      return { type: zip && this.found ? this.ext.slice(1) as FileType : 'unknown' };
    }
    const text = TEXT_EXT[this.ext];
    if (!text) return { type: 'unknown' };
    if (this.utf8) { try { this.decoder.decode(); } catch { this.utf8 = false; } }
    const encoding: TextEncoding | undefined = this.nul ? undefined : this.utf8 ? 'utf-8' : this.cp1252 ? 'windows-1252' : undefined;
    return encoding ? { type: text, encoding } : { type: 'unknown' };
  }
}

export function mimeOf(type: FileType): string {
  return MIME[type];
}

/** Formato del MVP (SE-413): un único manifest.json; se migra al primer acceso. */
interface LegacyManifest { version: 1; documents: FileDocument[] }

export interface AddInput {
  name: string;
  bytes: Buffer;
  tags?: string[];
  confidentiality?: string;
  replaces?: string;
}

/** SE-421: alta desde un stream (CLI, API HTTP): memoria acotada, sin cargar el fichero. */
export interface AddStreamInput {
  name: string;
  source: AsyncIterable<Uint8Array>;
  tags?: string[];
  confidentiality?: string;
  replaces?: string;
}

/** SE-421: lectura en streaming, entera (verificada al final) o por rango [start, end] inclusivo. */
export interface OpenedRead {
  stream: Readable;
  size: number;
  start: number;
  end: number;
  revision: FileRevision;
}

export interface FileStoreOptions {
  home?: string;
  dome: string;
  domeLevel?: string;
  limits?: Partial<FilesLimits>;
  /** Espera máxima por el lock de escritura (def. SAVIA_FILES_LOCK_WAIT_MS o 10 s). */
  lockWaitMs?: number;
  /** SE-417: la cúpula debe estar cifrada (se migra si no lo está). Una cúpula cifrada lo sigue siempre. */
  encrypt?: boolean;
  /** SE-417: dónde están las claves (def. `~/.savia-vaults/keys/files`). */
  keysHome?: string;
  /** SE-418: lease de una operación abierta (def. tiempo máximo de extracción + 60 s). */
  leaseMs?: number;
}

/** Sobre de un manifiesto sellado: en claro solo el id y la versión del formato. */
interface SealedDoc { id: string; v: 1; sealed: string }
const ENC_SUFFIX = '.svf';

/** SE-418: operación en curso de este almacén (explícita del servicio o implícita de una sección con lock). */
interface ActiveOp { id: string; kind: string; docs: Set<string>; explicit: boolean; idemKeyHash?: string; leaseUntil?: number }

export interface VerifyProblem { code: string; id?: string }
export interface VerifyReport { ok: boolean; documents: number; operations: number; receipts: number; problems: VerifyProblem[] }

/**
 * SE-421: temporal de un alta en streaming todavía en curso: `<…>.tmp-<pid>-<ms>` de un proceso vivo
 * de esta máquina y de menos de 24 h. `gc` no lo borra (ni la envoltura de su DEK).
 */
const TMP_RE = /\.tmp-(\d+)-(\d+)$/;
function inFlight(f: string): boolean {
  const m = TMP_RE.exec(f);
  if (!m || Date.now() - Number(m[2]) > 24 * 3600_000) return false;
  try { process.kill(Number(m[1]), 0); return true; } catch (e) { return (e as NodeJS.ErrnoException).code === 'EPERM'; }
}

const newId = (prefix: string) => `${prefix}_${randomBytes(8).toString('hex')}`;
const sha256 = (b: Buffer | string) => createHash('sha256').update(b).digest('hex');
const sleep = (ms: number) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

/**
 * Caché de documentos leídos, por fichero (inode + mtime + tamaño): `list` no re-parsea
 * lo que no cambió. Los documentos cacheados están congelados; quien muta pide una copia.
 */
const docCache = new Map<string, { key: string; doc: FileDocument }>();
/** Recuento de documentos por directorio `docs`, válido mientras no cambie su mtime. */
const countCache = new Map<string, { key: string; count: number }>();

function deepFreeze<T>(o: T): T {
  if (o && typeof o === 'object' && !Object.isFrozen(o)) {
    Object.freeze(o);
    for (const v of Object.values(o as object)) deepFreeze(v);
  }
  return o;
}

const statKey = (p: string) => {
  const st = fs.statSync(p, { bigint: true });
  return `${st.ino}:${st.mtimeNs}:${st.size}`;
};
const byCreation = (a: FileDocument, b: FileDocument) =>
  a.createdAt < b.createdAt ? -1 : a.createdAt > b.createdAt ? 1 : a.id < b.id ? -1 : a.id > b.id ? 1 : 0;

export class FileStore {
  readonly home: string;
  readonly dome: string;
  readonly dir: string;
  readonly limits: FilesLimits;
  private readonly domeLevel: string;
  private readonly lockWaitMs: number;
  private readonly wantEncrypt: boolean;
  readonly keys: KeyStore;
  private corrupt = 0;
  private migrating = false;
  /** SE-418 */
  readonly ledger: Ledger;
  private readonly signer: ReceiptSigner;
  private readonly leaseMs: number;
  private op: ActiveOp | undefined;
  private implicitKind = 'update';
  private importing = false;
  private ledgerChecked = false;

  constructor(opts: FileStoreOptions) {
    if (!DOME_RE.test(opts.dome)) throw new FilesError('INVALID_INPUT', `cúpula no válida: ${opts.dome}`);
    this.home = path.resolve(opts.home ?? defaultFilesHome());
    this.dome = opts.dome;
    this.dir = path.join(this.home, opts.dome);
    this.limits = { ...defaultLimits(), ...opts.limits };
    this.domeLevel = opts.domeLevel ?? 'N2';
    this.lockWaitMs = opts.lockWaitMs ?? this.limits.lockWaitMs;
    this.wantEncrypt = opts.encrypt === true;
    this.keys = new KeyStore({ home: opts.keysHome, dome: opts.dome });
    this.ledger = new Ledger(this.dir);
    this.signer = new ReceiptSigner(this.keys.home);
    this.leaseMs = opts.leaseMs ?? this.limits.extractTimeoutMs + 60_000;
  }

  // ── Cifrado (SE-417) ───────────────────────────────────────────────────

  private get markerPath(): string { return path.join(this.dir, 'encryption.json'); }

  /** true si la cúpula está cifrada (marca presente). Nunca se desactiva. */
  isEncrypted(): boolean {
    return fs.existsSync(this.markerPath);
  }

  /** SE-422: la cúpula está cifrada o se cifrará en la próxima escritura (N3/N4 u opt-in). */
  willEncrypt(): boolean {
    return this.isEncrypted() || this.wantEncrypt;
  }

  private sealing(): boolean {
    return this.migrating || this.isEncrypted();
  }

  private aad(documentId: string, revisionId: string, artifactKind: 'original' | 'extract') {
    return { schemaVersion: 1, domeId: this.dome, documentId, revisionId, artifactKind };
  }

  private metaAad(documentId: string) {
    return { schemaVersion: 1, domeId: this.dome, documentId, artifactKind: 'meta' };
  }

  private encBlobPath(revisionId: string): string {
    return path.join(this.dir, 'blobs', `${revisionId}${ENC_SUFFIX}`);
  }

  /**
   * Ruta a los bytes en claro para el worker o el antivirus. En cúpulas cifradas es una copia
   * en memoria (`/dev/shm`, 0700/0600) o, si no existe, en `<cúpula>/.work`; hay que liberarla
   * con `releasePlain`. En claro es el propio blob.
   */
  plainPath(documentId: string, revisionId?: string): string {
    const rev = this.revision(documentId, revisionId);
    if (!rev.enc) return this.blobPath(rev.sha256);
    const base = fs.existsSync('/dev/shm') ? '/dev/shm' : path.join(this.dir, '.work');
    fs.mkdirSync(base, { recursive: true, mode: DIR_MODE });
    const dir = fs.mkdtempSync(path.join(base, 'savia-files-'));
    fs.chmodSync(dir, DIR_MODE);
    const file = path.join(dir, 'original');
    // SE-421: descifrado frame a frame directamente a la copia (sin el fichero entero en memoria).
    try {
      const fd = fs.openSync(file, 'wx', 0o600);
      try {
        const h = createHash('sha256');
        this.decryptFileSync(documentId, rev, (plain) => { h.update(plain); fs.writeSync(fd, plain); });
        if (h.digest('hex') !== rev.sha256) throw new FilesError('INTEGRITY', `el blob de ${rev.id} no coincide con su SHA-256`);
      } finally {
        fs.closeSync(fd);
      }
    } catch (e) {
      fs.rmSync(dir, { recursive: true, force: true });
      throw e;
    }
    return file;
  }

  /** Borra una copia de `plainPath`; ignora las rutas que no son copias temporales. */
  releasePlain(file: string): void {
    const dir = path.dirname(file);
    if (/^savia-files-/.test(path.basename(dir)) && (path.dirname(dir) === '/dev/shm' || path.dirname(dir) === path.join(this.dir, '.work'))) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  }

  /** Cifra una cúpula en claro (o termina una migración cortada). Idempotente. */
  encryptExisting(): { documents: number; revisions: number } {
    return this.locked(() => {
      // Si locked() acaba de migrar por la política de la cúpula, ese es el informe.
      const auto = this.lastMigration;
      this.lastMigration = undefined;
      return auto ?? this.encryptExistingLocked();
    }, 'encrypt');
  }

  private lastMigration: { documents: number; revisions: number } | undefined;

  private encryptExistingLocked(): { documents: number; revisions: number } {
    this.keys.init();
    this.migrating = true;
    let documents = 0;
    let revisions = 0;
    try {
      for (const frozen of this.list()) {
        const d = this.readDoc(frozen.id);
        let changed = false;
        for (const rev of d.revisions) {
          if (rev.enc) continue;
          if (rev.extraction.status !== 'QUARANTINED') {
            const dek = this.keys.newDek({ documentId: d.id, revisionId: rev.id });
            rev.blobHash = this.encryptFileSync(this.blobPath(rev.sha256), rev.sha256, rev.id, dek, this.aad(d.id, rev.id, 'original'));
            const ex = this.extractPath(rev.id);
            if (fs.existsSync(ex)) {
              const content = fs.readFileSync(ex);
              if (rev.extraction.digest && sha256(content) !== rev.extraction.digest) {
                throw new FilesError('INTEGRITY', `la extracción de ${rev.id} no coincide con su digest; no se cifra`);
              }
              const sealed = seal(dek, content, this.aad(d.id, rev.id, 'extract'));
              writeAtomic(ex, sealed);
              rev.extraction = { ...rev.extraction, digest: sha256(sealed) };
            }
          }
          rev.enc = 1;
          revisions++;
          changed = true;
        }
        const raw = fs.readFileSync(this.docPath(d.id), 'utf-8');
        if (changed || !raw.includes('"sealed"')) this.writeDoc(d);
        if (changed) documents++;
      }
      if (!this.isEncrypted()) {
        writeAtomic(this.markerPath, JSON.stringify({ v: 1, since: new Date().toISOString(), kekId: this.keys.kekId() }));
      }
      // Originales en claro que ya tienen copia cifrada: fuera.
      const blobs = path.join(this.dir, 'blobs');
      for (const f of fs.existsSync(blobs) ? fs.readdirSync(blobs) : []) {
        if (!f.endsWith(ENC_SUFFIX) && !f.includes('.tmp-')) fs.rmSync(path.join(blobs, f), { force: true });
      }
    } finally {
      this.migrating = false;
    }
    return { documents, revisions };
  }

  /** SE-417 AC4: KEK nueva, DEK re-envueltas y manifiestos re-sellados. Reanudable. */
  rotateKeys(resealOthers?: () => void): void {
    this.locked(() => {
      if (!this.isEncrypted()) throw new FilesError('INVALID_INPUT', `la cúpula ${this.dome} no está cifrada`);
      this.keys.rotate(() => undefined, () => {
        for (const f of fs.existsSync(this.docsDir) ? fs.readdirSync(this.docsDir) : []) {
          const id = f.slice(0, -5);
          if (f.endsWith('.json') && DOCUMENT_RE.test(id)) this.writeDoc(this.readDoc(id));
        }
        resealOthers?.(); // p. ej. el índice RAG: aún se puede abrir con la clave anterior
      });
      writeAtomic(this.markerPath, JSON.stringify({ v: 1, since: new Date().toISOString(), kekId: this.keys.kekId() }));
    }, 'rotate');
  }

  private get docsDir(): string { return path.join(this.dir, 'docs'); }
  private docPath(id: string): string { return path.join(this.docsDir, `${id}.json`); }

  /** Documentos legibles, por fecha de creación. Los corruptos se omiten y se cuentan (`corruptCount`). */
  list(): FileDocument[] {
    this.ensureMigrated();
    if (this.isEncrypted()) this.keys.kek(); // KEY_MISSING antes que dar todo por corrupto
    let names: string[];
    try { names = fs.readdirSync(this.docsDir); } catch { this.corrupt = 0; return []; }
    const docs: FileDocument[] = [];
    let corrupt = 0;
    for (const f of names) {
      if (!f.endsWith('.json') || !DOCUMENT_RE.test(f.slice(0, -5))) continue;
      try { docs.push(this.readDoc(f.slice(0, -5), false)); } catch (e) {
        if (e instanceof FilesError && e.code === 'NOT_FOUND') continue; // borrado entre readdir y lectura
        corrupt++;
      }
    }
    this.corrupt = corrupt;
    return docs.sort(byCreation);
  }

  /** Documentos ilegibles (SE-414 AC7). Sin `fresh`, el recuento del último `list`. */
  corruptCount(fresh = true): number {
    if (fresh) this.list();
    return this.corrupt;
  }

  /** Documento congelado (solo lectura). */
  get(id: string): FileDocument {
    this.ensureMigrated();
    return this.readDoc(id, false);
  }

  /** Revisión congelada (solo lectura). */
  revision(id: string, revisionId?: string): FileRevision {
    const doc = this.get(id);
    const rev = doc.revisions.find((r) => r.id === (revisionId ?? doc.currentRevision));
    if (!rev) throw new FilesError('NOT_FOUND', `revisión ${revisionId} no existe en ${id}`);
    return rev;
  }

  /** Nombre, nivel y etiquetas validados, comunes a `add` y `addStream`. */
  private checkAdd(input: { name: string; tags?: string[]; confidentiality?: string }): { name: string; level?: string; tags: string[] } {
    const name = sanitizeName(input.name);
    const level = input.confidentiality?.toUpperCase();
    if (level !== undefined && !LEVELS.includes(level)) {
      throw new FilesError('INVALID_INPUT', `confidencialidad no válida: ${input.confidentiality}`);
    }
    if (exceedsDomeLevel(level, this.domeLevel)) {
      throw new FilesError('POLICY_DENIED', `confidencialidad ${level} superior a la cúpula (${this.domeLevel})`);
    }
    const tags = (input.tags ?? []).map((t) => String(t).trim()).filter(Boolean).slice(0, 32);
    return { name, level, tags };
  }

  /** Dentro del lock: documento previo (si sustituye) y límite de documentos. */
  private prepareRecord(replaces?: string): { prev?: FileDocument; count: number } {
    const prev = replaces ? this.readDoc(replaces) : undefined;
    const count = prev ? 0 : this.documentCount();
    if (!prev && count >= this.limits.maxDocuments) throw new FilesError('LIMIT', `la cúpula ya tiene ${count} documentos`);
    return { prev, count };
  }

  /** Dentro del lock y con el blob ya en su sitio: revisión nueva y documento escrito. */
  private recordRevision(o: {
    name: string; level?: string; tags: string[]; tagsGiven: boolean; prev?: FileDocument; count: number;
    documentId: string; revisionId: string; sha: string; size: number; type: FileType; encoding?: TextEncoding; blobHash?: string;
  }): { document: FileDocument; revision: FileRevision } {
    const now = new Date().toISOString();
    const revision: FileRevision = {
      id: o.revisionId, sha256: o.sha, size: o.size, mime: mimeOf(o.type), type: o.type,
      ...(o.blobHash ? { enc: 1 as const, blobHash: o.blobHash } : {}),
      ...(TEXT_TYPES.has(o.type) ? { encoding: o.encoding } : {}),
      createdAt: now,
      extraction: o.type === 'unknown'
        ? { status: 'ARCHIVE_ONLY', method: 'none', units: 0, extracted: 0, skipped: [{ reason: 'unsupported-type', count: 1 }] }
        : { status: 'PENDING', method: 'none', units: 0, extracted: 0, skipped: [] },
    };
    let document: FileDocument;
    if (o.prev) {
      o.prev.name = o.name;
      if (o.tagsGiven) o.prev.tags = o.tags;
      if (o.level) o.prev.confidentiality = o.level as Confidentiality;
      o.prev.revisions.push(revision);
      o.prev.currentRevision = revision.id;
      o.prev.updatedAt = now;
      document = o.prev;
    } else {
      document = {
        id: o.documentId, name: o.name, tags: o.tags, createdAt: now, updatedAt: now,
        currentRevision: revision.id, revisions: [revision],
        ...(o.level ? { confidentiality: o.level as Confidentiality } : {}),
      };
    }
    this.writeDoc(document);
    if (!o.prev) this.bumpCount(1, o.count);
    return { document, revision };
  }

  add(input: AddInput): { document: FileDocument; revision: FileRevision } {
    const { name, level, tags } = this.checkAdd(input);
    if (!Buffer.isBuffer(input.bytes)) throw new FilesError('INVALID_INPUT', 'bytes debe ser un Buffer');
    if (input.bytes.length > this.limits.maxBytes) {
      throw new FilesError('TOO_LARGE', `${input.bytes.length} bytes > límite ${this.limits.maxBytes}`);
    }
    return this.locked(() => {
      const { prev, count } = this.prepareRecord(input.replaces);
      const sha = sha256(input.bytes);
      const revisionId = newId('r');
      const documentId = prev?.id ?? newId('f');
      let blobHash: string | undefined;
      if (this.isEncrypted()) {
        const dek = this.keys.newDek({ documentId, revisionId });
        blobHash = this.writeEncBlob(revisionId, encryptStream(dek, input.bytes, this.aad(documentId, revisionId, 'original')));
      } else {
        this.writeBlob(sha, input.bytes);
      }
      const type = detectType(name, input.bytes);
      return this.recordRevision({
        name, level, tags, tagsGiven: !!input.tags, prev, count, documentId, revisionId, sha, size: input.bytes.length, type,
        encoding: TEXT_TYPES.has(type) ? textEncoding(input.bytes) : undefined, blobHash,
      });
    }, 'put');
  }

  /**
   * SE-421: alta en streaming. Los bytes se vuelcan a un temporal del almacén **fuera** del lock
   * (hash, tipo y, en cúpulas cifradas, SVF1 frame a frame), y dentro del lock solo se renombra y
   * se registra la revisión: un fichero de gigas no bloquea al resto de escrituras. Memoria ≈ 2 frames.
   */
  async addStream(input: AddStreamInput): Promise<{ document: FileDocument; revision: FileRevision }> {
    const { name, level, tags } = this.checkAdd(input);
    this.prepare();
    if (input.replaces) this.get(input.replaces); // NOT_FOUND antes de leer un byte
    const encrypted = this.isEncrypted();
    if (encrypted) this.keys.kek(); // KEY_MISSING: nunca se crea otra clave
    const encrypt = encrypted || this.wantEncrypt;
    if (encrypt && !encrypted) this.keys.init(); // la cúpula se cifrará al tomar el lock (SE-417)
    const revisionId = newId('r');
    const documentId = input.replaces ?? newId('f');
    const blobs = path.join(this.dir, 'blobs');
    fs.mkdirSync(blobs, { recursive: true, mode: DIR_MODE });
    const tmp = path.join(blobs, `${revisionId}.tmp-${process.pid}-${Date.now()}`);
    const hash = createHash('sha256');
    const cipherHash = encrypt ? createHash('sha256') : undefined;
    const sniff = new TypeSniffer(name);
    const enc = encrypt
      ? new StreamEncryptor(this.keys.newDek({ documentId, revisionId }), this.aad(documentId, revisionId, 'original'))
      : undefined;
    const fd = fs.openSync(tmp, 'wx', 0o600);
    const write = (b: Buffer) => { if (b.length) { fs.writeSync(fd, b); cipherHash?.update(b); } };
    let size = 0;
    let closed = false;
    const abort = () => {
      if (!closed) { fs.closeSync(fd); closed = true; }
      fs.rmSync(tmp, { force: true });
      if (enc) this.keys.destroyDek(revisionId);
    };
    try {
      if (enc) write(enc.header());
      let pending: Buffer[] = [];
      let pendingBytes = 0;
      for await (const chunk of input.source) {
        const c = Buffer.from(chunk.buffer, chunk.byteOffset, chunk.byteLength);
        size += c.length;
        if (size > this.limits.maxBytes) throw new FilesError('TOO_LARGE', `más de ${this.limits.maxBytes} bytes: límite de la cúpula`);
        hash.update(c);
        sniff.feed(c);
        if (!enc) { write(c); continue; }
        pending.push(c);
        pendingBytes += c.length;
        // Frames completos de 1 MiB; el resto espera: el último frame lleva TAG_FINAL.
        while (pendingBytes > FRAME_PLAIN_BYTES) {
          const all = Buffer.concat(pending);
          write(enc.push(all.subarray(0, FRAME_PLAIN_BYTES), false));
          pending = [all.subarray(FRAME_PLAIN_BYTES)];
          pendingBytes = pending[0].length;
        }
      }
      if (enc) write(enc.push(Buffer.concat(pending), true));
      fs.fsyncSync(fd);
      fs.closeSync(fd);
      closed = true;
    } catch (e) {
      abort();
      throw e;
    }
    fs.chmodSync(tmp, BLOB_MODE);
    const sha = hash.digest('hex');
    const blobHash = cipherHash?.digest('hex');
    const { type, encoding } = sniff.result();
    try {
      return this.locked(() => {
        if (this.isEncrypted() !== encrypt) {
          throw new FilesError('LOCKED', 'la cúpula cambió de cifrado durante la subida; repite la operación');
        }
        const { prev, count } = this.prepareRecord(input.replaces);
        if (enc) {
          fs.renameSync(tmp, this.encBlobPath(revisionId));
        } else if (fs.existsSync(this.blobPath(sha))) {
          fs.rmSync(tmp, { force: true }); // mismos bytes, mismo blob
        } else {
          fs.renameSync(tmp, this.blobPath(sha));
        }
        return this.recordRevision({
          name, level, tags, tagsGiven: !!input.tags, prev, count, documentId, revisionId, sha, size, type, encoding, blobHash,
        });
      }, 'put');
    } catch (e) {
      if (fs.existsSync(tmp)) abort();
      else if (enc && !this.docOfRevisionSafe(revisionId, documentId)) this.keys.destroyDek(revisionId);
      throw e;
    }
  }

  private docOfRevisionSafe(revisionId: string, documentId: string): boolean {
    try { return this.get(documentId).revisions.some((r) => r.id === revisionId); } catch { return false; }
  }

  /**
   * SE-421: lectura en streaming. Sin rango, verifica el SHA-256 al final (error INTEGRITY en el
   * stream si no casa). Con rango [start, end] (inclusivo): en cifradas cada frame va autenticado
   * pero se descifra desde el principio (secretstream no permite saltar); en claras no se verifica.
   */
  openRead(id: string, revisionId?: string, range?: { start: number; end?: number }): OpenedRead {
    const rev = this.revision(id, revisionId);
    if (rev.extraction.status === 'QUARANTINED') throw new FilesError('NOT_FOUND', `revisión ${rev.id} en cuarentena`);
    const file = rev.enc ? this.encBlobPath(rev.id) : this.blobPath(rev.sha256);
    if (!fs.existsSync(file)) throw new FilesError('NOT_FOUND', `bytes de ${rev.id} no disponibles`);
    const whole = !range;
    const start = range?.start ?? 0;
    const end = range?.end ?? rev.size - 1;
    if (range && (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start < 0 || end < start || end >= rev.size)) {
      throw new FilesError('INVALID_INPUT', `rango ${start}-${end} fuera del fichero (${rev.size} bytes)`);
    }
    const expected = rev.sha256;
    let stream: Readable;
    if (!rev.enc) {
      const raw = rev.size === 0 ? Readable.from([]) : fs.createReadStream(file, whole ? {} : { start, end });
      if (!whole) {
        stream = raw;
      } else {
        const h = createHash('sha256');
        stream = raw.pipe(new Transform({
          transform(chunk: Buffer, _e, cb) { h.update(chunk); cb(null, chunk); },
          flush(cb) { cb(h.digest('hex') === expected ? null : new FilesError('INTEGRITY', `el blob de ${rev.id} no coincide con su SHA-256`)); },
        }));
        raw.on('error', (e: Error) => stream.destroy(e));
      }
    } else {
      const dek = this.keys.dek({ documentId: id, revisionId: rev.id });
      const aad = this.aad(id, rev.id, 'original');
      stream = Readable.from((async function* () {
        const dec = new StreamDecryptor(dek, aad);
        const h = whole ? createHash('sha256') : undefined;
        let pos = 0;
        for await (const chunk of fs.createReadStream(file, { highWaterMark: FRAME_PLAIN_BYTES + 64 })) {
          for (const plain of dec.feed(chunk as Buffer)) {
            const from = pos;
            pos += plain.length;
            if (pos <= start) continue;
            const a = Math.max(0, start - from);
            const b = Math.min(plain.length, end - from + 1);
            if (b > a) {
              const out = plain.subarray(a, b);
              h?.update(out);
              yield out;
            }
            if (pos > end && !whole) return; // rango servido: no hace falta seguir
          }
        }
        dec.end();
        if (h && h.digest('hex') !== expected) throw new FilesError('INTEGRITY', `el blob de ${rev.id} no coincide con su SHA-256`);
      })());
    }
    return { stream, size: rev.size, start, end: Math.max(end, start - 1), revision: rev };
  }

  /**
   * SE-419: cambia nivel y listas de un documento (la autorización la hace el servicio).
   * Con `expectedVersion` distinta de la actual, CONFLICT.
   */
  setPolicy(id: string, patch: { confidentiality?: Confidentiality } & DocumentAcl, expectedVersion?: number): FileDocument {
    return this.locked(() => {
      const doc = this.readDoc(id);
      const current = doc.policyVersion ?? 0;
      if (expectedVersion !== undefined && expectedVersion !== current) {
        throw new FilesError('CONFLICT', `la política de ${id} cambió (versión ${current}, esperada ${expectedVersion})`);
      }
      if (patch.confidentiality !== undefined) {
        if (exceedsDomeLevel(patch.confidentiality, this.domeLevel)) {
          throw new FilesError('INVALID_INPUT', `confidencialidad ${patch.confidentiality} superior a la cúpula (${this.domeLevel})`);
        }
        doc.confidentiality = patch.confidentiality;
      }
      const acl: DocumentAcl = { ...doc.acl };
      if (patch.readers !== undefined) acl.readers = patch.readers;
      if (patch.writers !== undefined) acl.writers = patch.writers;
      if (acl.readers === null) delete acl.readers;
      if (acl.writers === null) delete acl.writers;
      if (Object.keys(acl).length) doc.acl = acl; else delete doc.acl;
      doc.policyVersion = current + 1;
      doc.updatedAt = new Date().toISOString();
      this.writeDoc(doc);
      return deepFreeze(doc);
    }, 'policy');
  }

  /**
   * Bytes del original en memoria, verificados contra su SHA-256. SE-421: solo hasta
   * `maxTransferBytes` (MCP en base64); para más, `openRead`.
   */
  readBytes(id: string, revisionId?: string): Buffer {
    const rev = this.revision(id, revisionId);
    if (rev.extraction.status === 'QUARANTINED') throw new FilesError('NOT_FOUND', `revisión ${rev.id} en cuarentena`);
    if (rev.size > this.limits.maxTransferBytes) {
      throw new FilesError('TOO_LARGE', `${rev.size} bytes > ${this.limits.maxTransferBytes} en memoria: usar la lectura en streaming (files get)`);
    }
    let bytes: Buffer;
    try {
      bytes = fs.readFileSync(rev.enc ? this.encBlobPath(rev.id) : this.blobPath(rev.sha256));
    } catch {
      throw new FilesError('NOT_FOUND', `bytes de ${rev.id} no disponibles`);
    }
    if (rev.enc) bytes = decryptStream(this.keys.dek({ documentId: id, revisionId: rev.id }), bytes, this.aad(id, rev.id, 'original'));
    if (sha256(bytes) !== rev.sha256) throw new FilesError('INTEGRITY', `el blob de ${rev.id} no coincide con su SHA-256`);
    return bytes;
  }

  blobPath(hash: string): string {
    return path.join(this.dir, 'blobs', hash);
  }

  /**
   * Guarda la extracción de una revisión y liga su digest al documento (SE-414 S5).
   * Con `documentId` no hace falta recorrer la cúpula para encontrar la revisión.
   */
  saveExtraction(revisionId: string, extraction: Extraction, info?: ExtractionInfo, documentId?: string): void {
    this.checkRevisionId(revisionId);
    this.locked(() => {
      const doc = this.docOfRevision(revisionId, documentId);
      const rev = doc.revisions.find((r) => r.id === revisionId)!;
      let content: Buffer = Buffer.from(JSON.stringify(extraction), 'utf-8');
      if (rev.enc) content = seal(this.keys.dek({ documentId: doc.id, revisionId }), content, this.aad(doc.id, revisionId, 'extract'));
      fs.mkdirSync(path.join(this.dir, 'extract'), { recursive: true, mode: DIR_MODE });
      writeAtomic(this.extractPath(revisionId), content);
      rev.extraction = { ...(info ?? rev.extraction), digest: sha256(content) };
      this.writeDoc(doc);
    }, 'extract');
  }

  /** Unidades extraídas, verificadas contra el digest guardado en el documento. */
  readExtraction(revisionId: string, documentId?: string): Extraction {
    this.checkRevisionId(revisionId);
    const doc = this.docOfRevision(revisionId, documentId);
    const rev = doc.revisions.find((r) => r.id === revisionId)!;
    let content: Buffer;
    try {
      content = fs.readFileSync(this.extractPath(revisionId));
    } catch {
      throw new FilesError('NOT_FOUND', `sin extracción para ${revisionId}`);
    }
    if (rev.extraction.digest && sha256(content) !== rev.extraction.digest) {
      throw new FilesError('INTEGRITY', `la extracción de ${revisionId} no coincide con su digest`);
    }
    if (rev.enc) content = open(this.keys.dek({ documentId: doc.id, revisionId }), content, this.aad(doc.id, revisionId, 'extract'));
    return JSON.parse(content.toString('utf-8')) as Extraction;
  }

  /** Cambia el estado de extracción de una revisión; QUARANTINED borra además sus bytes. */
  setExtraction(revisionId: string, info: ExtractionInfo, documentId?: string): void {
    this.checkRevisionId(revisionId);
    this.locked(() => {
      const doc = this.docOfRevision(revisionId, documentId);
      const rev = doc.revisions.find((r) => r.id === revisionId)!;
      rev.extraction = info;
      this.writeDoc(doc);
      if (info.status === 'QUARANTINED') {
        fs.rmSync(this.extractPath(revisionId), { force: true });
        this.removeRevisionBytes(rev);
      }
    }, 'extract');
  }

  /**
   * Deshace una revisión recién añadida que no llegó a aceptarse (p. ej. escaneo
   * obligatorio fallido): si era la única, borra el documento.
   */
  dropRevision(id: string, revisionId: string): void {
    const doc = this.get(id);
    if (doc.revisions.length === 1 && doc.revisions[0].id === revisionId) {
      this.delete(id);
      return;
    }
    this.locked(() => {
      const d = this.readDoc(id);
      const rev = d.revisions.find((r) => r.id === revisionId);
      if (!rev) throw new FilesError('NOT_FOUND', `revisión ${revisionId} no existe en ${id}`);
      d.revisions = d.revisions.filter((r) => r.id !== revisionId);
      if (d.currentRevision === revisionId) d.currentRevision = d.revisions[d.revisions.length - 1].id;
      this.writeDoc(d);
      fs.rmSync(this.extractPath(revisionId), { force: true });
      this.removeRevisionBytes(rev);
    }, 'rollback');
  }

  /** Borrado real: primero el documento (deja de existir), después bytes y extracciones. */
  delete(id: string): FileDocument {
    return this.locked(() => {
      const doc = this.readDoc(id);
      const count = this.documentCount();
      this.touch(id);
      fs.rmSync(this.docPath(id), { force: true });
      docCache.delete(this.docPath(id));
      this.bumpCount(-1, count);
      for (const rev of doc.revisions) fs.rmSync(this.extractPath(rev.id), { force: true });
      for (const rev of doc.revisions.filter((r) => r.enc)) this.removeRevisionBytes(rev);
      this.removeUnreferencedBlobs(doc.revisions.filter((r) => !r.enc).map((r) => r.sha256));
      return doc;
    }, 'delete');
  }

  /**
   * Limpia lo que una caída puede dejar: blobs y extracciones que ningún documento
   * referencia, y temporales `.tmp-*`. Con documentos corruptos no borra blobs: no
   * se puede saber si los referencian.
   */
  gc(): { blobs: number; extractions: number } {
    if (!fs.existsSync(this.dir)) return { blobs: 0, extractions: 0 };
    return this.locked(() => {
      const docs = this.list();
      const revisions = docs.flatMap((d) => d.revisions);
      const liveBlobs = new Set(revisions.filter((r) => r.extraction.status !== 'QUARANTINED').map((r) => (r.enc ? `${r.id}${ENC_SUFFIX}` : r.sha256)));
      const liveRevs = new Set(revisions.map((r) => `${r.id}.json`));
      const safe = this.corrupt === 0;
      const sweep = (sub: string, keep: (f: string) => boolean) => {
        const dir = path.join(this.dir, sub);
        if (!fs.existsSync(dir)) return 0;
        let n = 0;
        for (const f of fs.readdirSync(dir)) {
          if (keep(f) || inFlight(f)) continue; // SE-421: un alta en streaming en curso no se toca
          fs.rmSync(path.join(dir, f), { force: true });
          n++;
        }
        return n;
      };
      const tmpOnly = (f: string) => !f.includes('.tmp-');
      const inFlightRevs = new Set((fs.existsSync(path.join(this.dir, 'blobs')) ? fs.readdirSync(path.join(this.dir, 'blobs')) : [])
        .filter(inFlight).map((f) => f.split('.')[0]));
      sweep('docs', (f) => !f.includes('.tmp-'));
      // Envolturas de DEK sin revisión (caída entre crear la DEK y guardar el documento).
      const wraps = path.join(this.keys.dir, 'wraps');
      if (safe && fs.existsSync(wraps)) {
        const live = new Set(revisions.filter((r) => r.enc && r.extraction.status !== 'QUARANTINED').map((r) => `${r.id}.json`));
        for (const f of fs.readdirSync(wraps)) {
          if (!live.has(f) && f.endsWith('.json') && !inFlightRevs.has(f.slice(0, -5))) this.keys.destroyDek(f.slice(0, -5));
        }
      }
      return {
        blobs: sweep('blobs', (f) => (safe ? liveBlobs.has(f) : tmpOnly(f))),
        extractions: sweep('extract', (f) => (safe ? liveRevs.has(f) : tmpOnly(f))),
      };
    });
  }

  /** Bytes de una revisión: cifrada ⇒ blob propio + borrado criptográfico de su DEK; en claro ⇒ si nadie más lo usa. */
  private removeRevisionBytes(rev: FileRevision): void {
    if (rev.enc) {
      fs.rmSync(this.encBlobPath(rev.id), { force: true });
      this.keys.destroyDek(rev.id);
    } else {
      this.removeUnreferencedBlobs([rev.sha256]);
    }
  }

  private removeUnreferencedBlobs(hashes: string[]): void {
    if (!hashes.length) return;
    const docs = this.list();
    if (this.corrupt > 0) return; // sin saber qué referencian los corruptos, no se borra; `gc` lo retoma
    const live = new Set(
      docs.flatMap((d) => d.revisions).filter((r) => r.extraction.status !== 'QUARANTINED').map((r) => r.sha256),
    );
    for (const h of new Set(hashes)) if (!live.has(h)) fs.rmSync(this.blobPath(h), { force: true });
  }

  private docOfRevision(revisionId: string, documentId?: string): FileDocument {
    if (documentId) {
      const d = this.readDoc(documentId);
      if (!d.revisions.some((r) => r.id === revisionId)) throw new FilesError('NOT_FOUND', `revisión ${revisionId} no existe en ${documentId}`);
      return d;
    }
    const d = this.list().find((x) => x.revisions.some((r) => r.id === revisionId));
    if (!d) throw new FilesError('NOT_FOUND', `revisión ${revisionId} no existe`);
    return this.readDoc(d.id); // copia editable: lo de `list` está congelado
  }

  private documentCount(): number {
    let key: string;
    try { key = statKey(this.docsDir); } catch { return 0; }
    const hit = countCache.get(this.docsDir);
    if (hit && hit.key === key) return hit.count;
    const count = fs.readdirSync(this.docsDir).filter((f) => f.endsWith('.json') && !f.includes('.tmp-')).length;
    countCache.set(this.docsDir, { key, count });
    return count;
  }

  /** Ajusta el recuento cacheado tras una alta o baja propia (evita un readdir por escritura). */
  private bumpCount(delta: number, before: number): void {
    try { countCache.set(this.docsDir, { key: statKey(this.docsDir), count: before + delta }); } catch { countCache.delete(this.docsDir); }
  }

  /** Con `mutable` (def.) devuelve una copia editable; sin él, el objeto cacheado congelado. */
  private readDoc(id: string, mutable = true): FileDocument {
    if (typeof id !== 'string' || !DOCUMENT_RE.test(id)) throw new FilesError('NOT_FOUND', `documento ${String(id).slice(0, 40)} no existe en ${this.dome}`);
    const file = this.docPath(id);
    let st: fs.BigIntStats;
    try { st = fs.statSync(file, { bigint: true }); } catch {
      throw new FilesError('NOT_FOUND', `documento ${id} no existe en ${this.dome}`);
    }
    const key = `${st.ino}:${st.mtimeNs}:${st.size}`;
    const hit = docCache.get(file);
    if (hit && hit.key === key) return mutable ? structuredClone(hit.doc) : hit.doc;
    let bytes: Buffer;
    try {
      bytes = fs.readFileSync(file);
    } catch {
      throw new FilesError('NOT_FOUND', `documento ${id} no existe en ${this.dome}`);
    }
    this.checkAuthority(id, bytes);
    const doc = this.parseDoc(id, bytes);
    docCache.set(file, { key, doc: deepFreeze(doc) });
    return mutable ? structuredClone(doc) : doc;
  }

  /** Payload de un documento, sin comprobar el ledger (lo usan el ledger y verify). */
  private parseDoc(id: string, bytes: Buffer): FileDocument {
    let doc: FileDocument;
    let raw: FileDocument | SealedDoc;
    try {
      raw = JSON.parse(bytes.toString('utf-8')) as FileDocument | SealedDoc;
    } catch {
      throw new FilesError('INTEGRITY', `el manifiesto de ${id} está corrupto`);
    }
    if ('sealed' in raw) {
      if (raw.id !== id) throw new FilesError('INTEGRITY', `el manifiesto de ${id} está corrupto`);
      doc = JSON.parse(this.openMeta(id, Buffer.from(raw.sealed, 'base64')).toString('utf-8')) as FileDocument;
    } else {
      doc = raw;
    }
    if (doc?.id !== id || !Array.isArray(doc.revisions) || !doc.revisions.length) {
      throw new FilesError('INTEGRITY', `el manifiesto de ${id} está corrupto`);
    }
    return doc;
  }

  private writeDoc(doc: FileDocument): void {
    this.touch(doc.id); // antes de escribir: los lectores ven la operación pendiente
    fs.mkdirSync(this.docsDir, { recursive: true, mode: DIR_MODE });
    const body: FileDocument | SealedDoc = this.sealing()
      ? { id: doc.id, v: 1, sealed: seal(this.keys.subkey('meta')!, Buffer.from(JSON.stringify(doc)), this.metaAad(doc.id)).toString('base64') }
      : doc;
    writeAtomic(this.docPath(doc.id), JSON.stringify(body));
  }

  /** Abre un manifiesto sellado con la subclave actual o, durante una rotación, la anterior. */
  private openMeta(id: string, sealed: Buffer): Buffer {
    try {
      return open(this.keys.subkey('meta')!, sealed, this.metaAad(id));
    } catch (e) {
      const prev = this.keys.subkey('meta', 'prev');
      if (!prev || !(e instanceof FilesError) || e.code !== 'INTEGRITY') throw e;
      return open(prev, sealed, this.metaAad(id));
    }
  }

  /** SE-421: descifra un original frame a frame (síncrono), entregando el texto en claro por trozos. */
  private decryptFileSync(documentId: string, rev: FileRevision, onPlain: (b: Buffer) => void): void {
    const dec = new StreamDecryptor(this.keys.dek({ documentId, revisionId: rev.id }), this.aad(documentId, rev.id, 'original'));
    const fd = fs.openSync(this.encBlobPath(rev.id), 'r');
    try {
      const buf = Buffer.alloc(FRAME_PLAIN_BYTES + 64);
      let n: number;
      while ((n = fs.readSync(fd, buf, 0, buf.length, null)) > 0) for (const p of dec.feed(buf.subarray(0, n))) onPlain(p);
      dec.end();
    } finally {
      fs.closeSync(fd);
    }
  }

  /** SE-421: cifra un blob en claro a SVF1 en streaming, verificando su SHA-256; devuelve el hash del cifrado. */
  private encryptFileSync(src: string, expectedSha: string, revisionId: string, dek: Uint8Array, aad: object): string {
    const enc = new StreamEncryptor(dek, aad);
    const out = this.encBlobPath(revisionId);
    const tmp = `${out}.tmp-${process.pid}-${Date.now()}`;
    const plainHash = createHash('sha256');
    const cipherHash = createHash('sha256');
    const fdIn = fs.openSync(src, 'r');
    const fdOut = fs.openSync(tmp, 'wx', 0o600);
    const write = (b: Buffer) => { if (b.length) { fs.writeSync(fdOut, b); cipherHash.update(b); } };
    try {
      write(enc.header());
      const buf = Buffer.alloc(FRAME_PLAIN_BYTES);
      let prev: Buffer | undefined;
      let n: number;
      while ((n = fs.readSync(fdIn, buf, 0, buf.length, null)) > 0) {
        const chunk = Buffer.from(buf.subarray(0, n));
        plainHash.update(chunk);
        if (prev) write(enc.push(prev, false));
        prev = chunk;
      }
      write(enc.push(prev ?? Buffer.alloc(0), true));
      fs.fsyncSync(fdOut);
    } catch (e) {
      fs.closeSync(fdOut);
      fs.rmSync(tmp, { force: true });
      throw e;
    } finally {
      fs.closeSync(fdIn);
    }
    fs.closeSync(fdOut);
    if (plainHash.digest('hex') !== expectedSha) {
      fs.rmSync(tmp, { force: true });
      throw new FilesError('INTEGRITY', `el blob de ${revisionId} no coincide con su SHA-256; no se cifra`);
    }
    fs.chmodSync(tmp, BLOB_MODE);
    fs.renameSync(tmp, out);
    return cipherHash.digest('hex');
  }

  /** Escribe el blob cifrado y devuelve su SHA-256 (el del cifrado: es lo que va al ledger). */
  private writeEncBlob(revisionId: string, data: Buffer): string {
    fs.mkdirSync(path.join(this.dir, 'blobs'), { recursive: true, mode: DIR_MODE });
    const file = this.encBlobPath(revisionId);
    const tmp = `${file}.tmp-${process.pid}-${Date.now()}`;
    fs.writeFileSync(tmp, data, { mode: 0o600 });
    fs.chmodSync(tmp, BLOB_MODE);
    fs.renameSync(tmp, file);
    return sha256(data);
  }

  /** SE-414 AC8: reparte el manifest.json del MVP en un fichero por documento, una vez. */
  private ensureMigrated(): void {
    if (fs.existsSync(path.join(this.dir, 'manifest.json'))) this.locked(() => undefined);
  }

  private migrate(): void {
    const legacyPath = path.join(this.dir, 'manifest.json');
    if (!fs.existsSync(legacyPath)) return;
    let legacy: LegacyManifest;
    try {
      legacy = JSON.parse(fs.readFileSync(legacyPath, 'utf-8')) as LegacyManifest;
    } catch {
      throw new FilesError('INTEGRITY', `manifest.json del MVP corrupto en ${this.dome}; no se migra`);
    }
    for (const doc of legacy.documents ?? []) {
      for (const rev of doc.revisions) {
        const ex = this.extractPath(rev.id);
        if (!rev.extraction.digest && fs.existsSync(ex)) rev.extraction.digest = sha256(fs.readFileSync(ex, 'utf-8'));
      }
      this.writeDoc(doc);
    }
    let target = path.join(this.dir, 'manifest.json.migrated');
    if (fs.existsSync(target)) target = `${target}-${Date.now()}`;
    fs.renameSync(legacyPath, target);
  }

  private checkRevisionId(revisionId: string): void {
    if (!REVISION_RE.test(revisionId)) throw new FilesError('INVALID_INPUT', `revisionId no válido: ${String(revisionId).slice(0, 40)}`);
  }

  private extractPath(revisionId: string): string {
    return path.join(this.dir, 'extract', `${revisionId}.json`);
  }

  private writeBlob(hash: string, bytes: Buffer): void {
    const blobs = path.join(this.dir, 'blobs');
    fs.mkdirSync(blobs, { recursive: true, mode: DIR_MODE });
    const file = this.blobPath(hash);
    if (fs.existsSync(file)) return; // direccionado por contenido: mismos bytes, mismo blob
    const tmp = `${file}.tmp-${process.pid}-${Date.now()}`;
    fs.writeFileSync(tmp, bytes, { mode: 0o600 });
    fs.chmodSync(tmp, BLOB_MODE);
    fs.renameSync(tmp, file);
  }

  private prepare(): void {
    try {
      ensureSafeHome(this.home);
    } catch (e) {
      if (e instanceof RagError && e.code === 'UNSAFE_HOME') {
        throw new FilesError('UNSAFE_HOME', `SAVIA_FILES_HOME (${this.home}) está dentro de un repo git`);
      }
      throw e;
    }
    fs.mkdirSync(this.dir, { recursive: true, mode: DIR_MODE });
    fs.chmodSync(this.dir, DIR_MODE);
  }

  private depth = 0;

  /**
   * Lock de escritura entre procesos; espera hasta `lockWaitMs` con retroceso (SE-414 S6). Reentrante.
   * SE-418: la sección más externa sin operación explícita es una operación implícita (`kind`) que,
   * si tocó documentos, termina en un commit del ledger.
   */
  private locked<T>(fn: () => T, kind = 'update'): T {
    if (this.depth > 0) return fn();
    this.prepare();
    const deadline = Date.now() + this.lockWaitMs;
    let pause = 25;
    while (!acquireLock(this.dir, LOCK_NAME)) {
      if (Date.now() >= deadline) throw new FilesError('LOCKED', `otra escritura en curso en ${this.dome}`);
      sleep(Math.min(pause, Math.max(1, deadline - Date.now())));
      pause = Math.min(pause * 2, 200);
    }
    this.depth++;
    const outer = this.op;
    try {
      this.migrate();
      if (this.isEncrypted()) this.keys.kek(); // KEY_MISSING: nunca se crea otra clave en una cúpula cifrada
      this.ensureLedger();
      this.reconcile();
      if (!this.isEncrypted() && this.wantEncrypt) {
        // SE-417: N3/N4 u opt-in ⇒ se cifra al primer acceso (operación propia si no hay otra abierta)
        this.implicitKind = 'encrypt';
        this.lastMigration = this.encryptExistingLocked();
        if (this.op && !this.op.explicit && this.op !== outer) this.finishImplicit();
      }
      if (this.op?.explicit && Date.now() > (this.op.leaseUntil ?? 0) - this.leaseMs / 2) {
        // Renueva el lease solo cuando ha consumido la mitad (no un fsync por sección).
        this.journal().extend(this.op.id, this.leaseMs);
        this.op.leaseUntil = Date.now() + this.leaseMs;
      }
      this.implicitKind = kind;
      const r = fn();
      if (this.op && !this.op.explicit) this.finishImplicit();
      return r;
    } catch (e) {
      if (this.op && !this.op.explicit) {
        // El estado en disco es el que es: el ledger debe reflejarlo aunque la sección fallara.
        try { this.finishImplicit(); } catch { /* queda pendiente: el reconciliador la completa */ }
      }
      throw e;
    } finally {
      this.depth--;
      releaseLock(this.dir, LOCK_NAME);
    }
  }

  // ── Ledger, journal y receipts (SE-418) ──────────────────────────────────

  private get ledgerMarker(): string { return path.join(this.dir, 'ledger.json'); }

  /** true cuando el ledger existe y ya importó los documentos previos: desde entonces manda. */
  ledgerReady(): boolean {
    return fs.existsSync(this.ledgerMarker);
  }

  /** SE-422: journal de la cúpula para el estado de las subidas reanudables. */
  uploadJournal(): Journal {
    this.prepare();
    return this.journal();
  }

  /** SE-422: clave de una subida parcial cifrada (derivada de la subclave `name`; rotar invalida las subidas en curso). */
  uploadKey(uploadId: string): Buffer {
    return Buffer.from(opaqueName(this.keys.subkey('name')!, `upload:${uploadId}`), 'hex');
  }

  private journal(): Journal {
    const { journal, created } = Journal.open(this.dir);
    if (created && this.ledgerReady()) {
      // Journal nuevo, borrado o corrupto: se reconstruye desde los intents del ledger.
      journal.importCommitted(this.ledger.intents().map((i) => ({
        operationId: i.operationId, kind: i.kind, commitSha: i.commitSha, at: i.at, documents: i.documents,
        idemKeyHash: i.idemKeyHash, errorCode: i.errorCode,
      })));
    }
    return journal;
  }

  /** Crea el ledger e importa los documentos existentes (operación `import`). Reanudable. */
  private ensureLedger(): void {
    if (this.ledgerReady()) {
      if (!this.ledgerChecked) { this.ledger.assertPrivate(); this.ledgerChecked = true; }
      return;
    }
    this.ledger.init();
    this.importing = true;
    try {
      const operationId = newId('o');
      const ids: string[] = [];
      for (const f of fs.existsSync(this.docsDir) ? fs.readdirSync(this.docsDir) : []) {
        const id = f.slice(0, -5);
        if (!f.endsWith('.json') || !DOCUMENT_RE.test(id)) continue;
        const bytes = fs.readFileSync(this.docPath(id));
        try {
          this.ledger.writeManifest(this.manifestOf(this.parseDoc(id, bytes), bytes));
          ids.push(id);
        } catch { /* ilegible: no entra; verify lo reporta */ }
      }
      const at = new Date().toISOString();
      this.ledger.writeIntent({ operationId, kind: 'import', at, documents: ids });
      const commitSha = this.ledger.commit(`import ${operationId}`);
      writeAtomic(this.ledgerMarker, JSON.stringify({ v: 1, importedAt: at, operationId, commitSha }));
      this.ledgerChecked = true;
      this.journal(); // se crea y se puebla desde los intents (incluido el import)
    } finally {
      this.importing = false;
    }
  }

  /** Manifiesto compacto del ledger: ids, hashes y estados. En cúpulas cifradas, ni tipo ni tamaño. */
  private manifestOf(doc: FileDocument, payload: Buffer): LedgerManifest {
    return {
      schemaVersion: 1, documentId: doc.id, currentRevision: doc.currentRevision, metaHash: sha256(payload),
      revisions: doc.revisions.map((r) => ({
        revisionId: r.id,
        blob: r.enc ? (r.blobHash ?? this.fileHash(this.encBlobPath(r.id))) : r.sha256,
        ...(r.enc ? {} : { size: r.size, type: r.type }),
        extraction: { status: r.extraction.status, ...(r.extraction.digest ? { digest: r.extraction.digest } : {}) },
      })),
    };
  }

  private fileHash(file: string): string {
    try { return sha256(fs.readFileSync(file)); } catch { return ''; }
  }

  /** Registra el documento en la operación en curso (o abre una implícita). Antes de escribirlo. */
  private touch(id: string): void {
    if (this.importing || !this.ledgerReady()) return;
    if (!this.op) {
      const operationId = newId('o');
      this.journal().begin({ operationId, kind: this.implicitKind, leaseMs: this.leaseMs });
      this.op = { id: operationId, kind: this.implicitKind, docs: new Set(), explicit: false };
    }
    if (!this.op.docs.has(id)) {
      this.op.docs.add(id);
      this.journal().touch(this.op.id, id);
    }
  }

  /** El payload leído debe coincidir con su manifiesto del ledger. */
  private checkAuthority(id: string, payload: Buffer): void {
    if (this.importing || !this.ledgerReady()) return;
    const m = this.ledger.readManifest(id);
    if (m && m.metaHash === sha256(payload)) return;
    if (this.op?.docs.has(id) || this.journal().pendingFor(id)) return; // una operación lo está escribiendo
    if (!m) throw new FilesError('NOT_FOUND', `documento ${id} no existe en ${this.dome}`);
    throw new FilesError('INTEGRITY', `el documento ${id} no coincide con el ledger de ${this.dome} (modificado fuera de Savia)`);
  }

  /**
   * Lleva al ledger el estado en disco de los documentos: manifiesto, o tombstone si ya no existe.
   * Devuelve las revisiones aún PENDING (evento `extract` del outbox).
   */
  private syncLedger(ids: string[], operationId: string): ReceiptRef[] {
    const now = new Date().toISOString();
    const pending: ReceiptRef[] = [];
    for (const id of ids) {
      let bytes: Buffer | undefined;
      try { bytes = fs.readFileSync(this.docPath(id)); } catch { bytes = undefined; }
      if (bytes) {
        let doc: FileDocument;
        try { doc = this.parseDoc(id, bytes); } catch { continue; } // ilegible: el manifiesto anterior se queda; lectura y verify dan INTEGRITY
        this.ledger.writeManifest(this.manifestOf(doc, bytes));
        for (const r of doc.revisions) if (r.extraction.status === 'PENDING') pending.push({ documentId: id, revisionId: r.id });
      } else if (this.ledger.readManifest(id)) {
        this.ledger.removeManifest(id);
        this.ledger.writeTombstone({ documentId: id, deletedAt: now, operationId });
      }
    }
    return pending;
  }

  /** Commit de la operación + receipt firmado + eventos del outbox. */
  private commitOp(op: ActiveOp, o: { refs?: ReceiptRef[]; errorCode?: string; recovered?: boolean } = {}): Receipt {
    const ids = [...op.docs].sort();
    const pending = this.syncLedger(ids, op.id);
    const at = new Date().toISOString();
    let commitSha: string | undefined;
    if (ids.length || !o.errorCode) {
      this.ledger.writeIntent({
        operationId: op.id, kind: op.kind, at, documents: ids,
        ...(op.idemKeyHash ? { idempotencyKeyHash: op.idemKeyHash } : {}),
        ...(o.errorCode ? { errorCode: o.errorCode } : {}), ...(o.recovered ? { recovered: true as const } : {}),
      });
      commitSha = this.ledger.commit(`${op.kind} ${op.id}${o.recovered ? ' (recuperada)' : ''}`);
    }
    return this.finalizeOp(op, ids, at, commitSha, o, pending);
  }

  private finalizeOp(
    op: ActiveOp, ids: string[], at: string, commitSha: string | undefined, o: { refs?: ReceiptRef[]; errorCode?: string }, pending: ReceiptRef[],
  ): Receipt {
    const refs = o.refs ?? ids.map((documentId) => ({ documentId }));
    const base = { operationId: op.id, dome: this.dome, kind: op.kind, ...(refs.length ? { refs } : {}), at };
    if (o.errorCode) {
      const receipt = this.signer.sign({ ...base, status: 'failed', errorCode: o.errorCode, commitSha });
      this.journal().fail(op.id, o.errorCode, receipt, commitSha);
      return receipt;
    }
    const manifestHash = ids.length ? this.ledger.manifestHash(ids) : undefined;
    const receipt = this.signer.sign({ ...base, status: 'committed', commitSha, manifestHash });
    const events: { event: string; payload: unknown }[] = [];
    if (ids.length) events.push({ event: 'rag-sync', payload: {} });
    if (pending.length) events.push({ event: 'extract', payload: { refs: pending } });
    this.journal().commit(op.id, { commitSha, manifestHash, receipt, events });
    return receipt;
  }

  /** Revisiones PENDING de documentos ya confirmados (reconciliación de un journal sin cerrar). */
  private pendingOf(ids: string[]): ReceiptRef[] {
    const refs: ReceiptRef[] = [];
    for (const id of ids) {
      try {
        for (const r of this.parseDoc(id, fs.readFileSync(this.docPath(id))).revisions) {
          if (r.extraction.status === 'PENDING') refs.push({ documentId: id, revisionId: r.id });
        }
      } catch { /* borrado o ilegible */ }
    }
    return refs;
  }

  private finishImplicit(): void {
    const op = this.op!;
    this.op = undefined;
    try {
      this.commitOp(op);
    } catch (e) {
      this.journal().release(op.id);
      throw e;
    }
  }

  /** Completa o cancela las operaciones pendientes cuyo dueño ya no está (caída, COMMIT_PENDING). */
  private reconcile(): void {
    if (!this.ledgerReady()) return;
    const j = this.journal();
    if (!j.pendingCount()) return;
    for (const row of j.stalePending()) {
      if (row.operationId === this.op?.id) continue;
      const op: ActiveOp = { id: row.operationId, kind: row.kind, docs: new Set(j.documents(row.operationId)), explicit: false, idemKeyHash: row.idemKeyHash };
      if (this.ledger.intentCommitted(row.operationId)) {
        // Commit hecho, journal sin cerrar: solo falta el receipt.
        const ids = [...op.docs].sort();
        this.finalizeOp(op, ids, new Date().toISOString(), this.ledger.intentCommit(row.operationId), {}, this.pendingOf(ids));
      } else if (op.docs.size) {
        this.commitOp(op, { recovered: true });
      } else {
        this.finalizeOp(op, [], new Date().toISOString(), undefined, { errorCode: 'ABORTED' }, []);
      }
    }
  }

  /**
   * Abre una operación explícita (put, delete, reprocess…) que puede abarcar varias secciones con
   * lock y trabajo asíncrono (extracción). Con `idempotencyKey` ya usada devuelve su receipt.
   */
  beginOperation(kind: string, o: { idempotencyKey?: string; request?: unknown } = {}): { operationId: string; replay?: Receipt } {
    if (this.op) throw new FilesError('LOCKED', `ya hay una operación abierta en ${this.dome}`);
    if (o.idempotencyKey !== undefined && (typeof o.idempotencyKey !== 'string' || !o.idempotencyKey || o.idempotencyKey.length > 200)) {
      throw new FilesError('INVALID_INPUT', 'idempotencyKey debe ser un texto de 1 a 200 caracteres');
    }
    return this.locked(() => {
      const idemKeyHash = o.idempotencyKey ? sha256(`savia-files-idem\n${this.dome}\n${o.idempotencyKey}`) : undefined;
      const requestHash = o.request === undefined ? undefined : sha256(canonicalJson(o.request));
      const operationId = newId('o');
      const { existing } = this.journal().begin({ operationId, kind, idemKeyHash, requestHash, leaseMs: this.leaseMs });
      if (existing) {
        if (existing.kind !== kind || (existing.requestHash && requestHash && existing.requestHash !== requestHash)) {
          throw new FilesError('IDEMPOTENCY_CONFLICT', 'esa idempotencyKey ya se usó con otra petición');
        }
        if (existing.status === 'pending') throw new FilesError('LOCKED', `la operación ${existing.operationId} con esa idempotencyKey sigue en curso`);
        return { operationId: existing.operationId, replay: this.receiptOf(existing) };
      }
      this.op = { id: operationId, kind, docs: new Set(), explicit: true, idemKeyHash, leaseUntil: Date.now() + this.leaseMs };
      return { operationId };
    }, kind);
  }

  /** Cierra la operación explícita: commit + receipt. Si git falla, COMMIT_PENDING con el operationId. */
  finishOperation(o: { refs?: ReceiptRef[]; errorCode?: string } = {}): Receipt {
    const op = this.op;
    if (!op?.explicit) throw new FilesError('INVALID_INPUT', 'no hay operación abierta');
    return this.locked(() => {
      try {
        return this.commitOp(op, o);
      } catch (e) {
        this.journal().release(op.id);
        if (e instanceof FilesError && e.code === 'COMMIT_PENDING') {
          throw new FilesError('COMMIT_PENDING', `${e.message.replace(/^COMMIT_PENDING: /, '')}; operación ${op.id} pendiente: se completará en el siguiente acceso`);
        }
        throw e;
      } finally {
        this.op = undefined;
      }
    });
  }

  /** Receipt de una operación (el guardado o, si el journal se reconstruyó, uno nuevo con lo que hay). */
  receiptOf(row: OpRow): Receipt {
    const stored = this.journal().receipt(row.operationId);
    if (stored) return stored;
    const refs = this.journal().documents(row.operationId).map((documentId) => ({ documentId }));
    return this.signer.sign({
      operationId: row.operationId, dome: this.dome, kind: row.kind, ...(refs.length ? { refs } : {}), status: row.status,
      ...(row.status === 'committed' && row.commitSha ? { commitSha: row.commitSha } : {}),
      ...(row.errorCode ? { errorCode: row.errorCode } : {}), at: row.updatedAt,
    });
  }

  /** Estado de una operación y su receipt. */
  operation(operationId: string): { operation: OpRow; receipt?: Receipt } {
    if (!this.ledgerReady()) throw new FilesError('NOT_FOUND', `operación ${String(operationId).slice(0, 40)} no existe`);
    const row = this.journal().get(operationId);
    if (!row) throw new FilesError('NOT_FOUND', `operación ${String(operationId).slice(0, 40)} no existe`);
    return { operation: row, ...(row.status === 'pending' ? {} : { receipt: this.receiptOf(row) }) };
  }

  operations(limit = 50): OpRow[] {
    return this.ledgerReady() ? this.journal().list(Math.max(1, Math.min(limit, 1000))) : [];
  }

  // Outbox (al menos una vez): el servicio consume los eventos.
  dueEvents(event?: string): OutboxEvent[] { return this.ledgerReady() ? this.journal().due(event) : []; }
  claimEvent(id: number, leaseMs = this.leaseMs): boolean { return this.journal().claim(id, leaseMs); }
  eventDone(id: number): void { this.journal().done(id); }
  eventRetry(id: number, attempts: number): void { this.journal().retry(id, Math.min(60_000 * 2 ** attempts, 3_600_000)); }

  /** Termina las operaciones cortadas (se hace solo en cada escritura; útil tras restaurar). */
  recover(): { pending: number } {
    this.locked(() => undefined, 'recover');
    return { pending: this.ledgerReady() ? this.journal().pendingCount() : 0 };
  }

  /** SE-418: comprueba ledger, payloads, blobs, journal y receipts. `deep` rehace los hashes de los blobs. */
  verify(o: { deep?: boolean } = {}): VerifyReport {
    const problems: VerifyProblem[] = [];
    if (!this.ledgerReady()) {
      const docs = fs.existsSync(this.docsDir) ? fs.readdirSync(this.docsDir).filter((f) => f.endsWith('.json')).length : 0;
      return { ok: docs === 0, documents: docs, operations: 0, receipts: 0, problems: docs ? [{ code: 'NO_LEDGER' }] : [] };
    }
    const j = this.journal();
    if (!j.quickCheck()) problems.push({ code: 'JOURNAL_CORRUPT' });
    if (!this.ledger.fsck()) problems.push({ code: 'LEDGER_FSCK' });
    try { this.ledger.assertPrivate(); } catch { problems.push({ code: 'LEDGER_REMOTE' }); }
    for (const r of j.stalePending()) problems.push({ code: 'STALE_OPERATION', id: r.operationId });
    if (!j.pendingCount()) for (const f of this.ledger.dirty()) problems.push({ code: 'LEDGER_DIRTY', id: f });
    const manifests = this.ledger.manifestIds();
    for (const id of manifests) {
      let bytes: Buffer;
      try { bytes = fs.readFileSync(this.docPath(id)); } catch { problems.push({ code: 'MISSING_PAYLOAD', id }); continue; }
      const m = this.ledger.readManifest(id)!;
      if (m.metaHash !== sha256(bytes) && !j.pendingFor(id)) problems.push({ code: 'PAYLOAD_MISMATCH', id });
      for (const r of m.revisions) {
        if (r.extraction.status === 'QUARANTINED') continue;
        const file = this.isEncryptedRev(r) ? this.encBlobPath(r.revisionId) : this.blobPath(r.blob);
        if (!fs.existsSync(file)) problems.push({ code: 'MISSING_BLOB', id: r.revisionId });
        else if (o.deep && this.fileHash(file) !== r.blob) problems.push({ code: 'BLOB_MISMATCH', id: r.revisionId });
      }
    }
    const tracked = new Set(manifests);
    for (const f of fs.existsSync(this.docsDir) ? fs.readdirSync(this.docsDir) : []) {
      const id = f.slice(0, -5);
      if (f.endsWith('.json') && DOCUMENT_RE.test(id) && !tracked.has(id) && !j.pendingFor(id)) problems.push({ code: 'UNTRACKED_PAYLOAD', id });
    }
    const receipts = j.receipts();
    for (const r of receipts) {
      if (!this.signer.verify(r)) problems.push({ code: 'BAD_RECEIPT', id: r.operationId });
      else if (r.commitSha && !this.ledger.hasCommit(r.commitSha)) problems.push({ code: 'RECEIPT_COMMIT_MISSING', id: r.operationId });
    }
    return { ok: problems.length === 0, documents: manifests.length, operations: j.list(1_000_000).length, receipts: receipts.length, problems };
  }

  /** En el manifiesto de una cúpula cifrada la revisión no lleva tipo ni tamaño. */
  private isEncryptedRev(r: LedgerManifest['revisions'][number]): boolean {
    return r.type === undefined;
  }
}
