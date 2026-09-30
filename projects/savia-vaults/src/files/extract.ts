// SE-413 F2 — extracción con localizador: TS para texto (TXT/MD/CSV/JSON) y worker
// Python aislado (Docling sin OCR + openpyxl) para PDF/DOCX/PPTX/XLSX.
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import type { FileStore } from './store.js';
import { scanFile, type ScanMode } from './scan.js';
import type { ExtractUnit, ExtractionInfo, FileType, Locator } from './types.js';

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

export function defaultPython(): string {
  return process.env.SAVIA_FILES_PYTHON || path.join(os.homedir(), '.savia-vaults', 'files-venv', 'bin', 'python');
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

function jsonUnits(text: string): ExtractUnit[] {
  const units: ExtractUnit[] = [];
  const walk = (v: unknown, p: string) => {
    if (units.length >= MAX_UNITS) return;
    if (Array.isArray(v)) return v.forEach((x, i) => walk(x, `${p}[${i}]`));
    if (v !== null && typeof v === 'object') {
      return Object.entries(v).forEach(([k, x]) => walk(x, p ? `${p}.${k}` : k));
    }
    const key = p || '$';
    units.push({ locator: { type: 'key', path: key }, kind: 'value', text: `${key}: ${v === null ? 'null' : String(v)}` });
  };
  walk(JSON.parse(text), '');
  return units;
}

/** Extracción sin dependencias de los formatos de texto. JSON inválido lanza. */
export function extractTextual(type: FileType, bytes: Buffer): RawExtraction {
  const text = bytes.toString('utf-8').replace(/^﻿/, '');
  const units = type === 'csv' ? csvUnits(text) : type === 'json' ? jsonUnits(text) : linesUnits(text);
  const skipped = units.length > MAX_UNITS ? [{ reason: 'max-units', count: units.length - MAX_UNITS }] : [];
  return { method: 'text', units: units.slice(0, MAX_UNITS), skipped };
}

function validUnit(u: unknown): u is ExtractUnit {
  const x = u as ExtractUnit;
  return !!x && typeof x.text === 'string' && typeof x.kind === 'string'
    && !!x.locator && LOCATOR_TYPES.has(x.locator.type);
}

/** Proceso Python aparte: entorno reducido, sin red de modelos, timeout y salida acotada. */
export function runWorker(type: FileType, file: string, python: string, timeoutMs: number): Promise<RawExtraction> {
  const env: NodeJS.ProcessEnv = {
    PATH: process.env.PATH, HOME: process.env.HOME, LANG: 'C.UTF-8',
    HF_HUB_OFFLINE: '1', TRANSFORMERS_OFFLINE: '1', PYTHONDONTWRITEBYTECODE: '1',
  };
  return new Promise((resolve, reject) => {
    execFile(python, [workerScript(), type, file],
      { env, timeout: timeoutMs, killSignal: 'SIGKILL', maxBuffer: WORKER_MAX_OUTPUT, encoding: 'utf-8' },
      (err, stdout) => {
        if (err && (err.killed || err.signal === 'SIGKILL')) return reject(new Error(`timeout del worker (${timeoutMs} ms)`));
        if (err && /maxBuffer/i.test(err.message)) return reject(new Error('salida del worker demasiado grande'));
        let parsed: { error?: string; method?: string; units?: unknown[]; skipped?: RawExtraction['skipped'] };
        try { parsed = JSON.parse(stdout); } catch { return reject(new Error(`worker sin salida válida: ${err?.message ?? 'vacía'}`)); }
        if (parsed.error || err) return reject(new Error(parsed.error ?? err!.message));
        const all = Array.isArray(parsed.units) ? parsed.units : [];
        const units = all.filter(validUnit);
        const skipped = [...(parsed.skipped ?? [])];
        if (units.length < all.length) skipped.push({ reason: 'invalid-unit', count: all.length - units.length });
        resolve({ method: String(parsed.method ?? 'worker'), units, skipped });
      });
  });
}

export interface ProcessOptions {
  revisionId?: string;
  scan?: ScanMode;
  clamscan?: string;
  python?: string;
  timeoutMs?: number;
}

const total = (s: { count: number }[]) => s.reduce((a, b) => a + b.count, 0);

/** Escanea (si procede), extrae y registra estado y cobertura de una revisión. */
export async function processRevision(store: FileStore, documentId: string, opts: ProcessOptions = {}): Promise<ExtractionInfo> {
  const rev = store.revision(documentId, opts.revisionId);
  const blob = store.blobPath(rev.sha256);
  store.readBytes(documentId, rev.id); // verifica existencia e integridad antes de nada
  const scan = await scanFile(blob, { mode: opts.scan ?? 'auto', clamscan: opts.clamscan });
  if (scan.verdict === 'infected') {
    const info: ExtractionInfo = { status: 'QUARANTINED', method: 'clamscan', units: 0, extracted: 0, skipped: [], error: scan.signature };
    store.setExtraction(rev.id, info);
    return info;
  }
  const scanSkips = scan.verdict === 'error' ? [{ reason: 'scan-error', count: 1 }] : [];
  let info: ExtractionInfo;
  let units: ExtractUnit[] = [];
  if (rev.type === 'unknown') {
    info = { ...rev.extraction, status: 'ARCHIVE_ONLY' };
  } else if (WORKER_TYPES.has(rev.type) && !fs.existsSync(opts.python ?? defaultPython())) {
    info = { status: 'ARCHIVE_ONLY', method: 'none', units: 0, extracted: 0, skipped: [{ reason: 'worker-missing', count: 1 }] };
  } else {
    try {
      const raw = WORKER_TYPES.has(rev.type)
        ? await runWorker(rev.type, blob, opts.python ?? defaultPython(), opts.timeoutMs ?? store.limits.extractTimeoutMs)
        : extractTextual(rev.type, store.readBytes(documentId, rev.id));
      units = raw.units;
      const skipped = [...raw.skipped, ...scanSkips];
      info = {
        status: skipped.length ? 'PARTIAL' : 'READY', method: raw.method,
        units: units.length + total(raw.skipped), extracted: units.length, skipped,
      };
    } catch (e) {
      info = { status: 'FAILED', method: WORKER_TYPES.has(rev.type) ? 'worker' : 'text', units: 0, extracted: 0,
        skipped: scanSkips, error: (e as Error).message.slice(0, 500) };
    }
  }
  store.saveExtraction(rev.id, { units }, info);
  return info;
}
