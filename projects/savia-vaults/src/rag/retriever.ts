import MiniSearch from 'minisearch';
import { decayFactor, excludedReason } from './policy.js';
import type { FlatVectorStore } from './store.js';
import { RAG_LIMITS, type RagHit, type RagMode, type ResolvedRagConfig } from './types.js';

/** SE-410 — Recuperación híbrida por cúpula: BM25 sobre chunks + denso, RRF, frescura. */

/** Reciprocal Rank Fusion: score(id) = Σ 1/(k + rank), rank desde 1. */
export function rrf(lists: string[][], k: number = RAG_LIMITS.rrfK): Map<string, number> {
  const scores = new Map<string, number>();
  for (const list of lists) {
    list.forEach((id, i) => scores.set(id, (scores.get(id) ?? 0) + 1 / (k + i + 1)));
  }
  return scores;
}

interface Bm25Doc { id: number; heading: string; text: string }

// Stopwords es/en: sin ellas, términos como "de" o "que" dominan el OR de BM25
// y el prefijo los expande a medio vocabulario.
const STOPWORDS = new Set((
  'a al algo ante antes como con contra cual cuando de del desde donde durante e el ella ellas ellos en entre era es esa ese eso esta este esto estos fue ha han hasta hay la las le les lo los mas me mi mientras muy nada ni no nos o os otra otro para pero poco por porque que quien se sea segun ser si sin sobre son su sus tambien te tiene todo tras tu un una uno unos y ya yo ' +
  'a an and are as at be but by for from has have if in into is it its not of on or so that the their then there these this to was were will with'
).split(' '));

/** Normaliza un término: minúsculas, sin acentos; null si es stopword. */
export function processTerm(term: string): string | null {
  const t = term.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  return STOPWORDS.has(t) ? null : t;
}

const bm25Cache = new WeakMap<FlatVectorStore, MiniSearch<Bm25Doc>>();

function bm25Index(store: FlatVectorStore): MiniSearch<Bm25Doc> {
  let ms = bm25Cache.get(store);
  if (!ms) {
    ms = new MiniSearch<Bm25Doc>({
      fields: ['heading', 'text'],
      idField: 'id',
      processTerm,
      searchOptions: {
        boost: { heading: 1.5 },
        prefix: (term: string) => term.length >= 4,
        fuzzy: (term: string) => (term.length >= 5 ? 0.1 : 0),
      },
    });
    ms.addAll(store.chunks.map((c, i) => ({ id: i, heading: c.heading, text: c.text })));
    bm25Cache.set(store, ms);
  }
  return ms;
}

export interface StoreSearchInput {
  store: FlatVectorStore;
  query: string;
  queryVec?: Float32Array;
  mode: RagMode;
  k: number;
  cfg: Pick<ResolvedRagConfig, 'excludeStatuses' | 'halfLifeDays'>;
  pathPrefix?: string;
  includeStale?: boolean;
  now?: Date;
}

/** Hits de una cúpula sin dome/confidencialidad (los añade el servicio). */
export type StoreHit = Omit<RagHit, 'dome' | 'confidentiality'>;

export function searchStore(input: StoreSearchInput): StoreHit[] {
  const { store, cfg } = input;
  const now = input.now ?? new Date();
  const depth = RAG_LIMITS.candidateDepth;
  const accept = (i: number) => {
    const c = store.chunks[i];
    if (input.pathPrefix && !c.path.startsWith(input.pathPrefix)) return false;
    return input.includeStale || !excludedReason(c.meta, cfg, now);
  };

  const lists: string[][] = [];
  const dense = new Map<number, { rank: number; score: number }>();
  const lexical = new Map<number, { rank: number; score: number }>();

  if (input.mode !== 'bm25' && input.queryVec) {
    store.topK(input.queryVec, depth, accept).forEach((h, r) => dense.set(h.index, { rank: r + 1, score: h.score }));
    lists.push([...dense.keys()].map(String));
  }
  if (input.mode !== 'dense') {
    bm25Index(store).search(input.query)
      .filter(r => accept(r.id as number))
      .slice(0, depth)
      .forEach((r, rank) => lexical.set(r.id as number, { rank: rank + 1, score: r.score }));
    lists.push([...lexical.keys()].map(String));
  }

  const fused = [...rrf(lists).entries()].map(([id, score]) => {
    const i = Number(id);
    const c = store.chunks[i];
    const decay = decayFactor(c.meta.modified, cfg.halfLifeDays, now);
    return { i, score: score * decay, decay };
  }).sort((a, b) => b.score - a.score);

  const perDoc = new Map<string, number>();
  const out: StoreHit[] = [];
  for (const f of fused) {
    const c = store.chunks[f.i];
    const n = perDoc.get(c.path) ?? 0;
    if (n >= RAG_LIMITS.maxChunksPerDoc) continue;
    perDoc.set(c.path, n + 1);
    const d = dense.get(f.i);
    const l = lexical.get(f.i);
    out.push({
      path: c.path, chunkId: c.id, heading: c.heading, text: c.text, score: f.score,
      signals: { denseRank: d?.rank, dense: d?.score, bm25Rank: l?.rank, bm25: l?.score },
      freshness: { modified: c.meta.modified, status: c.meta.status, supersededBy: c.meta.supersededBy, decay: f.decay },
      generation: store.manifest.generation,
    });
    if (out.length >= input.k) break;
  }
  return out;
}

/** Fusión entre cúpulas o consultas por rango (los scores no son comparables entre índices). */
export function fuseAcross(lists: RagHit[][], k: number): RagHit[] {
  const byKey = new Map<string, RagHit>();
  const keyed = lists.map(list => list.map((h) => {
    const key = `${h.dome}\u0000${h.chunkId}`;
    if (!byKey.has(key)) byKey.set(key, h);
    return key;
  }));
  return [...rrf(keyed).entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, k)
    .map(([key, score]) => ({ ...byKey.get(key)!, score }));
}

/** Recorta el texto de los hits para respetar maxChars; nunca omite hits. */
export function applyCharBudget(hits: RagHit[], maxChars: number): RagHit[] {
  const total = hits.reduce((s, h) => s + h.text.length, 0);
  if (total <= maxChars || hits.length === 0) return hits;
  const per = Math.max(200, Math.floor(maxChars / hits.length));
  return hits.map(h => (h.text.length > per ? { ...h, text: `${h.text.slice(0, per - 1)}…` } : h));
}
