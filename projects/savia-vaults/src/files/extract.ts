// SE-413 F2 / SE-415 — extracción con localizador: TS para texto (TXT/MD/CSV/JSON, UTF-8
// o Windows-1252) y worker Python aislado por lotes (Docling sin OCR + openpyxl) para
// PDF/DOCX/PPTX/XLSX. Cobertura declarada: sin unidades nunca es READY.
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import type { FileStore } from './store.js';
import { CLAMSCAN_MAX_BYTES, scanFiles, scanStream, type ScanMode } from './scan.js';
import { Tools } from './setup.js';
import { inspectZipFile } from './zip-guard.js';
import { sodiumReady } from './crypto.js';
import type { ExtractUnit, ExtractionInfo, FileType, Locator, TextEncoding } from './types.js';

const MAX_UNITS = 50_000;
const BLOCK_LINES = 60;
const BLOCK_CHARS = 4_000;
const WORKER_MAX_OUTPUT = 64 * 1024 * 1024;
const WORKER_TYPES = new Set<FileType>(['pdf', 'docx', 'pptx', 'xlsx']);
const LOCATOR_TYPES = new Set(['page', 'slide', 'element', 'cell', 'lines', 'row', 'key']);

export interface RawExtraction {
  method: string;
  units: ExtractUnit[];
  skipped: { reason: string; count: number }[];
}

/**
 * Intérprete del worker: `SAVIA_FILES_PYTHON`, después el extractor instalado por
 * `files setup` (SE-416) y, por compatibilidad, el venv manual de SE-413.
 */
export function defaultPython(): string {
  return process.env.SAVIA_FILES_PYTHON
    || new Tools().pythonPath()
    || path.join(os.homedir(), '.savia-vaults', 'files-venv', 'bin', 'python');
}

export function workerScript(): string {
  return fileURLToPath(new URL('../../workers/files/extract.py', import.meta.url));
}

function linesUnits(text: string): ExtractUnit[] {
  const lines = text.replace(/\r\n?/g, '\n').split('\n');
  const units: ExtractUnit[] = [];
  let start = -1;
  let buf: string[] = [];
  const flush = (end: number) => {
    if (buf.length) units.push({ locator: { type: 'lines', from: start + 1, to: end + 1 }, kind: 'text', text: buf.join('\n') });
    buf = [];
    start = -1;
  };
  lines.forEach((line, i) => {
    if (!line.trim()) return flush(i - 1);
    if (start < 0) start = i;
    buf.push(line);
    if (buf.length >= BLOCK_LINES || buf.join('\n').length >= BLOCK_CHARS) flush(i);
  });
  flush(lines.length - 1);
  return units;
}

/** Parser CSV RFC 4180 mínimo: comillas, "" escapado, saltos de línea dentro de comillas. */
export function parseCsv(text: string): string[][] {
  const firstLine = text.slice(0, text.indexOf('\n') >>> 0);
  const sep = (firstLine.match(/;/g)?.length ?? 0) > (firstLine.match(/,/g)?.length ?? 0) ? ';' : ',';
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"' && field === '') quoted = true;
    else if (ch === sep) { row.push(field); field = ''; }
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(field); rows.push(row); row = []; field = '';
    } else field += ch;
  }
  if (field !== '' || row.length) { row.push(field); rows.push(row); }
  return rows;
}

function csvUnits(text: string): ExtractUnit[] {
  const [header, ...rows] = parseCsv(text);
  if (!header) return [];
  return rows.flatMap((cells, i) => {
    if (cells.every((c) => !c.trim())) return [];
    const parts = cells.map((c, j) => `${header[j]?.trim() || `col${j + 1}`}: ${c.trim()}`);
    return [{ locator: { type: 'row', row: i + 2 } as Locator, kind: 'row', text: parts.join(' | ') }];
  });
}

const MAX_JSON_DEPTH = 64;

/**
 * JSON aplanado por clave, iterativo (sin desbordar la pila). Declara lo omitido:
 * hojas por encima del tope (`max-units`) y subárboles más hondos de 64 (`max-depth`).
 */
function jsonUnits(text: string): { units: ExtractUnit[]; skipped: RawExtraction['skipped'] } {
  const units: ExtractUnit[] = [];
  let overflow = 0;
  let tooDeep = 0;
  const stack: { v: unknown; p: string; depth: number }[] = [{ v: JSON.parse(text), p: '', depth: 0 }];
  while (stack.length) {
    const { v, p, depth } = stack.pop()!;
    if (v !== null && typeof v === 'object') {
      if (depth >= MAX_JSON_DEPTH) { tooDeep++; continue; }
      const entries: [string, unknown][] = Array.isArray(v)
        ? v.map((x, i) => [`${p}[${i}]`, x])
        : Object.entries(v).map(([k, x]) => [p ? `${p}.${k}` : k, x]);
      for (let i = entries.length - 1; i >= 0; i--) stack.push({ v: entries[i][1], p: entries[i][0], depth: depth + 1 });
      continue;
    }
    if (units.length >= MAX_UNITS) { overflow++; continue; }
    const key = p || '$';
    units.push({ locator: { type: 'key', path: key }, kind: 'value', text: `${key}: ${v === null ? 'null' : String(v)}` });
  }
  const skipped: RawExtraction['skipped'] = [];
  if (overflow) skipped.push({ reason: 'max-units', count: overflow });
  if (tooDeep) skipped.push({ reason: 'max-depth', count: tooDeep });
  return { units, skipped };
}

/** Extracción sin dependencias de los formatos de texto. JSON inválido lanza. */
export function extractTextual(type: FileType, bytes: Buffer, encoding: TextEncoding = 'utf-8'): RawExtraction {
  const text = new TextDecoder(encoding).decode(bytes).replace(/^\uFEFF/, '');
  const method = encoding === 'utf-8' ? 'text' : `text-${encoding}`;
  if (type === 'json') return { method, ...jsonUnits(text) };
  const units = type === 'csv' ? csvUnits(text) : linesUnits(text);
  const skipped = units.length > MAX_UNITS ? [{ reason: 'max-units', count: units.length - MAX_UNITS }] : [];
  return { method, units: units.slice(0, MAX_UNITS), skipped };
}

function validUnit(u: unknown): u is ExtractUnit {
  const x = u as ExtractUnit;
  return !!x && typeof x.text === 'string' && typeof x.kind === 'string'
    && !!x.locator && LOCATOR_TYPES.has(x.locator.type);
}

const OOXML_TYPES = new Set<FileType>(['docx', 'pptx', 'xlsx']);
const ZIP_MAX_RATIO = 200;
const ZIP_MAX_ENTRIES = 10_000;

/**
 * SE-414 S2: semáforo por proceso para el worker Python (≈1,2 GB de RAM cada uno).
 * `SAVIA_FILES_WORKERS` (def. 1) se lee en cada adquisición.
 */
let running = 0;
const waiting: (() => void)[] = [];
async function withWorkerSlot<T>(fn: () => Promise<T>): Promise<T> {
  const max = Math.max(1, Number(process.env.SAVIA_FILES_WORKERS) || 1);
  while (running >= max) await new Promise<void>((r) => waiting.push(r));
  running++;
  try {
    return await fn();
  } finally {
    running--;
    waiting.shift()?.();
  }
}

function parseWorkerResult(parsed: { error?: string; method?: string; units?: unknown[]; skipped?: RawExtraction['skipped'] }): RawExtraction | Error {
  if (parsed.error) return new Error(parsed.error);
  const all = Array.isArray(parsed.units) ? parsed.units : [];
  const units = all.filter(validUnit);
  const skipped = [...(parsed.skipped ?? [])];
  if (units.length < all.length) skipped.push({ reason: 'invalid-unit', count: all.length - units.length });
  return { method: String(parsed.method ?? 'worker'), units, skipped };
}

/**
 * SE-415 E2: un proceso Python para un lote de ficheros (Docling se carga una vez).
 * Entorno reducido, sin red de modelos, timeout por fichero y total, salida acotada.
 * Devuelve un resultado por fichero, en orden; los no devueltos (caída o timeout), Error.
 */
export function runWorkerBatch(items: { type: FileType; file: string }[], python: string, timeoutMs: number): Promise<(RawExtraction | Error)[]> {
  const env: NodeJS.ProcessEnv = {
    PATH: process.env.PATH, HOME: process.env.HOME, LANG: 'C.UTF-8',
    HF_HUB_OFFLINE: '1', TRANSFORMERS_OFFLINE: '1', PYTHONDONTWRITEBYTECODE: '1',
    SAVIA_FILES_ITEM_TIMEOUT_S: String(Math.max(1, Math.ceil(timeoutMs / 1000))),
  };
  const total = timeoutMs * items.length;
  return new Promise((resolve) => {
    const child = execFile(python, [workerScript(), '--batch'],
      { env, timeout: total, killSignal: 'SIGKILL', maxBuffer: WORKER_MAX_OUTPUT, encoding: 'utf-8' },
      (err, stdout) => {
        const lines = String(stdout ?? '').split('\n').filter((l) => l.trim());
        const killed = err && (err.killed || err.signal === 'SIGKILL');
        const tooBig = err && /maxBuffer/i.test(err.message);
        resolve(items.map((_, i) => {
          if (i < lines.length && !tooBig) {
            try { return parseWorkerResult(JSON.parse(lines[i])); } catch { return new Error('worker sin salida válida'); }
          }
          if (tooBig) return new Error('salida del worker demasiado grande');
          if (killed) return new Error(`timeout del worker (${total} ms)`);
          return new Error(`el worker terminó sin devolver este fichero${err ? `: ${err.message.slice(0, 200)}` : ''}`);
        }));
      });
    child.stdin?.on('error', () => undefined); // el worker puede cerrar stdin antes de leerlo todo
    child.stdin?.end(items.map((it) => JSON.stringify({ type: it.type, path: it.file })).join('\n') + '\n');
  });
}

export interface ProcessOptions {
  revisionId?: string;
  scan?: ScanMode;
  clamscan?: string;
  python?: string;
  timeoutMs?: number;
}

const sum = (s: { count: number }[]) => s.reduce((a, b) => a + b.count, 0);

/** SE-415 Q1: sin ninguna unidad nunca es READY: ARCHIVE_ONLY con los motivos (o `empty`). */
function finish(raw: RawExtraction, scanSkips: RawExtraction['skipped']): ExtractionInfo {
  const units = raw.units.length;
  if (units === 0) {
    const skipped = [...(raw.skipped.length ? raw.skipped : [{ reason: 'empty', count: 1 }]), ...scanSkips];
    return { status: 'ARCHIVE_ONLY', method: raw.method, units: sum(raw.skipped), extracted: 0, skipped };
  }
  const skipped = [...raw.skipped, ...scanSkips];
  return { status: skipped.length ? 'PARTIAL' : 'READY', method: raw.method, units: units + sum(raw.skipped), extracted: units, skipped };
}

interface Pending {
  documentId: string;
  revisionId: string;
  scanSkips: RawExtraction['skipped'];
  info?: ExtractionInfo;
  units: ExtractUnit[];
  job?: { type: FileType; file: string };
}

/**
 * Escanea, extrae y registra estado y cobertura de varias revisiones. Las que
 * necesitan el worker se extraen juntas en un solo proceso (SE-415 E2).
 */
export async function processRevisions(
  store: FileStore, items: { documentId: string; revisionId?: string }[], opts: ProcessOptions = {},
): Promise<ExtractionInfo[]> {
  await sodiumReady();
  const python = opts.python ?? defaultPython();
  const pending: Pending[] = [];
  // Existencia e integridad de todo el lote antes de nada; después, un solo análisis antivirus (SE-416).
  // En cúpulas cifradas (SE-417), antivirus y worker leen una copia en memoria que se borra siempre.
  const plains: string[] = [];
  try {
    // SE-421: nada se carga entero en memoria. Hasta `maxExtractBytes` hay copia legible (el blob en
    // claras o una copia en memoria en cifradas); por encima, en cifradas, el antivirus lee por stdin
    // descifrando al vuelo y no hay extracción.
    const revs = items.map((it) => {
      const rev = store.revision(it.documentId, it.revisionId);
      const tooBig = rev.size > store.limits.maxExtractBytes;
      let blob: string | undefined;
      if (!rev.enc) blob = store.plainPath(it.documentId, rev.id);
      else if (!tooBig) { blob = store.plainPath(it.documentId, rev.id); plains.push(blob); }
      return { it, rev, blob, tooBig };
    });
    const mode = opts.scan ?? 'auto';
    // Por encima del tope de clamscan no se escanea por ruta (diría «OK» sin haberlo leído entero).
    const byPath = revs.filter((r) => r.blob && r.rev.size <= CLAMSCAN_MAX_BYTES);
    const pathScans = await scanFiles(byPath.map((r) => r.blob!), { mode, clamscan: opts.clamscan });
    const scans = new Map(byPath.map((r, i) => [r.rev.id, pathScans[i]]));
    for (const r of revs.filter((x) => !scans.has(x.rev.id))) {
      scans.set(r.rev.id, await scanStream(() => store.openRead(r.it.documentId, r.rev.id).stream, r.rev.size, { mode, clamscan: opts.clamscan }));
    }
    for (const { it, rev, blob, tooBig } of revs) {
      const p: Pending = { documentId: it.documentId, revisionId: rev.id, scanSkips: [], units: [] };
      pending.push(p);
      const scan = scans.get(rev.id)!;
      if (scan.verdict === 'infected') {
        p.info = { status: 'QUARANTINED', method: 'clamscan', units: 0, extracted: 0, skipped: [], error: scan.signature };
        continue;
      }
      p.scanSkips = scan.verdict === 'error'
        ? [{ reason: scan.detail === 'too-large-to-scan' ? 'too-large-to-scan' : 'scan-error', count: 1 }]
        : [];
      if (rev.type !== 'unknown' && tooBig) {
        // SE-421: descargable y citable como fichero, sin texto (ni worker ni lectura entera).
        p.info = { status: 'ARCHIVE_ONLY', method: 'none', units: 0, extracted: 0, skipped: [...p.scanSkips, { reason: 'too-large-to-extract', count: 1 }] };
        continue;
      }
      const zip = OOXML_TYPES.has(rev.type) && blob
        ? inspectZipFile(blob, { maxUnzippedBytes: store.limits.maxUnzippedBytes, maxRatio: ZIP_MAX_RATIO, maxEntries: ZIP_MAX_ENTRIES })
        : undefined;
      if (rev.type === 'unknown') {
        p.info = { ...rev.extraction, status: 'ARCHIVE_ONLY' };
      } else if (zip && !zip.ok) {
        // SE-414 S1: bomba de descompresión o ZIP inválido; el worker no llega a lanzarse.
        p.info = { status: 'FAILED', method: 'zip-guard', units: 0, extracted: 0, skipped: p.scanSkips, error: `decompression-limit: ${zip.reason}` };
      } else if (WORKER_TYPES.has(rev.type) && !fs.existsSync(python)) {
        p.info = { status: 'ARCHIVE_ONLY', method: 'none', units: 0, extracted: 0, skipped: [{ reason: 'worker-missing', count: 1 }] };
      } else if (WORKER_TYPES.has(rev.type)) {
        p.job = { type: rev.type, file: blob! };
      } else {
        try {
          const raw = extractTextual(rev.type, fs.readFileSync(blob!), rev.encoding ?? 'utf-8');
          p.units = raw.units;
          p.info = finish(raw, p.scanSkips);
        } catch (e) {
          p.info = { status: 'FAILED', method: 'text', units: 0, extracted: 0, skipped: p.scanSkips, error: (e as Error).message.slice(0, 500) };
        }
      }
    }
    const jobs = pending.filter((p) => p.job);
    if (jobs.length) {
      const results = await withWorkerSlot(() => runWorkerBatch(
        jobs.map((p) => p.job!), python, opts.timeoutMs ?? store.limits.extractTimeoutMs));
      jobs.forEach((p, i) => {
        const r = results[i];
        if (r instanceof Error) {
          p.info = { status: 'FAILED', method: 'worker', units: 0, extracted: 0, skipped: p.scanSkips, error: r.message.slice(0, 500) };
        } else {
          p.units = r.units;
          p.info = finish(r, p.scanSkips);
        }
      });
    }
    for (const p of pending) {
      if (p.info!.status === 'QUARANTINED') store.setExtraction(p.revisionId, p.info!, p.documentId);
      else store.saveExtraction(p.revisionId, { units: p.units }, p.info, p.documentId);
    }
    return pending.map((p) => p.info!);
  } finally {
    for (const f of plains) store.releasePlain(f);
  }
}

/** Escanea (si procede), extrae y registra estado y cobertura de una revisión. */
export async function processRevision(store: FileStore, documentId: string, opts: ProcessOptions = {}): Promise<ExtractionInfo> {
  const [info] = await processRevisions(store, [{ documentId, revisionId: opts.revisionId }], opts);
  return info;
}
