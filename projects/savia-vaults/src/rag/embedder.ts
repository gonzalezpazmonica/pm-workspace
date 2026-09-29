import { createHash } from 'node:crypto';
import { CHUNKER_VERSION } from './chunker.js';
import { RagError, type EmbeddingContract } from './types.js';

/** SE-410 — Embedder: vectores normalizados; `contract()` resuelve digest y dims reales. */
export interface Embedder {
  contract(): Promise<EmbeddingContract>;
  embed(texts: string[], kind: 'query' | 'doc'): Promise<Float32Array[]>;
}

export function normalize(v: ArrayLike<number>): Float32Array {
  let norm = 0;
  for (let i = 0; i < v.length; i++) norm += v[i] * v[i];
  norm = Math.sqrt(norm) || 1;
  const out = new Float32Array(v.length);
  for (let i = 0; i < v.length; i++) out[i] = v[i] / norm;
  return out;
}

/** Producto escalar; con vectores normalizados equivale al coseno. */
export function cosine(a: Float32Array, b: Float32Array): number {
  let s = 0;
  for (let i = 0; i < a.length; i++) s += a[i] * b[i];
  return s;
}

/** Prefijos por familia de modelo (instruction-aware). */
export function promptProfile(model: string): { queryPrefix: string; docPrefix: string } {
  const m = model.toLowerCase();
  if (m.startsWith('qwen3-embedding')) {
    return { queryPrefix: 'Instruct: Given a question, retrieve documentation passages that answer it\nQuery: ', docPrefix: '' };
  }
  if (m.includes('e5')) return { queryPrefix: 'query: ', docPrefix: 'passage: ' };
  return { queryPrefix: '', docPrefix: '' };
}

export interface ContractParams {
  chunkChars: number;
  overlap: number;
}

const DEFAULT_PARAMS: ContractParams = { chunkChars: 1200, overlap: 0.15 };

/**
 * P9: solo para tests y entornos sin red. Bolsa de tokens con hashing.
 * Nunca se usa como sustituto silencioso del proveedor configurado.
 */
export class HashEmbedder implements Embedder {
  constructor(private readonly dims = 256, private readonly params: ContractParams = DEFAULT_PARAMS, private readonly tag = 'hash-bow-v1') {}

  async contract(): Promise<EmbeddingContract> {
    return {
      provider: 'hash', model: this.tag, modelDigest: this.tag, dims: this.dims, normalize: true,
      chunkerVersion: CHUNKER_VERSION, chunkChars: this.params.chunkChars, overlap: this.params.overlap,
      queryPrefix: '', docPrefix: '',
    };
  }

  async embed(texts: string[]): Promise<Float32Array[]> {
    return texts.map((t) => {
      const v = new Float32Array(this.dims);
      const tokens = t.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').match(/[a-z0-9]{2,}/g) || [];
      for (const tok of tokens) {
        const h = createHash('sha1').update(tok).digest();
        v[h.readUInt32BE(0) % this.dims] += h[4] & 1 ? 1 : -1;
      }
      return normalize(v);
    });
  }
}

export interface OllamaOptions {
  baseUrl?: string;
  model: string;
  batchSize?: number;
  timeoutMs?: number;
  params?: ContractParams;
  queryPrefix?: string;
  docPrefix?: string;
}

export class OllamaEmbedder implements Embedder {
  private readonly baseUrl: string;
  private readonly batchSize: number;
  private readonly timeoutMs: number;
  private readonly params: ContractParams;
  private readonly queryPrefix: string;
  private readonly docPrefix: string;
  private cached?: EmbeddingContract;

  constructor(private readonly opts: OllamaOptions) {
    this.baseUrl = (opts.baseUrl || process.env.SAVIA_OLLAMA_URL || 'http://127.0.0.1:11434').replace(/\/$/, '');
    this.batchSize = opts.batchSize ?? 32;
    this.timeoutMs = opts.timeoutMs ?? 30000;
    this.params = opts.params ?? DEFAULT_PARAMS;
    const profile = promptProfile(opts.model);
    this.queryPrefix = opts.queryPrefix ?? profile.queryPrefix;
    this.docPrefix = opts.docPrefix ?? profile.docPrefix;
  }

  get model(): string { return this.opts.model; }

  private async request(pathname: string, body?: unknown): Promise<any> {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), this.timeoutMs);
    try {
      const res = await fetch(`${this.baseUrl}${pathname}`, {
        method: body === undefined ? 'GET' : 'POST',
        headers: body === undefined ? undefined : { 'content-type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: ctrl.signal,
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } catch (e) {
      throw new RagError('EMBEDDER_UNAVAILABLE', `ollama ${pathname}: ${e instanceof Error ? e.message : String(e)}`);
    } finally {
      clearTimeout(timer);
    }
  }

  private async post(input: string[]): Promise<number[][]> {
    let lastErr: unknown;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const data = await this.request('/api/embed', { model: this.opts.model, input, truncate: true });
        if (!Array.isArray(data?.embeddings) || data.embeddings.length !== input.length) {
          throw new RagError('EMBEDDER_UNAVAILABLE', 'respuesta de /api/embed inválida');
        }
        return data.embeddings;
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr;
  }

  /** Digest actual del modelo en Ollama (P4). */
  async currentDigest(): Promise<string> {
    const data = await this.request('/api/tags');
    const wanted = this.opts.model.includes(':') ? this.opts.model : `${this.opts.model}:latest`;
    const found = (data?.models || []).find((m: { name: string }) => m.name === wanted || m.name === this.opts.model);
    if (!found) throw new RagError('EMBEDDER_UNAVAILABLE', `modelo ${this.opts.model} no está en Ollama`);
    return String(found.digest);
  }

  async contract(): Promise<EmbeddingContract> {
    if (this.cached) return this.cached;
    const modelDigest = await this.currentDigest();
    const [probe] = await this.post(['dims']);
    this.cached = {
      provider: 'ollama', model: this.opts.model, modelDigest, dims: probe.length, normalize: true,
      chunkerVersion: CHUNKER_VERSION, chunkChars: this.params.chunkChars, overlap: this.params.overlap,
      queryPrefix: this.queryPrefix, docPrefix: this.docPrefix,
    };
    return this.cached;
  }

  async embed(texts: string[], kind: 'query' | 'doc'): Promise<Float32Array[]> {
    const prefix = kind === 'query' ? this.queryPrefix : this.docPrefix;
    const out: Float32Array[] = [];
    for (let i = 0; i < texts.length; i += this.batchSize) {
      const batch = texts.slice(i, i + this.batchSize).map(t => prefix + t);
      const vectors = await this.post(batch);
      for (const v of vectors) out.push(normalize(v));
    }
    return out;
  }
}
