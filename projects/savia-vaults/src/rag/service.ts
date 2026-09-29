import * as fs from 'node:fs';
import * as path from 'node:path';
import { HashEmbedder, OllamaEmbedder, type Embedder } from './embedder.js';
import { RagIndexer, listIndexable, logEvent } from './indexer.js';
import { fanOut, withTimeout, TimeoutError } from './parallel.js';
import { promotionDecision, resolveRagConfig, sloStatus, type EvalMetrics } from './policy.js';
import { applyCharBudget, fuseAcross, searchStore, type StoreHit } from './retriever.js';
import {
  FlatVectorStore, defaultRagHome, domeDir, ensureSafeHome, gcGeneration, generationId, readActive, writeActive,
} from './store.js';
import {
  RAG_LIMITS, RagError, type Confidentiality, type DomeOutcome, type EmbeddingContract, type RagDomeConfig,
  type RagHit, type RagMode, type RagRequest, type RagResponse, type ResolvedRagConfig, type SyncReport,
} from './types.js';

/**
 * SE-410 — RagService: orquesta frescura, embeddings por contrato, fan-out
 * paralelo y fusión. Una instancia por proceso (MCP server o CLI).
 */

export interface RagDomeRef {
  name: string;
  path: string;
  confidentiality: Confidentiality;
  rag?: RagDomeConfig;
}

export interface RagServiceOptions {
  domes: () => RagDomeRef[];
  home?: string;
  embedderFactory?: (cfg: ResolvedRagConfig) => Embedder;
  /** Lanza si la acción no está autorizada sobre la cúpula. */
  authorize?: (dome: string, action: 'read' | 'write', tool: string) => Promise<void>;
  /** true en el servidor MCP (proceso largo): permite sync en segundo plano. */
  background?: boolean;
  env?: NodeJS.ProcessEnv;
}

export interface EvalQueryInput { query: string; relevantPaths: string[]; kind?: string }

export interface RagEvalResult extends EvalMetrics {
  n: number;
  recallAt5: number;
  mode: RagMode;
  generation: string;
  p50Ms: number;
  p95Ms: number;
  failed: { query: string; relevant: string[]; retrieved: string[] }[];
}

export interface DomeStatusReport {
  name: string;
  enabled: boolean;
  confidentiality: Confidentiality;
  active?: string;
  shadow?: string;
  previous?: string;
  contract?: EmbeddingContract;
  currentDigest?: string;
  digestMatch: boolean;
  chunks: number;
  totalDocs: number;
  pendingDocs: number;
  staleRatio: number;
  lagHours: number;
  generationAgeHours?: number;
  memoryBytes: number;
  slo: { ok: boolean; alerts: string[] };
}

export type SyncResult = SyncReport & { gate?: { promote: boolean; reason: string } };

/**
 * Fábrica por defecto: Ollama. `SAVIA_RAG_TEST_PROVIDER=hash` existe solo para
 * tests e2e sin red; el contrato resultante declara `provider: hash` (P9).
 */
let testProviderWarned = false;

export function defaultEmbedderFactory(env: NodeJS.ProcessEnv = process.env): (cfg: ResolvedRagConfig) => Embedder {
  if (env.SAVIA_RAG_TEST_PROVIDER === 'hash') {
    if (!testProviderWarned) console.error('[rag] WARNING: SAVIA_RAG_TEST_PROVIDER=hash — embeddings de test, no semánticos');
    testProviderWarned = true;
    // cfg.model puede venir ya como `hash:<modelo>` (reconstruido desde el contrato).
    return (cfg) => new HashEmbedder(256, cfg, `hash:${cfg.model.replace(/^hash:/, '')}`);
  }
  return (cfg) => new OllamaEmbedder({ model: cfg.model, params: { chunkChars: cfg.chunkChars, overlap: cfg.overlap } });
}

const LRU_MAX = 4;
const WRITE_DEBOUNCE_MS = 2000;

function percentile(values: number[], p: number): number {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)];
}

export class RagService {
  private readonly home: string;
  private readonly env: NodeJS.ProcessEnv;
  private readonly embedders = new Map<string, Embedder>();
  private readonly stores = new Map<string, FlatVectorStore>();
  private readonly syncing = new Map<string, Promise<SyncResult>>();
  private readonly timers = new Map<string, NodeJS.Timeout>();

  constructor(private readonly o: RagServiceOptions) {
    this.home = o.home ?? defaultRagHome();
    this.env = o.env ?? process.env;
  }

  // ── Configuración y dependencias ──────────────────────────────────────

  private dome(name: string): RagDomeRef {
    const d = this.o.domes().find(x => x.name === name);
    if (!d) throw new RagError('UNKNOWN_DOME', `cúpula "${name}" no registrada`);
    return d;
  }

  config(d: RagDomeRef): ResolvedRagConfig {
    return resolveRagConfig(d.rag, this.env);
  }

  private embedder(cfg: ResolvedRagConfig): Embedder {
    const key = `${cfg.model}|${cfg.chunkChars}|${cfg.overlap}`;
    let e = this.embedders.get(key);
    if (!e) {
      e = (this.o.embedderFactory ?? defaultEmbedderFactory(this.env))(cfg);
      this.embedders.set(key, e);
    }
    return e;
  }

  private indexer(d: RagDomeRef, cfg = this.config(d)): RagIndexer {
    return new RagIndexer({ dome: d.name, vaultPath: d.path, home: this.home, cfg, embedder: this.embedder(cfg), domeLevel: d.confidentiality });
  }

  /** LRU de ≤4 índices cargados; clave incluye seq para invalidar tras cada sync. */
  private loadStore(dome: string, generation: string): FlatVectorStore {
    const dir = path.join(domeDir(this.home, dome), generation);
    const manifest = FlatVectorStore.readManifest(dir);
    if (!manifest) throw new RagError('NOT_INDEXED', `generación ${generation} de ${dome} no existe`);
    const key = `${dome}/${generation}/${manifest.seq}`;
    const hit = this.stores.get(key);
    if (hit) {
      this.stores.delete(key);
      this.stores.set(key, hit);
      return hit;
    }
    const store = FlatVectorStore.load(dir);
    for (const k of this.stores.keys()) if (k.startsWith(`${dome}/${generation}/`)) this.stores.delete(k);
    this.stores.set(key, store);
    while (this.stores.size > LRU_MAX) this.stores.delete(this.stores.keys().next().value!);
    return store;
  }

  // ── Sync, promoción y generaciones ────────────────────────────────────

  sync(name: string, opts: { rebuild?: boolean } = {}): Promise<SyncResult> {
    const inflight = this.syncing.get(name);
    if (inflight && !opts.rebuild) return inflight;
    const run = this.runSync(name, opts).finally(() => this.syncing.delete(name));
    this.syncing.set(name, run);
    return run;
  }

  private async runSync(name: string, opts: { rebuild?: boolean }): Promise<SyncResult> {
    const d = this.dome(name);
    const cfg = this.config(d);
    const report: SyncResult = await this.indexer(d, cfg).sync(opts);
    if (report.shadow) {
      const { metrics, ...decision } = await this.gate(d, cfg, report.generation, false);
      report.gate = decision;
      if (decision.promote) {
        this.activate(name, report.generation);
        await this.recordBaseline(d, cfg, report.generation, metrics);
        report.promoted = true;
        report.shadow = false;
      }
      logEvent(this.home, { event: 'gate', dome: name, generation: report.generation, ...decision });
    } else if (report.promoted || !readActive(this.home, name).metrics?.[report.generation]) {
      await this.recordBaseline(d, cfg, report.generation);
    }
    return report;
  }

  private loadEvalSet(d: RagDomeRef, cfg: ResolvedRagConfig): EvalQueryInput[] | undefined {
    if (!cfg.evalSet) return undefined;
    // Ruta relativa al vault (o absoluta); la fija la operadora en el registry.
    const file = path.resolve(d.path, cfg.evalSet);
    if (!file.endsWith('.json') || !fs.existsSync(file)) return undefined;
    return JSON.parse(fs.readFileSync(file, 'utf-8')) as EvalQueryInput[];
  }

  /**
   * P5: la activa se evalúa en vivo; si su modelo ya no está disponible (deriva
   * de digest, P4), se usa la línea base registrada al activarla.
   */
  private async gate(d: RagDomeRef, cfg: ResolvedRagConfig, candidate: string, force: boolean) {
    const pointer = readActive(this.home, d.name);
    const hasActive = Boolean(pointer.active) && pointer.active !== candidate;
    const queries = this.loadEvalSet(d, cfg);
    let active: EvalMetrics | undefined;
    let cand: EvalMetrics | undefined;
    if (queries?.length && hasActive && !force) {
      try {
        active = await this.evaluate(d.name, queries, { generation: pointer.active });
      } catch (e) {
        if (!(e instanceof RagError) || !['CONTRACT_MISMATCH', 'EMBEDDER_UNAVAILABLE'].includes(e.code)) throw e;
        active = pointer.metrics?.[pointer.active!];
      }
      cand = await this.evaluate(d.name, queries, { generation: candidate });
    }
    const manifest = FlatVectorStore.readManifest(path.join(domeDir(this.home, d.name), candidate));
    const indexable = listIndexable(d.path).length;
    const coverage = manifest ? (indexable ? Object.keys(manifest.docs).length / indexable : 1) : 0;
    return { ...promotionDecision({ active, candidate: cand, coverage: Math.min(1, coverage), hasActive, force }), metrics: cand };
  }

  /** Registra la línea base de eval de una generación recién activada. */
  private async recordBaseline(d: RagDomeRef, cfg: ResolvedRagConfig, generation: string, known?: EvalMetrics): Promise<void> {
    let m = known;
    if (!m) {
      const queries = this.loadEvalSet(d, cfg);
      if (!queries?.length) return;
      try { m = await this.evaluate(d.name, queries, { generation }); } catch { return; }
    }
    const p = readActive(this.home, d.name);
    writeActive(this.home, d.name, {
      active: p.active, previous: p.previous, shadow: p.shadow,
      metrics: { ...(p.metrics ?? {}), [generation]: { recallAt10: m.recallAt10, mrr: m.mrr, at: new Date().toISOString() } },
    });
  }

  private activate(name: string, generation: string): void {
    const p = readActive(this.home, name);
    if (p.active === generation) return;
    writeActive(this.home, name, {
      active: generation,
      previous: p.active,
      shadow: p.shadow === generation ? undefined : p.shadow,
    });
  }

  async promote(name: string, generation: string, force = false): Promise<{ promote: boolean; reason: string }> {
    const d = this.dome(name);
    if (!FlatVectorStore.readManifest(path.join(domeDir(this.home, name), generation))) {
      throw new RagError('NOT_INDEXED', `generación ${generation} de ${name} no existe`);
    }
    const cfg = this.config(d);
    const { metrics, ...decision } = await this.gate(d, cfg, generation, force);
    if (!decision.promote) throw new RagError('PROMOTION_REJECTED', decision.reason);
    this.activate(name, generation);
    await this.recordBaseline(d, cfg, generation, metrics);
    logEvent(this.home, { event: 'promote', dome: name, generation, force, reason: decision.reason });
    return decision;
  }

  async rollback(name: string): Promise<string> {
    this.dome(name);
    const p = readActive(this.home, name);
    if (!p.previous) throw new RagError('NOT_INDEXED', `${name} no tiene generación anterior`);
    writeActive(this.home, name, { active: p.previous, previous: p.active, shadow: p.shadow });
    logEvent(this.home, { event: 'rollback', dome: name, from: p.active, to: p.previous });
    return p.previous;
  }

  async gc(name: string): Promise<number> {
    this.dome(name);
    const dir = domeDir(this.home, name);
    if (!fs.existsSync(dir)) return 0;
    const p = readActive(this.home, name);
    const keep = new Set([p.active, p.previous, p.shadow].filter(Boolean) as string[]);
    let removed = 0;
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (!e.isDirectory()) continue;
      const full = path.join(dir, e.name);
      if (keep.has(e.name)) removed += gcGeneration(full);
      else { fs.rmSync(full, { recursive: true, force: true }); removed++; }
    }
    return removed;
  }

  /** Disparador de escritura (P3): debounce de 2 s por cúpula; solo en el servidor. */
  scheduleSync(name: string): void {
    if (!this.o.background) return;
    const d = this.o.domes().find(x => x.name === name);
    if (!d || !this.config(d).enabled) return;
    clearTimeout(this.timers.get(name));
    const t = setTimeout(() => {
      this.timers.delete(name);
      this.sync(name).catch(e => logEvent(this.home, { event: 'sync_error', dome: name, detail: String(e) }));
    }, WRITE_DEBOUNCE_MS);
    t.unref?.();
    this.timers.set(name, t);
  }

  // ── Búsqueda ─────────────────────────────────────────────────────────

  private validate(req: RagRequest): Required<Pick<RagRequest, 'k' | 'mode' | 'maxChars' | 'concurrency' | 'timeoutMs'>> {
    const q = req.queries;
    if (!Array.isArray(q) || q.length < 1 || q.length > RAG_LIMITS.maxQueries) {
      throw new RagError('INVALID_INPUT', `queries: entre 1 y ${RAG_LIMITS.maxQueries}`);
    }
    for (const s of q) {
      if (typeof s !== 'string' || !s.trim() || s.length > RAG_LIMITS.maxQueryChars) {
        throw new RagError('INVALID_INPUT', `cada consulta: 1-${RAG_LIMITS.maxQueryChars} caracteres`);
      }
    }
    const k = req.k ?? RAG_LIMITS.defaultK;
    if (!Number.isInteger(k) || k < 1 || k > RAG_LIMITS.maxK) throw new RagError('INVALID_INPUT', `k: 1-${RAG_LIMITS.maxK}`);
    const mode = req.mode ?? 'hybrid';
    if (!['hybrid', 'dense', 'bm25'].includes(mode)) throw new RagError('INVALID_INPUT', `mode no válido: ${mode}`);
    const maxChars = req.maxChars ?? RAG_LIMITS.defaultMaxChars;
    if (!Number.isFinite(maxChars) || maxChars < 500) throw new RagError('INVALID_INPUT', 'maxChars ≥ 500');
    return {
      k, mode, maxChars,
      concurrency: Math.max(1, Math.min(16, req.concurrency ?? RAG_LIMITS.defaultConcurrency)),
      timeoutMs: Math.max(50, req.timeoutMs ?? RAG_LIMITS.defaultTimeoutMs),
    };
  }

  private targetDomes(req: RagRequest): RagDomeRef[] {
    const all = this.o.domes();
    if (!req.domes || req.domes === '*') {
      return all.filter(d => d.confidentiality !== 'N4' && this.config(d).enabled);
    }
    return [...new Set(req.domes)].map(n => this.dome(n));
  }

  async search(req: RagRequest): Promise<RagResponse> {
    const t0 = Date.now();
    const opt = this.validate(req);
    const targets = this.targetDomes(req);
    const outcomes = new Map<string, DomeOutcome>(targets.map(d => [d.name, { name: d.name, status: 'ok' }]));
    let syncMs = 0;

    // 2. Autorización por cúpula: las denegadas se declaran, nunca se omiten.
    const allowed: RagDomeRef[] = [];
    for (const d of targets) {
      try {
        await this.o.authorize?.(d.name, 'read', 'vault_rag');
        allowed.push(d);
      } catch (e) {
        outcomes.set(d.name, { name: d.name, status: 'denied', detail: e instanceof Error ? e.message : String(e) });
      }
    }

    // 3. Frescura (P3-lectura) y carga del índice por cúpula, en paralelo con timeout.
    interface Prepared { d: RagDomeRef; cfg: ResolvedRagConfig; store: FlatVectorStore }
    const prepared = await fanOut(allowed.map(d => ({
      key: d.name,
      fn: async (): Promise<Prepared | undefined> => {
        const cfg = this.config(d);
        if (!cfg.enabled) {
          outcomes.set(d.name, { name: d.name, status: 'not_indexed', detail: 'sin bloque rag habilitado' });
          return undefined;
        }
        const s0 = Date.now();
        const pending = await this.indexer(d, cfg).pending();
        let status: DomeOutcome['status'] = 'ok';
        let detail: string | undefined;
        if (pending.pendingDocs > 0) {
          if (pending.pendingDocs <= cfg.inlineSyncBudget) {
            try {
              await this.sync(d.name);
            } catch (e) {
              status = 'stale';
              detail = e instanceof Error ? e.message : String(e);
            }
          } else {
            status = 'stale';
            detail = `${pending.pendingDocs} documentos pendientes > presupuesto inline ${cfg.inlineSyncBudget}; ejecutar rag sync`;
            if (this.o.background) this.sync(d.name).catch(err => logEvent(this.home, { event: 'sync_error', dome: d.name, detail: String(err) }));
          }
        }
        syncMs += Date.now() - s0;
        const active = readActive(this.home, d.name).active;
        if (!active) {
          outcomes.set(d.name, { name: d.name, status: 'not_indexed', detail: detail ?? 'sin generación activa; ejecutar rag sync' });
          return undefined;
        }
        const store = this.loadStore(d.name, active);
        outcomes.set(d.name, { name: d.name, status, generation: active, detail });
        return { d, cfg, store };
      },
    })), { concurrency: opt.concurrency, timeoutMs: opt.timeoutMs });

    const ready: Prepared[] = [];
    for (const d of allowed) {
      const r = prepared.get(d.name)!;
      if (r.ok) { if (r.value) ready.push(r.value); }
      else outcomes.set(d.name, { name: d.name, status: r.timeout ? 'timeout' : 'error', detail: r.error });
    }

    // 4. Embeddings de consultas: un lote por contrato (P1); contrato vivo distinto ⇒ degradado.
    const e0 = Date.now();
    const queryVecs = new Map<string, Float32Array[]>();
    if (opt.mode !== 'bm25') {
      const byGen = new Map<string, Prepared[]>();
      for (const p of ready) byGen.set(p.store.manifest.generation, [...(byGen.get(p.store.manifest.generation) ?? []), p]);
      await Promise.all([...byGen.entries()].map(async ([gen, group]) => {
        const degrade = (detail: string) => {
          for (const p of group) {
            const prev = outcomes.get(p.d.name)!;
            outcomes.set(p.d.name, { ...prev, status: 'degraded', detail: prev.detail ? `${prev.detail}; ${detail}` : detail });
          }
        };
        try {
          const emb = this.embedder({ ...group[0].cfg, model: group[0].store.manifest.contract.model });
          const live = await withTimeout(emb.contract(), opt.timeoutMs);
          if (generationId(live) !== gen) {
            degrade(`CONTRACT_MISMATCH: el modelo vivo (${live.model} ${live.modelDigest.slice(0, 12)}) no es el de la generación ${gen}; generación sombra pendiente`);
            return;
          }
          queryVecs.set(gen, await withTimeout(emb.embed(req.queries, 'query'), opt.timeoutMs));
        } catch (e) {
          degrade(e instanceof TimeoutError ? `embed de consulta: ${e.message}` : (e instanceof Error ? e.message : String(e)));
        }
      }));
    }
    const embedMs = Date.now() - e0;

    // 5. Puntuación por (cúpula, consulta).
    const perQuery: RagHit[][][] = req.queries.map(() => []);
    for (const p of ready) {
      const vecs = queryVecs.get(p.store.manifest.generation);
      const mode: RagMode = vecs ? opt.mode : 'bm25';
      req.queries.forEach((query, qi) => {
        const hits: StoreHit[] = searchStore({
          store: p.store, query, queryVec: vecs?.[qi], mode, k: opt.k, cfg: p.cfg,
          pathPrefix: req.pathPrefix, includeStale: req.includeStale,
        });
        perQuery[qi].push(hits.map(h => ({ ...h, dome: p.d.name, confidentiality: p.d.confidentiality })));
      });
    }

    // 6. Fusión por rango entre cúpulas y, si hay varias consultas, global.
    const results = req.queries.map((query, qi) => ({
      query,
      hits: applyCharBudget(fuseAcross(perQuery[qi], opt.k), opt.maxChars),
    }));
    const merged = req.queries.length > 1
      ? applyCharBudget(fuseAcross(results.map(r => r.hits), opt.k), opt.maxChars)
      : undefined;

    return {
      results,
      ...(merged ? { merged } : {}),
      domes: targets.map(d => outcomes.get(d.name)!),
      timings: { totalMs: Date.now() - t0, embedMs, syncMs },
    };
  }

  // ── Evaluación ───────────────────────────────────────────────────────

  async evaluate(name: string, queries: EvalQueryInput[], opts: { generation?: string; mode?: RagMode } = {}): Promise<RagEvalResult> {
    const d = this.dome(name);
    const cfg = this.config(d);
    const generation = opts.generation ?? readActive(this.home, name).active;
    if (!generation) throw new RagError('NOT_INDEXED', `${name} sin generación activa`);
    const store = this.loadStore(name, generation);
    const mode = opts.mode ?? 'hybrid';
    const emb = this.embedder({ ...cfg, model: store.manifest.contract.model });
    if (mode !== 'bm25') {
      const live = await emb.contract();
      if (generationId(live) !== generation) {
        throw new RagError('CONTRACT_MISMATCH', `el embedder vivo no corresponde a la generación ${generation}`);
      }
    }
    let recall5 = 0, recall10 = 0, mrr = 0;
    const times: number[] = [];
    const failed: RagEvalResult['failed'] = [];
    for (const q of queries) {
      const t = Date.now();
      const vecs = mode !== 'bm25' ? await emb.embed([q.query], 'query') : undefined;
      const hits = searchStore({ store, query: q.query, queryVec: vecs?.[0], mode, k: 20, cfg });
      times.push(Date.now() - t);
      const docs = [...new Set(hits.map(h => h.path))];
      const rel = new Set(q.relevantPaths);
      const at = (k: number) => docs.slice(0, k).filter(p => rel.has(p)).length / (rel.size || 1);
      recall5 += at(5);
      recall10 += at(10);
      const first = docs.findIndex(p => rel.has(p));
      mrr += first >= 0 ? 1 / (first + 1) : 0;
      if (first < 0 || first >= 10) failed.push({ query: q.query, relevant: q.relevantPaths, retrieved: docs.slice(0, 5) });
    }
    const n = queries.length || 1;
    return {
      n: queries.length, mode, generation,
      recallAt5: recall5 / n, recallAt10: recall10 / n, mrr: mrr / n,
      p50Ms: percentile(times, 50), p95Ms: percentile(times, 95), failed,
    };
  }

  // ── Estado y SLO (P7) ────────────────────────────────────────────────

  async status(names?: string[]): Promise<DomeStatusReport[]> {
    const list = names?.length ? names.map(n => this.dome(n)) : this.o.domes();
    const out: DomeStatusReport[] = [];
    for (const d of list) {
      const cfg = this.config(d);
      const pointer = readActive(this.home, d.name);
      const pending = await this.indexer(d, cfg).pending();
      const manifest = pointer.active ? FlatVectorStore.readManifest(path.join(domeDir(this.home, d.name), pointer.active)) : undefined;
      let currentDigest: string | undefined;
      let digestMatch = true;
      if (cfg.enabled && manifest) {
        try {
          const live = await this.embedder({ ...cfg, model: manifest.contract.model }).contract();
          currentDigest = live.modelDigest;
          digestMatch = live.modelDigest === manifest.contract.modelDigest;
        } catch {
          // proveedor caído: no es deriva de modelo; se refleja en búsqueda como degraded
        }
      }
      const slo = sloStatus({ enabled: cfg.enabled, hasGeneration: Boolean(manifest), totalDocs: pending.totalDocs, pendingDocs: pending.pendingDocs, digestMatch });
      out.push({
        name: d.name, enabled: cfg.enabled, confidentiality: d.confidentiality,
        active: pointer.active, shadow: pointer.shadow, previous: pointer.previous,
        contract: manifest?.contract, currentDigest, digestMatch,
        chunks: manifest?.chunkCount ?? 0,
        totalDocs: pending.totalDocs, pendingDocs: pending.pendingDocs,
        staleRatio: slo.staleRatio, lagHours: Number(pending.lagHours.toFixed(2)),
        generationAgeHours: manifest ? Number(((Date.now() - Date.parse(manifest.createdAt)) / 3.6e6).toFixed(2)) : undefined,
        memoryBytes: manifest ? manifest.chunkCount * manifest.contract.dims * 4 : 0,
        slo: { ok: slo.ok, alerts: slo.alerts },
      });
    }
    return out;
  }

  /** Comprueba que el home es seguro antes de operar (AC11). */
  ensureHome(): void {
    ensureSafeHome(this.home);
  }
}
