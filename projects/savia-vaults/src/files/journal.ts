// SE-418 — journal de operaciones de Savia Files (node:sqlite, WAL, synchronous=FULL).
// No es una segunda autoridad: guarda lo que aún no está en el ledger (operaciones pendientes,
// con lease y proceso dueño), el outbox (eventos al menos una vez) y los receipts. Si se pierde o
// se corrompe se aparta y se reconstruye desde los intents del ledger. Nada sensible: ids,
// códigos de error y hashes; nunca nombres, texto ni mensajes libres.
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { FilesError } from './types.js';
import type { Receipt } from './receipts.js';

export type OpStatus = 'pending' | 'committed' | 'failed';

export interface OpRow {
  operationId: string;
  kind: string;
  status: OpStatus;
  idemKeyHash?: string;
  requestHash?: string;
  commitSha?: string;
  manifestHash?: string;
  errorCode?: string;
  pid?: number;
  host?: string;
  leaseUntil: number;
  createdAt: string;
  updatedAt: string;
}

export interface OutboxEvent { id: number; operationId: string; event: string; payload: unknown; attempts: number }

const SCHEMA_VERSION = 2; // v2 (SE-422): subidas reanudables y tokens de un solo uso
const ERROR_CODE_RE = /^[A-Z][A-Z_]{1,31}$/;
const HOST = os.hostname();

const SCHEMA = `
CREATE TABLE IF NOT EXISTS operations (
  operation_id TEXT PRIMARY KEY, kind TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending','committed','failed')),
  idem_key_hash TEXT UNIQUE, request_hash TEXT, commit_sha TEXT, manifest_hash TEXT, error_code TEXT,
  pid INTEGER, host TEXT, lease_until INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS op_documents (
  operation_id TEXT NOT NULL, document_id TEXT NOT NULL, PRIMARY KEY (operation_id, document_id));
CREATE INDEX IF NOT EXISTS op_documents_doc ON op_documents (document_id);
CREATE TABLE IF NOT EXISTS outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT, operation_id TEXT NOT NULL, event TEXT NOT NULL, payload TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0, next_at INTEGER NOT NULL DEFAULT 0,
  UNIQUE (operation_id, event));
CREATE TABLE IF NOT EXISTS receipts (operation_id TEXT PRIMARY KEY, receipt TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS uploads (
  upload_id TEXT PRIMARY KEY, owner_hash TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('receiving','processing','done','failed','terminated','expired')),
  length INTEGER NOT NULL, offset INTEGER NOT NULL DEFAULT 0, file_size INTEGER NOT NULL DEFAULT 0,
  chunk_index INTEGER NOT NULL DEFAULT 0, expires_at INTEGER NOT NULL,
  document_id TEXT, operation_id TEXT, error_code TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS uploads_owner ON uploads (owner_hash, status);
CREATE TABLE IF NOT EXISTS used_tokens (jti TEXT PRIMARY KEY, used_at TEXT NOT NULL);
`;

export type UploadStatus = 'receiving' | 'processing' | 'done' | 'failed' | 'terminated' | 'expired';

export interface UploadRow {
  uploadId: string;
  ownerHash: string;
  status: UploadStatus;
  length: number;
  offset: number;
  fileSize: number;
  chunkIndex: number;
  expiresAt: number;
  documentId?: string;
  operationId?: string;
  errorCode?: string;
}

type Row = Record<string, string | number | null>;
const opt = <T>(v: T | null | undefined) => (v === null || v === undefined ? undefined : v);
const toOp = (r: Row): OpRow => ({
  operationId: String(r.operation_id), kind: String(r.kind), status: r.status as OpStatus,
  idemKeyHash: opt(r.idem_key_hash as string), requestHash: opt(r.request_hash as string),
  commitSha: opt(r.commit_sha as string), manifestHash: opt(r.manifest_hash as string),
  errorCode: opt(r.error_code as string), pid: opt(r.pid as number), host: opt(r.host as string),
  leaseUntil: Number(r.lease_until), createdAt: String(r.created_at), updatedAt: String(r.updated_at),
});

function alive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (e) {
    return (e as NodeJS.ErrnoException).code === 'EPERM';
  }
}

const cache = new Map<string, { ino: number; journal: Journal }>();

export class Journal {
  private constructor(private readonly db: DatabaseSync, readonly file: string) {}

  /**
   * Abre (o crea) `<dir>/journal.db`. `created` indica que empieza vacío (nuevo, borrado o
   * corrupto): quien lo abre debe reconstruirlo desde el ledger.
   */
  static open(dir: string): { journal: Journal; created: boolean } {
    const file = path.join(dir, 'journal.db');
    const exists = fs.existsSync(file);
    const hit = cache.get(file);
    if (hit && exists && fs.statSync(file).ino === hit.ino) return { journal: hit.journal, created: false };
    if (hit) { try { hit.journal.db.close(); } catch { /* ya cerrado */ } cache.delete(file); }
    let created = !exists;
    let j: Journal;
    try {
      j = Journal.connect(file);
    } catch {
      const stamp = new Date().toISOString().replace(/[:.]/g, '-');
      for (const s of ['', '-wal', '-shm']) {
        if (fs.existsSync(file + s)) fs.renameSync(file + s, `${file}.corrupt-${stamp}${s}`);
      }
      j = Journal.connect(file);
      created = true;
    }
    cache.set(file, { ino: fs.statSync(file).ino, journal: j });
    return { journal: j, created };
  }

  private static connect(file: string): Journal {
    if (!fs.existsSync(file)) fs.writeFileSync(file, '', { mode: 0o600 });
    fs.chmodSync(file, 0o600);
    const db = new DatabaseSync(file);
    try {
      db.exec('PRAGMA busy_timeout = 5000');
      const check = db.prepare('PRAGMA quick_check').get() as Row | undefined;
      if (!check || Object.values(check)[0] !== 'ok') throw new Error('quick_check');
      db.exec('PRAGMA journal_mode = WAL');
      db.exec('PRAGMA synchronous = FULL');
      const version = Number((db.prepare('PRAGMA user_version').get() as Row).user_version);
      if (version > SCHEMA_VERSION) throw new FilesError('UNSUPPORTED', `journal.db con esquema ${version}, más nuevo que esta versión de Savia`);
      if (version < SCHEMA_VERSION) {
        db.exec('BEGIN IMMEDIATE');
        db.exec(SCHEMA);
        db.exec(`PRAGMA user_version = ${SCHEMA_VERSION}`);
        db.exec('COMMIT');
      }
    } catch (e) {
      try { db.close(); } catch { /* nada */ }
      if (e instanceof FilesError) throw e;
      throw new Error('journal corrupto');
    }
    return new Journal(db, file);
  }

  /** Cierra todos los journals abiertos (tests). */
  static closeAll(): void {
    for (const { journal } of cache.values()) { try { journal.db.close(); } catch { /* ya cerrado */ } }
    cache.clear();
  }

  pragma(name: 'journal_mode' | 'synchronous'): string | number {
    return Object.values(this.db.prepare(`PRAGMA ${name}`).get() as Row)[0] as string | number;
  }

  private tx<T>(fn: () => T): T {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const r = fn();
      this.db.exec('COMMIT');
      return r;
    } catch (e) {
      this.db.exec('ROLLBACK');
      throw e;
    }
  }

  /** Registra una operación pendiente; con una clave de idempotencia ya usada devuelve la existente. */
  begin(o: { operationId: string; kind: string; idemKeyHash?: string; requestHash?: string; leaseMs: number; pid?: number }): { existing?: OpRow } {
    return this.tx(() => {
      if (o.idemKeyHash) {
        const r = this.db.prepare('SELECT * FROM operations WHERE idem_key_hash = ?').get(o.idemKeyHash) as Row | undefined;
        if (r) return { existing: toOp(r) };
      }
      const now = new Date().toISOString();
      this.db.prepare(`INSERT INTO operations (operation_id, kind, status, idem_key_hash, request_hash, pid, host, lease_until, created_at, updated_at)
        VALUES (?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?)`).run(
        o.operationId, o.kind, o.idemKeyHash ?? null, o.requestHash ?? null, o.pid ?? process.pid, HOST, Date.now() + o.leaseMs, now, now);
      return {};
    });
  }

  /**
   * Escrituras frecuentes y recuperables (documentos tocados, lease, reclamación del outbox): con
   * `synchronous=NORMAL` en WAL son durables frente a la caída del proceso sin un fsync por fila; el
   * siguiente cambio de estado (begin/commit/fail, en FULL) las lleva al disco. El payload tampoco
   * se escribe con fsync: exigir más al journal que a lo que describe no añade garantía.
   */
  private relaxed<T>(fn: () => T): T {
    this.db.exec('PRAGMA synchronous = NORMAL');
    try { return fn(); } finally { this.db.exec('PRAGMA synchronous = FULL'); }
  }

  private insertDocument(operationId: string, documentId: string): void {
    this.db.prepare('INSERT OR IGNORE INTO op_documents (operation_id, document_id) VALUES (?, ?)').run(operationId, documentId);
  }

  touch(operationId: string, documentId: string): void {
    this.relaxed(() => this.insertDocument(operationId, documentId));
  }

  documents(operationId: string): string[] {
    return (this.db.prepare('SELECT document_id FROM op_documents WHERE operation_id = ? ORDER BY document_id').all(operationId) as Row[])
      .map((r) => String(r.document_id));
  }

  /** true si una operación pendiente (de este u otro proceso) está modificando el documento. */
  pendingFor(documentId: string): boolean {
    return !!this.db.prepare(`SELECT 1 FROM op_documents d JOIN operations o USING (operation_id)
      WHERE d.document_id = ? AND o.status = 'pending' LIMIT 1`).get(documentId);
  }

  extend(operationId: string, leaseMs: number): void {
    this.relaxed(() => this.db.prepare("UPDATE operations SET lease_until = ? WHERE operation_id = ? AND status = 'pending'").run(Date.now() + leaseMs, operationId));
  }

  /** Suelta el lease: el reconciliador puede completarla ya (COMMIT_PENDING). */
  release(operationId: string): void {
    this.db.prepare("UPDATE operations SET lease_until = 0 WHERE operation_id = ? AND status = 'pending'").run(operationId);
  }

  get(operationId: string): OpRow | undefined {
    const r = this.db.prepare('SELECT * FROM operations WHERE operation_id = ?').get(operationId) as Row | undefined;
    return r ? toOp(r) : undefined;
  }

  /** Pendientes cuyo dueño ya no las atiende: lease vencido o proceso muerto en esta máquina. */
  stalePending(): OpRow[] {
    const now = Date.now();
    return (this.db.prepare("SELECT * FROM operations WHERE status = 'pending' ORDER BY created_at").all() as Row[])
      .map(toOp)
      .filter((r) => r.leaseUntil < now || (r.host === HOST && r.pid !== undefined && !alive(r.pid)));
  }

  pendingCount(): number {
    return Number((this.db.prepare("SELECT count(*) AS n FROM operations WHERE status = 'pending'").get() as Row).n);
  }

  commit(operationId: string, o: { commitSha?: string; manifestHash?: string; receipt: Receipt; events: { event: string; payload: unknown }[] }): void {
    this.tx(() => {
      this.db.prepare(`UPDATE operations SET status = 'committed', commit_sha = ?, manifest_hash = ?, lease_until = 0, updated_at = ?
        WHERE operation_id = ?`).run(o.commitSha ?? null, o.manifestHash ?? null, new Date().toISOString(), operationId);
      this.db.prepare('INSERT OR REPLACE INTO receipts (operation_id, receipt) VALUES (?, ?)').run(operationId, JSON.stringify(o.receipt));
      for (const e of o.events) {
        this.db.prepare('INSERT OR IGNORE INTO outbox (operation_id, event, payload) VALUES (?, ?, ?)').run(operationId, e.event, JSON.stringify(e.payload));
      }
    });
  }

  fail(operationId: string, errorCode: string, receipt: Receipt, commitSha?: string): void {
    if (!ERROR_CODE_RE.test(errorCode)) throw new FilesError('INVALID_INPUT', 'código de error no válido para el journal');
    this.tx(() => {
      this.db.prepare(`UPDATE operations SET status = 'failed', error_code = ?, commit_sha = ?, lease_until = 0, updated_at = ?
        WHERE operation_id = ?`).run(errorCode, commitSha ?? null, new Date().toISOString(), operationId);
      this.db.prepare('INSERT OR REPLACE INTO receipts (operation_id, receipt) VALUES (?, ?)').run(operationId, JSON.stringify(receipt));
    });
  }

  receipt(operationId: string): Receipt | undefined {
    const r = this.db.prepare('SELECT receipt FROM receipts WHERE operation_id = ?').get(operationId) as Row | undefined;
    return r ? JSON.parse(String(r.receipt)) as Receipt : undefined;
  }

  receipts(): Receipt[] {
    return (this.db.prepare('SELECT receipt FROM receipts').all() as Row[]).map((r) => JSON.parse(String(r.receipt)) as Receipt);
  }

  /** Últimas operaciones (más recientes primero). */
  list(limit: number): OpRow[] {
    return (this.db.prepare('SELECT * FROM operations ORDER BY created_at DESC, operation_id DESC LIMIT ?').all(limit) as Row[]).map(toOp);
  }

  /** Reconstrucción desde el ledger: operaciones confirmadas, sin receipts (se perdieron con el journal). */
  importCommitted(ops: { operationId: string; kind: string; commitSha: string; at: string; documents: string[]; idemKeyHash?: string; errorCode?: string }[]): void {
    this.tx(() => {
      for (const o of ops) {
        const failed = o.errorCode !== undefined && ERROR_CODE_RE.test(o.errorCode);
        this.db.prepare(`INSERT OR IGNORE INTO operations (operation_id, kind, status, idem_key_hash, commit_sha, error_code, lease_until, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)`).run(o.operationId, o.kind, failed ? 'failed' : 'committed', o.idemKeyHash ?? null, o.commitSha,
          failed ? o.errorCode! : null, o.at, o.at);
        for (const d of o.documents) this.insertDocument(o.operationId, d);
      }
    });
  }

  // ── Outbox ───────────────────────────────────────────────────────────────

  due(event?: string): OutboxEvent[] {
    const rows = this.db.prepare(`SELECT * FROM outbox WHERE status = 'pending' AND next_at <= ? ${event ? 'AND event = ?' : ''} ORDER BY id`)
      .all(...(event ? [Date.now(), event] : [Date.now()])) as Row[];
    return rows.map((r) => ({
      id: Number(r.id), operationId: String(r.operation_id), event: String(r.event), payload: JSON.parse(String(r.payload)), attempts: Number(r.attempts),
    }));
  }

  /** Reclama un evento durante `leaseMs`; false si otro consumidor ya lo tiene. */
  claim(id: number, leaseMs: number): boolean {
    const r = this.relaxed(() => this.db.prepare("UPDATE outbox SET next_at = ? WHERE id = ? AND status = 'pending' AND next_at <= ?").run(Date.now() + leaseMs, id, Date.now()));
    return Number(r.changes) === 1;
  }

  retry(id: number, delayMs: number): void {
    this.db.prepare('UPDATE outbox SET attempts = attempts + 1, next_at = ? WHERE id = ?').run(Date.now() + delayMs, id);
  }

  done(id: number): void {
    this.db.prepare("UPDATE outbox SET status = 'done' WHERE id = ?").run(id);
  }

  // ── Subidas reanudables (SE-422) ─────────────────────────────────────────

  uploadCreate(o: { uploadId: string; ownerHash: string; length: number; expiresAt: number }): void {
    const now = new Date().toISOString();
    this.db.prepare(`INSERT INTO uploads (upload_id, owner_hash, status, length, expires_at, created_at, updated_at)
      VALUES (?, ?, 'receiving', ?, ?, ?, ?)`).run(o.uploadId, o.ownerHash, o.length, o.expiresAt, now, now);
  }

  upload(uploadId: string): UploadRow | undefined {
    const r = this.db.prepare('SELECT * FROM uploads WHERE upload_id = ?').get(uploadId) as Row | undefined;
    if (!r) return undefined;
    return {
      uploadId: String(r.upload_id), ownerHash: String(r.owner_hash), status: r.status as UploadStatus, length: Number(r.length),
      offset: Number(r.offset), fileSize: Number(r.file_size), chunkIndex: Number(r.chunk_index), expiresAt: Number(r.expires_at),
      documentId: opt(r.document_id as string), operationId: opt(r.operation_id as string), errorCode: opt(r.error_code as string),
    };
  }

  /** Avanza el offset tras escribir (y sincronizar) un trozo. Solo si seguía en el offset esperado. */
  uploadAdvance(uploadId: string, from: number, to: { offset: number; fileSize: number; chunkIndex: number }): boolean {
    const r = this.db.prepare(`UPDATE uploads SET offset = ?, file_size = ?, chunk_index = ?, updated_at = ?
      WHERE upload_id = ? AND offset = ? AND status = 'receiving'`).run(to.offset, to.fileSize, to.chunkIndex, new Date().toISOString(), uploadId, from);
    return Number(r.changes) === 1;
  }

  uploadSet(uploadId: string, o: { status: UploadStatus; documentId?: string; operationId?: string; errorCode?: string }): void {
    if (o.errorCode !== undefined && !ERROR_CODE_RE.test(o.errorCode)) throw new FilesError('INVALID_INPUT', 'código de error no válido para el journal');
    this.db.prepare(`UPDATE uploads SET status = ?, document_id = COALESCE(?, document_id), operation_id = COALESCE(?, operation_id),
      error_code = COALESCE(?, error_code), updated_at = ? WHERE upload_id = ?`)
      .run(o.status, o.documentId ?? null, o.operationId ?? null, o.errorCode ?? null, new Date().toISOString(), uploadId);
  }

  /** Subidas sin terminar de un dueño (límite de subidas activas). */
  activeUploads(ownerHash: string): number {
    return Number((this.db.prepare("SELECT count(*) AS n FROM uploads WHERE owner_hash = ? AND status IN ('receiving','processing') AND expires_at > ?")
      .get(ownerHash, Date.now()) as Row).n);
  }

  expiredUploads(now = Date.now()): string[] {
    return (this.db.prepare("SELECT upload_id FROM uploads WHERE status = 'receiving' AND expires_at <= ?").all(now) as Row[]).map((r) => String(r.upload_id));
  }

  /** Consume un token de un solo uso; false si ya se usó. */
  useToken(jti: string): boolean {
    const r = this.db.prepare('INSERT OR IGNORE INTO used_tokens (jti, used_at) VALUES (?, ?)').run(jti, new Date().toISOString());
    return Number(r.changes) === 1;
  }

  quickCheck(): boolean {
    const r = this.db.prepare('PRAGMA quick_check').get() as Row | undefined;
    return !!r && Object.values(r)[0] === 'ok';
  }
}
