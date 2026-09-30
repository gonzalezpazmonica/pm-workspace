import { createHash } from 'node:crypto';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { RagError, type ActivePointer, type Chunk, type EmbeddingContract, type Manifest } from './types.js';

/**
 * SE-410 — Almacén flat exacto por generación.
 * Layout: <home>/<dome>/active.json, <home>/<dome>/<gen>/{manifest.json, chunks-<seq>.jsonl, vectors-<seq>.f32}
 * Escritura: ficheros nuevos por seq + rename atómico del manifest. Un lector nunca ve un snapshot parcial.
 */

const FILE_MODE = 0o600;
const DIR_MODE = 0o700;

export function defaultRagHome(): string {
  return process.env.SAVIA_RAG_HOME || path.join(os.homedir(), '.savia-vaults', 'rag');
}

export function domeDir(home: string, dome: string): string {
  if (!/^[\w.-]+$/.test(dome) || dome === '.' || dome === '..') {
    throw new RagError('INVALID_INPUT', `nombre de cúpula no válido para el índice: ${dome}`);
  }
  return path.join(home, dome);
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>).sort(([a], [b]) => a.localeCompare(b));
    return `{${entries.map(([k, v]) => `${JSON.stringify(k)}:${canonical(v)}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

/** P1: id de generación = sha256 del contrato canónico, 12 hex. */
export function generationId(contract: EmbeddingContract): string {
  return createHash('sha256').update(canonical(contract)).digest('hex').slice(0, 12);
}

function mkdirPrivate(dir: string): void {
  fs.mkdirSync(dir, { recursive: true, mode: DIR_MODE });
  fs.chmodSync(dir, DIR_MODE);
}

/** `.git` real: directorio con HEAD (repo) o fichero `gitdir:` (worktree/submódulo). */
function isGitMarker(p: string): boolean {
  try {
    const st = fs.statSync(p);
    if (st.isDirectory()) return fs.existsSync(path.join(p, 'HEAD'));
    return st.isFile() && fs.readFileSync(p, 'utf-8').startsWith('gitdir:');
  } catch {
    return false;
  }
}

/** AC11: el índice copia texto de notas; nunca dentro de un repo git. */
export function ensureSafeHome(home: string): void {
  const abs = path.resolve(home);
  // SE-414: resolver symlinks del ancestro existente más cercano; si no, un enlace
  // a un directorio dentro de un repo pasaría la comprobación.
  let existing = abs;
  const rest: string[] = [];
  while (!fs.existsSync(existing) && path.dirname(existing) !== existing) {
    rest.unshift(path.basename(existing));
    existing = path.dirname(existing);
  }
  let cur = path.join(fs.realpathSync(existing), ...rest);
  for (;;) {
    if (isGitMarker(path.join(cur, '.git'))) {
      throw new RagError('UNSAFE_HOME', `SAVIA_RAG_HOME (${abs}) está dentro del repo git ${cur}`);
    }
    const parent = path.dirname(cur);
    if (parent === cur) break;
    cur = parent;
  }
  mkdirPrivate(abs);
}

export function writeAtomic(file: string, data: string | Uint8Array): void {
  const tmp = `${file}.tmp-${process.pid}-${Date.now()}`;
  fs.writeFileSync(tmp, data, { mode: FILE_MODE });
  fs.chmodSync(tmp, FILE_MODE);
  fs.renameSync(tmp, file);
}

export function readActive(home: string, dome: string): ActivePointer {
  const file = path.join(domeDir(home, dome), 'active.json');
  try {
    return JSON.parse(fs.readFileSync(file, 'utf-8')) as ActivePointer;
  } catch {
    return { updatedAt: '' };
  }
}

/** Conserva `metrics` existentes si el llamador no las pasa; poda las de generaciones retiradas. */
export function writeActive(home: string, dome: string, pointer: Omit<ActivePointer, 'updatedAt'>): void {
  const dir = domeDir(home, dome);
  mkdirPrivate(dir);
  const keep = new Set([pointer.active, pointer.previous, pointer.shadow].filter(Boolean) as string[]);
  const metrics = Object.fromEntries(
    Object.entries(pointer.metrics ?? readActive(home, dome).metrics ?? {}).filter(([g]) => keep.has(g)),
  );
  const next: ActivePointer = { ...pointer, ...(Object.keys(metrics).length ? { metrics } : {}), updatedAt: new Date().toISOString() };
  writeAtomic(path.join(dir, 'active.json'), JSON.stringify(next, null, 2));
}

type StoredChunk = Omit<Chunk, 'embedText'>;

export interface TopKHit { index: number; score: number }

export class FlatVectorStore {
  private constructor(
    public readonly manifest: Manifest,
    public readonly chunks: Chunk[],
    private readonly vectors: Float32Array,
    /** Directorio de la generación (para artefactos derivados como el índice BM25). */
    public readonly dir: string,
  ) {}

  get size(): number { return this.chunks.length; }
  get dims(): number { return this.manifest.contract.dims; }

  static readManifest(dir: string): Manifest | undefined {
    try {
      return JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf-8')) as Manifest;
    } catch {
      return undefined;
    }
  }

  static load(dir: string, expected?: EmbeddingContract): FlatVectorStore {
    const manifest = FlatVectorStore.readManifest(dir);
    if (!manifest) throw new RagError('NOT_INDEXED', `sin manifest en ${dir}`);
    if (generationId(manifest.contract) !== manifest.generation) {
      throw new RagError('CORRUPT_INDEX', `manifest de ${dir} no coincide con su contrato`);
    }
    if (expected && generationId(expected) !== manifest.generation) {
      throw new RagError('CONTRACT_MISMATCH', `la generación ${manifest.generation} no corresponde al contrato solicitado ${generationId(expected)}`);
    }
    let chunks: Chunk[];
    let buf: Buffer;
    try {
      chunks = fs.readFileSync(path.join(dir, `chunks-${manifest.seq}.jsonl`), 'utf-8')
        .split('\n').filter(Boolean)
        .map((line) => {
          const c = JSON.parse(line) as StoredChunk;
          return { ...c, embedText: `${c.heading}\n\n${c.text}` };
        });
      buf = fs.readFileSync(path.join(dir, `vectors-${manifest.seq}.f32`));
    } catch (e) {
      throw new RagError('CORRUPT_INDEX', `no se pudo leer la generación ${manifest.generation}: ${e instanceof Error ? e.message : e}`);
    }
    const dims = manifest.contract.dims;
    if (chunks.length !== manifest.chunkCount || buf.byteLength !== chunks.length * dims * 4) {
      throw new RagError('CORRUPT_INDEX', `tamaños inconsistentes en ${manifest.generation} (chunks ${chunks.length}/${manifest.chunkCount}, bytes ${buf.byteLength})`);
    }
    const vectors = new Float32Array(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength));
    return new FlatVectorStore(manifest, chunks, vectors, dir);
  }

  static write(dir: string, manifest: Manifest, chunks: Chunk[], vectors: Float32Array[]): void {
    if (chunks.length !== vectors.length) throw new RagError('CORRUPT_INDEX', 'chunks y vectores desalineados');
    mkdirPrivate(dir);
    const dims = manifest.contract.dims;
    const flat = new Float32Array(chunks.length * dims);
    vectors.forEach((v, i) => {
      if (v.length !== dims) throw new RagError('CONTRACT_MISMATCH', `vector de ${v.length} dims, contrato ${dims}`);
      flat.set(v, i * dims);
    });
    const lines = chunks.map(({ embedText: _e, ...rest }) => JSON.stringify(rest)).join('\n');
    writeAtomic(path.join(dir, `chunks-${manifest.seq}.jsonl`), lines ? `${lines}\n` : '');
    writeAtomic(path.join(dir, `vectors-${manifest.seq}.f32`), new Uint8Array(flat.buffer));
    writeAtomic(path.join(dir, 'manifest.json'), JSON.stringify({ ...manifest, chunkCount: chunks.length }, null, 2));
  }

  /** Solo metadatos (mtime, fingerprint) cambiaron: el seq y los datos siguen válidos. */
  static updateManifest(dir: string, manifest: Manifest): void {
    writeAtomic(path.join(dir, 'manifest.json'), JSON.stringify(manifest, null, 2));
  }

  vector(index: number): Float32Array {
    const d = this.dims;
    return this.vectors.subarray(index * d, (index + 1) * d);
  }

  /** Top-k exacto por producto escalar (vectores normalizados). */
  topK(query: Float32Array, k: number, accept?: (index: number) => boolean): TopKHit[] {
    if (query.length !== this.dims) throw new RagError('CONTRACT_MISMATCH', `consulta de ${query.length} dims, índice ${this.dims}`);
    const d = this.dims;
    const best: TopKHit[] = [];
    for (let i = 0; i < this.chunks.length; i++) {
      if (accept && !accept(i)) continue;
      let s = 0;
      const off = i * d;
      for (let j = 0; j < d; j++) s += this.vectors[off + j] * query[j];
      if (best.length < k) {
        best.push({ index: i, score: s });
        if (best.length === k) best.sort((a, b) => b.score - a.score);
      } else if (s > best[k - 1].score) {
        best[k - 1] = { index: i, score: s };
        best.sort((a, b) => b.score - a.score);
      }
    }
    return best.sort((a, b) => b.score - a.score);
  }
}

/** Borra ficheros de seq no referenciados por el manifest con antigüedad > graceMs. */
export function gcGeneration(dir: string, graceMs = 10 * 60 * 1000): number {
  const manifest = FlatVectorStore.readManifest(dir);
  if (!manifest) return 0;
  let removed = 0;
  const now = Date.now();
  for (const f of fs.readdirSync(dir)) {
    const m = f.match(/^(chunks|vectors)-(\d+)\.(jsonl|f32)$/) || f.match(/^(bm25)-(\d+)-v\d+\.json$/)
      || (f.includes('.tmp-') ? [f, '', '-1'] : null);
    if (!m || Number(m[2]) === manifest.seq) continue;
    const full = path.join(dir, f);
    if (graceMs <= 0 || now - fs.statSync(full).mtimeMs >= graceMs) {
      fs.rmSync(full, { force: true });
      removed++;
    }
  }
  return removed;
}
