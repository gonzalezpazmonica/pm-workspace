// SE-410 — Savia RAG: tipos compartidos.

export type Confidentiality = 'N1' | 'N2' | 'N3' | 'N4';
export type RagMode = 'hybrid' | 'dense' | 'bm25';
export type DomeRagStatus = 'ok' | 'stale' | 'degraded' | 'denied' | 'timeout' | 'error' | 'not_indexed';

/** Bloque opcional `rag` de una cúpula en savia-vaults.domes.json. */
export interface RagDomeConfig {
  enabled?: boolean;
  model?: string;
  chunkChars?: number;
  overlap?: number;
  halfLifeDays?: number;
  excludeStatuses?: string[];
  evalSet?: string;
  inlineSyncBudget?: number;
}

export interface ResolvedRagConfig {
  enabled: boolean;
  model: string;
  chunkChars: number;
  overlap: number;
  halfLifeDays: number;
  excludeStatuses: string[];
  evalSet?: string;
  inlineSyncBudget: number;
}

/** P1: contrato inmutable de una generación. Su hash es el id de generación. */
export interface EmbeddingContract {
  provider: 'ollama' | 'hash';
  model: string;
  modelDigest: string;
  dims: number;
  normalize: true;
  chunkerVersion: string;
  chunkChars: number;
  overlap: number;
  queryPrefix: string;
  docPrefix: string;
}

/** Metadatos de frescura extraídos del frontmatter. */
export interface ChunkMeta {
  title: string;
  status?: string;
  validUntil?: string;
  supersededBy?: string;
  modified: string;
  confidentiality?: string;
}

export interface Chunk {
  id: string;          // `${path}#${ordinal}`
  path: string;
  ordinal: number;
  heading: string;     // "título › h2 › h3"
  text: string;        // texto del chunk sin cabecera
  embedText: string;   // cabecera contextual + texto (lo que se embebe)
  hash: string;        // sha256(embedText + generationId), rellenado por el indexer
  meta: ChunkMeta;
}

export interface DocEntry {
  hash: string;        // sha256 de los bytes del fichero
  mtimeMs: number;
  chunkIds: string[];
  /** Motivo por el que no se embebe (p. ej. confidencialidad de la nota > cúpula). */
  skipped?: string;
}

export interface Manifest {
  version: 1;
  dome: string;
  generation: string;
  contract: EmbeddingContract;
  seq: number;
  createdAt: string;
  updatedAt: string;
  docs: Record<string, DocEntry>;
  chunkCount: number;
  fingerprint: string;
}

export interface ActivePointer {
  active?: string;
  previous?: string;
  shadow?: string;
  /** Métricas de eval registradas al activar cada generación (línea base de P5). */
  metrics?: Record<string, { recallAt10: number; mrr: number; at: string }>;
  updatedAt: string;
}

export interface SyncReport {
  dome: string;
  generation: string;
  promoted: boolean;
  shadow: boolean;
  docs: { added: number; updated: number; deleted: number; unchanged: number; skipped: number };
  chunks: { total: number; embedded: number; reused: number };
  durationMs: number;
}

export interface RagHit {
  dome: string;
  confidentiality: Confidentiality;
  path: string;
  chunkId: string;
  heading: string;
  text: string;
  score: number;
  signals: { denseRank?: number; bm25Rank?: number; dense?: number; bm25?: number };
  freshness: { modified: string; status?: string; supersededBy?: string; decay: number };
  generation: string;
}

export interface RagRequest {
  queries: string[];
  domes?: string[] | '*';
  k?: number;
  mode?: RagMode;
  pathPrefix?: string;
  includeStale?: boolean;
  maxChars?: number;
  concurrency?: number;
  timeoutMs?: number;
}

export interface DomeOutcome {
  name: string;
  status: DomeRagStatus;
  generation?: string;
  detail?: string;
}

export interface RagResponse {
  results: { query: string; hits: RagHit[] }[];
  merged?: RagHit[];
  domes: DomeOutcome[];
  timings: { totalMs: number; embedMs: number; syncMs: number };
}

export type RagErrorCode =
  | 'CONTRACT_MISMATCH'
  | 'INVALID_INPUT'
  | 'UNKNOWN_DOME'
  | 'LOCKED'
  | 'CORRUPT_INDEX'
  | 'UNSAFE_HOME'
  | 'EMBEDDER_UNAVAILABLE'
  | 'NOT_INDEXED'
  | 'PROMOTION_REJECTED';

export class RagError extends Error {
  constructor(public readonly code: RagErrorCode, message: string) {
    super(`${code}: ${message}`);
    this.name = 'RagError';
  }
}

export const RAG_DEFAULTS: ResolvedRagConfig = {
  enabled: false,
  model: 'qwen3-embedding:0.6b',
  chunkChars: 1200,
  overlap: 0.15,
  halfLifeDays: 0,
  excludeStatuses: ['deprecated', 'superseded', 'archived'],
  inlineSyncBudget: 25,
};

export const RAG_LIMITS = {
  maxQueries: 8,
  maxQueryChars: 1000,
  maxK: 50,
  defaultK: 8,
  defaultMaxChars: 12000,
  defaultConcurrency: 4,
  defaultTimeoutMs: 8000,
  maxFileBytes: 1024 * 1024,
  candidateDepth: 50,
  rrfK: 60,
  maxChunksPerDoc: 2,
} as const;
