// SE-413 F1 / SE-414 — almacén de ficheros por cúpula: originales inmutables direccionados
// por SHA-256, un manifiesto por documento (docs/<id>.json) con revisiones, extracciones
// ligadas a su revisión por digest, borrado real y lock entre procesos con espera.
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash, randomBytes } from 'node:crypto';
import { ensureSafeHome, writeAtomic } from '../rag/store.js';
import { acquireLock, releaseLock, exceedsDomeLevel } from '../rag/indexer.js';
import { RagError } from '../rag/types.js';
import {
  FilesError, type Confidentiality, type Extraction, type ExtractionInfo, type FileDocument,
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

export function defaultLimits(env: NodeJS.ProcessEnv = process.env): FilesLimits {
  return {
    maxBytes: envInt('SAVIA_FILES_MAX_BYTES', 100 * 1024 * 1024, env),
    maxDocuments: envInt('SAVIA_FILES_MAX_DOCS', 10_000, env),
    extractTimeoutMs: envInt('SAVIA_FILES_EXTRACT_TIMEOUT_MS', 300_000, env),
    maxTransferBytes: envInt('SAVIA_FILES_MAX_TRANSFER_BYTES', 20 * 1024 * 1024, env),
    maxUnzippedBytes: envInt('SAVIA_FILES_MAX_UNZIPPED_BYTES', 256 * 1024 * 1024, env),
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

export interface FileStoreOptions {
  home?: string;
  dome: string;
  domeLevel?: string;
  limits?: Partial<FilesLimits>;
  /** Espera máxima por el lock de escritura (def. SAVIA_FILES_LOCK_WAIT_MS o 10 s). */
  lockWaitMs?: number;
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
  private corrupt = 0;

  constructor(opts: FileStoreOptions) {
    if (!DOME_RE.test(opts.dome)) throw new FilesError('INVALID_INPUT', `cúpula no válida: ${opts.dome}`);
    this.home = path.resolve(opts.home ?? defaultFilesHome());
    this.dome = opts.dome;
    this.dir = path.join(this.home, opts.dome);
    this.limits = { ...defaultLimits(), ...opts.limits };
    this.domeLevel = opts.domeLevel ?? 'N2';
    this.lockWaitMs = opts.lockWaitMs ?? this.limits.lockWaitMs;
  }

  private get docsDir(): string { return path.join(this.dir, 'docs'); }
  private docPath(id: string): string { return path.join(this.docsDir, `${id}.json`); }

  /** Documentos legibles, por fecha de creación. Los corruptos se omiten y se cuentan (`corruptCount`). */
  list(): FileDocument[] {
    this.ensureMigrated();
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

  add(input: AddInput): { document: FileDocument; revision: FileRevision } {
    const name = sanitizeName(input.name);
    if (!Buffer.isBuffer(input.bytes)) throw new FilesError('INVALID_INPUT', 'bytes debe ser un Buffer');
    if (input.bytes.length > this.limits.maxBytes) {
      throw new FilesError('TOO_LARGE', `${input.bytes.length} bytes > límite ${this.limits.maxBytes}`);
    }
    const level = input.confidentiality?.toUpperCase();
    if (level !== undefined && !LEVELS.includes(level)) {
      throw new FilesError('INVALID_INPUT', `confidencialidad no válida: ${input.confidentiality}`);
    }
    if (exceedsDomeLevel(level, this.domeLevel)) {
      throw new FilesError('POLICY_DENIED', `confidencialidad ${level} superior a la cúpula (${this.domeLevel})`);
    }
    const tags = (input.tags ?? []).map((t) => String(t).trim()).filter(Boolean).slice(0, 32);
    return this.locked(() => {
      const prev = input.replaces ? this.readDoc(input.replaces) : undefined;
      const count = prev ? 0 : this.documentCount();
      if (!prev && count >= this.limits.maxDocuments) {
        throw new FilesError('LIMIT', `la cúpula ya tiene ${count} documentos`);
      }
      const hash = sha256(input.bytes);
      this.writeBlob(hash, input.bytes);
      const type = detectType(name, input.bytes);
      const now = new Date().toISOString();
      const revision: FileRevision = {
        id: newId('r'), sha256: hash, size: input.bytes.length, mime: mimeOf(type), type,
        ...(TEXT_TYPES.has(type) ? { encoding: textEncoding(input.bytes) } : {}),
        createdAt: now,
        extraction: type === 'unknown'
          ? { status: 'ARCHIVE_ONLY', method: 'none', units: 0, extracted: 0, skipped: [{ reason: 'unsupported-type', count: 1 }] }
          : { status: 'PENDING', method: 'none', units: 0, extracted: 0, skipped: [] },
      };
      let document: FileDocument;
      if (prev) {
        prev.name = name;
        if (input.tags) prev.tags = tags;
        if (level) prev.confidentiality = level as Confidentiality;
        prev.revisions.push(revision);
        prev.currentRevision = revision.id;
        prev.updatedAt = now;
        document = prev;
      } else {
        document = {
          id: newId('f'), name, tags, createdAt: now, updatedAt: now,
          currentRevision: revision.id, revisions: [revision],
          ...(level ? { confidentiality: level as Confidentiality } : {}),
        };
      }
      this.writeDoc(document);
      if (!prev) this.bumpCount(1, count);
      return { document, revision };
    });
  }

  /** Bytes del original, verificados contra su SHA-256. */
  readBytes(id: string, revisionId?: string): Buffer {
    const rev = this.revision(id, revisionId);
    if (rev.extraction.status === 'QUARANTINED') throw new FilesError('NOT_FOUND', `revisión ${rev.id} en cuarentena`);
    let bytes: Buffer;
    try {
      bytes = fs.readFileSync(this.blobPath(rev.sha256));
    } catch {
      throw new FilesError('NOT_FOUND', `bytes de ${rev.id} no disponibles`);
    }
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
      const content = JSON.stringify(extraction);
      fs.mkdirSync(path.join(this.dir, 'extract'), { recursive: true, mode: DIR_MODE });
      writeAtomic(this.extractPath(revisionId), content);
      rev.extraction = { ...(info ?? rev.extraction), digest: sha256(content) };
      this.writeDoc(doc);
    });
  }

  /** Unidades extraídas, verificadas contra el digest guardado en el documento. */
  readExtraction(revisionId: string, documentId?: string): Extraction {
    this.checkRevisionId(revisionId);
    const doc = this.docOfRevision(revisionId, documentId);
    const rev = doc.revisions.find((r) => r.id === revisionId)!;
    let content: string;
    try {
      content = fs.readFileSync(this.extractPath(revisionId), 'utf-8');
    } catch {
      throw new FilesError('NOT_FOUND', `sin extracción para ${revisionId}`);
    }
    if (rev.extraction.digest && sha256(content) !== rev.extraction.digest) {
      throw new FilesError('INTEGRITY', `la extracción de ${revisionId} no coincide con su digest`);
    }
    return JSON.parse(content) as Extraction;
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
        this.removeUnreferencedBlobs([rev.sha256]);
      }
    });
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
      this.removeUnreferencedBlobs([rev.sha256]);
    });
  }

  /** Borrado real: primero el documento (deja de existir), después bytes y extracciones. */
  delete(id: string): FileDocument {
    return this.locked(() => {
      const doc = this.readDoc(id);
      const count = this.documentCount();
      fs.rmSync(this.docPath(id), { force: true });
      docCache.delete(this.docPath(id));
      this.bumpCount(-1, count);
      for (const rev of doc.revisions) fs.rmSync(this.extractPath(rev.id), { force: true });
      this.removeUnreferencedBlobs(doc.revisions.map((r) => r.sha256));
      return doc;
    });
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
      const liveBlobs = new Set(revisions.filter((r) => r.extraction.status !== 'QUARANTINED').map((r) => r.sha256));
      const liveRevs = new Set(revisions.map((r) => `${r.id}.json`));
      const safe = this.corrupt === 0;
      const sweep = (sub: string, keep: (f: string) => boolean) => {
        const dir = path.join(this.dir, sub);
        if (!fs.existsSync(dir)) return 0;
        let n = 0;
        for (const f of fs.readdirSync(dir)) {
          if (keep(f)) continue;
          fs.rmSync(path.join(dir, f), { force: true });
          n++;
        }
        return n;
      };
      const tmpOnly = (f: string) => !f.includes('.tmp-');
      sweep('docs', (f) => !f.includes('.tmp-'));
      return {
        blobs: sweep('blobs', (f) => (safe ? liveBlobs.has(f) : tmpOnly(f))),
        extractions: sweep('extract', (f) => (safe ? liveRevs.has(f) : tmpOnly(f))),
      };
    });
  }

  private removeUnreferencedBlobs(hashes: string[]): void {
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
    let doc: FileDocument;
    try {
      doc = JSON.parse(fs.readFileSync(file, 'utf-8')) as FileDocument;
    } catch {
      throw new FilesError('INTEGRITY', `el manifiesto de ${id} está corrupto`);
    }
    if (doc?.id !== id || !Array.isArray(doc.revisions) || !doc.revisions.length) {
      throw new FilesError('INTEGRITY', `el manifiesto de ${id} está corrupto`);
    }
    docCache.set(file, { key, doc: deepFreeze(doc) });
    return mutable ? structuredClone(doc) : doc;
  }

  private writeDoc(doc: FileDocument): void {
    fs.mkdirSync(this.docsDir, { recursive: true, mode: DIR_MODE });
    writeAtomic(this.docPath(doc.id), JSON.stringify(doc));
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

  /** Lock de escritura entre procesos; espera hasta `lockWaitMs` con retroceso (SE-414 S6). Reentrante. */
  private locked<T>(fn: () => T): T {
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
    try {
      this.migrate();
      return fn();
    } finally {
      this.depth--;
      releaseLock(this.dir, LOCK_NAME);
    }
  }
}
