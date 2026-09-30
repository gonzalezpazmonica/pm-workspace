// SE-413 F1 — almacén de ficheros por cúpula: originales inmutables direccionados por
// SHA-256, manifiesto atómico con revisiones, extracciones por revisión y borrado real.
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash, randomBytes } from 'node:crypto';
import { ensureSafeHome, writeAtomic } from '../rag/store.js';
import { acquireLock, releaseLock, exceedsDomeLevel } from '../rag/indexer.js';
import { RagError } from '../rag/types.js';
import {
  FilesError, type Confidentiality, type Extraction, type ExtractionInfo, type FileDocument,
  type FileRevision, type FileType, type FilesLimits,
} from './types.js';

const LOCK_NAME = 'files.lock';
const DIR_MODE = 0o700;
const BLOB_MODE = 0o400;
const REVISION_RE = /^r_[0-9a-f]{16}$/;
const DOME_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
const LEVELS = ['N1', 'N2', 'N3', 'N4'];

const envInt = (name: string, def: number) => {
  const v = Number(process.env[name]);
  return Number.isFinite(v) && v > 0 ? v : def;
};

export function defaultLimits(): FilesLimits {
  return {
    maxBytes: envInt('SAVIA_FILES_MAX_BYTES', 100 * 1024 * 1024),
    maxDocuments: envInt('SAVIA_FILES_MAX_DOCS', 10_000),
    extractTimeoutMs: envInt('SAVIA_FILES_EXTRACT_TIMEOUT_MS', 300_000),
    maxTransferBytes: envInt('SAVIA_FILES_MAX_TRANSFER_BYTES', 20 * 1024 * 1024),
  };
}

export function defaultFilesHome(): string {
  return process.env.SAVIA_FILES_HOME || path.join(os.homedir(), '.savia-vaults', 'files');
}

/** Nombre visible del fichero: nunca una ruta. La ruta física la decide el almacén. */
export function sanitizeName(name: string): string {
  const n = typeof name === 'string' ? name.normalize('NFC') : '';
  if (!n || n === '.' || n === '..' || /[/\\\u0000-\u001f\u007f]/.test(n) || Buffer.byteLength(n) > 255) {
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
const TEXT_EXT: Record<string, FileType> = { '.txt': 'txt', '.md': 'md', '.markdown': 'md', '.csv': 'csv', '.json': 'json' };

function isUtf8Text(bytes: Buffer): boolean {
  if (bytes.includes(0)) return false;
  try { new TextDecoder('utf-8', { fatal: true }).decode(bytes); return true; } catch { return false; }
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
  if (text) return isUtf8Text(bytes) ? text : 'unknown';
  return 'unknown';
}

export function mimeOf(type: FileType): string {
  return MIME[type];
}

interface Manifest { version: 1; documents: FileDocument[] }

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
}

const newId = (prefix: string) => `${prefix}_${randomBytes(8).toString('hex')}`;
const sha256 = (b: Buffer) => createHash('sha256').update(b).digest('hex');

export class FileStore {
  readonly home: string;
  readonly dome: string;
  readonly dir: string;
  readonly limits: FilesLimits;
  private readonly domeLevel: string;

  constructor(opts: FileStoreOptions) {
    if (!DOME_RE.test(opts.dome)) throw new FilesError('INVALID_INPUT', `cúpula no válida: ${opts.dome}`);
    this.home = path.resolve(opts.home ?? defaultFilesHome());
    this.dome = opts.dome;
    this.dir = path.join(this.home, opts.dome);
    this.limits = { ...defaultLimits(), ...opts.limits };
    this.domeLevel = opts.domeLevel ?? 'N2';
  }

  list(): FileDocument[] {
    return this.load().documents;
  }

  get(id: string): FileDocument {
    const doc = this.load().documents.find((d) => d.id === id);
    if (!doc) throw new FilesError('NOT_FOUND', `documento ${id} no existe en ${this.dome}`);
    return doc;
  }

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
      const manifest = this.load();
      const prev = input.replaces ? manifest.documents.find((d) => d.id === input.replaces) : undefined;
      if (input.replaces && !prev) throw new FilesError('NOT_FOUND', `documento ${input.replaces} no existe`);
      if (!prev && manifest.documents.length >= this.limits.maxDocuments) {
        throw new FilesError('LIMIT', `la cúpula ya tiene ${manifest.documents.length} documentos`);
      }
      const hash = sha256(input.bytes);
      this.writeBlob(hash, input.bytes);
      const type = detectType(name, input.bytes);
      const now = new Date().toISOString();
      const revision: FileRevision = {
        id: newId('r'), sha256: hash, size: input.bytes.length, mime: mimeOf(type), type, createdAt: now,
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
        manifest.documents.push(document);
      }
      this.save(manifest);
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

  saveExtraction(revisionId: string, extraction: Extraction, info?: ExtractionInfo): void {
    this.checkRevisionId(revisionId);
    this.locked(() => {
      const manifest = this.load();
      const rev = manifest.documents.flatMap((d) => d.revisions).find((r) => r.id === revisionId);
      if (!rev) throw new FilesError('NOT_FOUND', `revisión ${revisionId} no existe`);
      fs.mkdirSync(path.join(this.dir, 'extract'), { recursive: true, mode: DIR_MODE });
      writeAtomic(this.extractPath(revisionId), JSON.stringify(extraction));
      if (info) {
        rev.extraction = info;
        this.save(manifest);
      }
    });
  }

  readExtraction(revisionId: string): Extraction {
    this.checkRevisionId(revisionId);
    try {
      return JSON.parse(fs.readFileSync(this.extractPath(revisionId), 'utf-8')) as Extraction;
    } catch {
      throw new FilesError('NOT_FOUND', `sin extracción para ${revisionId}`);
    }
  }

  /** Cambia el estado de extracción de una revisión; QUARANTINED borra además sus bytes. */
  setExtraction(revisionId: string, info: ExtractionInfo): void {
    this.checkRevisionId(revisionId);
    this.locked(() => {
      const manifest = this.load();
      const rev = manifest.documents.flatMap((d) => d.revisions).find((r) => r.id === revisionId);
      if (!rev) throw new FilesError('NOT_FOUND', `revisión ${revisionId} no existe`);
      rev.extraction = info;
      this.save(manifest);
      if (info.status === 'QUARANTINED') {
        fs.rmSync(this.extractPath(revisionId), { force: true });
        this.removeUnreferencedBlobs(manifest, [rev.sha256], revisionId);
      }
    });
  }

  /** Borrado real: primero el manifiesto (deja de existir), después bytes y extracciones. */
  delete(id: string): FileDocument {
    return this.locked(() => {
      const manifest = this.load();
      const doc = manifest.documents.find((d) => d.id === id);
      if (!doc) throw new FilesError('NOT_FOUND', `documento ${id} no existe en ${this.dome}`);
      manifest.documents = manifest.documents.filter((d) => d.id !== id);
      this.save(manifest);
      for (const rev of doc.revisions) fs.rmSync(this.extractPath(rev.id), { force: true });
      this.removeUnreferencedBlobs(manifest, doc.revisions.map((r) => r.sha256));
      return doc;
    });
  }

  private removeUnreferencedBlobs(manifest: Manifest, hashes: string[], exceptRevision?: string): void {
    const live = new Set(
      manifest.documents.flatMap((d) => d.revisions)
        .filter((r) => r.id !== exceptRevision && r.extraction.status !== 'QUARANTINED')
        .map((r) => r.sha256),
    );
    for (const h of new Set(hashes)) if (!live.has(h)) fs.rmSync(this.blobPath(h), { force: true });
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

  private load(): Manifest {
    try {
      const m = JSON.parse(fs.readFileSync(path.join(this.dir, 'manifest.json'), 'utf-8')) as Manifest;
      return Array.isArray(m.documents) ? m : { version: 1, documents: [] };
    } catch (e) {
      if ((e as NodeJS.ErrnoException).code === 'ENOENT') return { version: 1, documents: [] };
      throw e;
    }
  }

  private save(manifest: Manifest): void {
    writeAtomic(path.join(this.dir, 'manifest.json'), JSON.stringify(manifest, null, 1));
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

  private locked<T>(fn: () => T): T {
    this.prepare();
    if (!acquireLock(this.dir, LOCK_NAME)) throw new FilesError('LOCKED', `otra escritura en curso en ${this.dome}`);
    try {
      return fn();
    } finally {
      releaseLock(this.dir, LOCK_NAME);
    }
  }
}
