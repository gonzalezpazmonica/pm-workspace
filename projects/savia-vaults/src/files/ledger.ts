// SE-418 — ledger git privado de una cúpula de Savia Files (`<cúpula>/ledger`): la autoridad.
// Un documento existe si su manifiesto está en el ledger. Repo local, sin remoto, sin hooks, con
// identidad propia y sin leer la configuración global ni variables GIT_* del entorno. Solo ids,
// hashes, tamaños, tipos y estados: nunca nombres, etiquetas, texto, rutas ni claves.
//   manifests/<documentId>.json   manifiesto compacto (JSON canónico)
//   intents/<operationId>.json    qué operación hizo el commit
//   tombstones/<documentId>.json  documento borrado
import * as fs from 'node:fs';
import * as path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { writeAtomic } from '../rag/store.js';
import { canonicalJson } from './crypto.js';
import { FilesError, type ExtractionStatus, type FileType } from './types.js';

export interface LedgerManifest {
  schemaVersion: 1;
  documentId: string;
  currentRevision: string;
  /** SHA-256 del payload `docs/<id>.json` tal como está en disco (sellado en cúpulas cifradas). */
  metaHash: string;
  revisions: {
    revisionId: string;
    /** SHA-256 del original en claras; del cifrado en cúpulas cifradas. */
    blob: string;
    /** Solo en cúpulas en claro (en las cifradas, ni tamaño ni tipo en claro). */
    size?: number;
    type?: FileType;
    extraction: { status: ExtractionStatus; digest?: string };
  }[];
}

export interface LedgerIntent {
  operationId: string;
  kind: string;
  at: string;
  documents: string[];
  idempotencyKeyHash?: string;
  /** Operación fallida que aun así cambió documentos (p. ej. lote deshecho). */
  errorCode?: string;
  recovered?: true;
}

export interface LedgerTombstone { documentId: string; deletedAt: string; operationId: string }

const DOCUMENT_RE = /^f_[0-9a-f]{16}$/;
const OPERATION_RE = /^o_[0-9a-f]{1,32}$/;
const DIR_MODE = 0o700;

const sha256 = (b: Buffer | string) => createHash('sha256').update(b).digest('hex');

/** Entorno de git aislado: ni GIT_* heredados ni configuración global o de sistema. */
function gitEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [k, v] of Object.entries(process.env)) if (!k.startsWith('GIT_')) env[k] = v;
  return { ...env, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null', GIT_TERMINAL_PROMPT: '0', LC_ALL: 'C' };
}

export class Ledger {
  readonly dir: string;

  constructor(domeDir: string) {
    this.dir = path.join(domeDir, 'ledger');
  }

  private git(args: string[], opts: { input?: string } = {}): string {
    try {
      return execFileSync('git', ['-C', this.dir, ...args], {
        env: gitEnv(), encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'], input: opts.input, maxBuffer: 64 * 1024 * 1024,
      });
    } catch (e) {
      if ((e as NodeJS.ErrnoException).code === 'ENOENT') {
        throw new FilesError('UNSUPPORTED', 'git no está instalado: Savia Files lo necesita para guardar el historial de cada cúpula');
      }
      throw e;
    }
  }

  exists(): boolean {
    return fs.existsSync(path.join(this.dir, '.git'));
  }

  /** Crea el repo si no existe. Idempotente. */
  init(): void {
    fs.mkdirSync(this.dir, { recursive: true, mode: DIR_MODE });
    fs.chmodSync(this.dir, DIR_MODE);
    if (!this.exists()) this.git(['init', '-q']);
    for (const [k, v] of [
      ['user.name', 'Savia Files'], ['user.email', 'files@savia.invalid'], ['core.hooksPath', '/dev/null'],
      ['commit.gpgsign', 'false'], ['gc.auto', '0'], ['core.fsync', 'committed'], ['core.autocrlf', 'false'],
    ]) this.git(['config', k, v]);
    this.assertPrivate();
  }

  /** El ledger nunca tiene remoto: si alguien lo añade, no se escribe. */
  assertPrivate(): void {
    if (this.git(['remote']).trim()) {
      throw new FilesError('UNSAFE_HOME', `el ledger de ${path.basename(path.dirname(this.dir))} tiene un remoto configurado; quítalo (git remote remove) antes de seguir`);
    }
  }

  private file(sub: 'manifests' | 'intents' | 'tombstones', id: string): string {
    const re = sub === 'intents' ? OPERATION_RE : DOCUMENT_RE;
    if (!re.test(id)) throw new FilesError('INVALID_INPUT', `id no válido en el ledger: ${String(id).slice(0, 40)}`);
    return path.join(this.dir, sub, `${id}.json`);
  }

  private write(sub: 'manifests' | 'intents' | 'tombstones', id: string, body: object): void {
    fs.mkdirSync(path.join(this.dir, sub), { recursive: true, mode: DIR_MODE });
    writeAtomic(this.file(sub, id), `${canonicalJson(body)}\n`);
  }

  readManifest(documentId: string): LedgerManifest | undefined {
    try {
      return JSON.parse(fs.readFileSync(this.file('manifests', documentId), 'utf-8')) as LedgerManifest;
    } catch (e) {
      if (e instanceof FilesError) throw e;
      return undefined;
    }
  }

  writeManifest(m: LedgerManifest): void {
    this.write('manifests', m.documentId, m);
  }

  removeManifest(documentId: string): void {
    fs.rmSync(this.file('manifests', documentId), { force: true });
  }

  writeTombstone(t: LedgerTombstone): void {
    this.write('tombstones', t.documentId, { schemaVersion: 1, ...t });
  }

  writeIntent(i: LedgerIntent): void {
    this.write('intents', i.operationId, { schemaVersion: 1, ...i, documents: [...i.documents].sort() });
  }

  manifestIds(): string[] {
    const d = path.join(this.dir, 'manifests');
    return fs.existsSync(d) ? fs.readdirSync(d).filter((f) => f.endsWith('.json')).map((f) => f.slice(0, -5)).filter((id) => DOCUMENT_RE.test(id)).sort() : [];
  }

  /** Commit de todo lo cambiado. Si git falla, COMMIT_PENDING (reintentable). */
  commit(message: string): string {
    try {
      this.git(['add', '-A']);
      this.git(['commit', '-q', '--no-verify', '--allow-empty', '-m', message]);
      return this.git(['rev-parse', 'HEAD']).trim();
    } catch (e) {
      if (e instanceof FilesError) throw e;
      const detail = String((e as { stderr?: string }).stderr ?? '').split('\n')[0].slice(0, 200);
      throw new FilesError('COMMIT_PENDING', `no se pudo confirmar en el ledger (${detail || 'git falló'})`);
    }
  }

  hasCommit(sha: string): boolean {
    if (!/^[0-9a-f]{40,64}$/.test(sha)) return false;
    try {
      this.git(['cat-file', '-e', `${sha}^{commit}`]);
      return true;
    } catch {
      return false;
    }
  }

  /** true si el intent de la operación ya está en HEAD. */
  intentCommitted(operationId: string): boolean {
    this.file('intents', operationId);
    try {
      this.git(['cat-file', '-e', `HEAD:intents/${operationId}.json`]);
      return true;
    } catch {
      return false;
    }
  }

  /** Commit en el que entró el intent de una operación. */
  intentCommit(operationId: string): string | undefined {
    this.file('intents', operationId);
    try {
      return this.git(['log', '-1', '--format=%H', '--diff-filter=A', '--', `intents/${operationId}.json`]).trim() || undefined;
    } catch {
      return undefined;
    }
  }

  /** Operaciones confirmadas (de la más antigua a la más nueva) con su commit, para reconstruir el journal. */
  intents(): (LedgerIntent & { commitSha: string; idemKeyHash?: string })[] {
    let log: string;
    try {
      log = this.git(['log', '--reverse', '--format=%x01%H', '--name-only', '--diff-filter=A', '--', 'intents/']);
    } catch {
      return [];
    }
    const out: (LedgerIntent & { commitSha: string; idemKeyHash?: string })[] = [];
    for (const block of log.split('\x01').filter(Boolean)) {
      const [sha, ...files] = block.split('\n').map((s) => s.trim()).filter(Boolean);
      for (const f of files) {
        const id = path.basename(f, '.json');
        if (!OPERATION_RE.test(id)) continue;
        try {
          const i = JSON.parse(this.git(['show', `${sha}:${f}`])) as LedgerIntent;
          out.push({ ...i, commitSha: sha, idemKeyHash: i.idempotencyKeyHash });
        } catch { /* intent ilegible: verify lo reporta */ }
      }
    }
    return out;
  }

  /** Ficheros del ledger con cambios sin confirmar. */
  dirty(): string[] {
    return this.git(['status', '--porcelain', '--untracked-files=all']).split('\n').filter(Boolean).map((l) => l.slice(3).trim());
  }

  fsck(): boolean {
    try {
      this.git(['fsck', '--no-progress', '--no-dangling']);
      return true;
    } catch {
      return false;
    }
  }

  /** Hash de un conjunto de manifiestos tal como están en disco (null si no existe). */
  manifestHash(documentIds: string[]): string {
    const entries = [...new Set(documentIds)].sort().map((id) => {
      try {
        return [id, sha256(fs.readFileSync(this.file('manifests', id)))];
      } catch {
        return [id, null];
      }
    });
    return sha256(canonicalJson(entries));
  }
}
