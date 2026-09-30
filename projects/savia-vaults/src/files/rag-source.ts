// SE-413 F3 — documentos de Savia Files como fuentes virtuales de Savia RAG.
// Cada chunk agrupa unidades consecutivas sin cruzar página ni diapositiva, y
// conserva documento, revisión y localizador para citar y abrir el original.
import * as fs from 'node:fs';
import { createHash } from 'node:crypto';
import type { Chunk, VirtualSource } from '../rag/types.js';
import type { FileStore } from './store.js';
import { FilesError, type ExtractUnit, type FileDocument, type FileRevision, type Locator } from './types.js';

export const FILES_CHUNKER_VERSION = 'files-v1';
export const FILES_PATH_PREFIX = 'files/';

export function locatorLabel(l: Locator): string {
  switch (l.type) {
    case 'page': return `p. ${l.page}`;
    case 'slide': return `diapositiva ${l.slide}`;
    case 'element': return `elemento ${l.index}`;
    case 'cell': return `${l.sheet}!${l.cell}`;
    case 'lines': return l.from === l.to ? `línea ${l.from}` : `líneas ${l.from}–${l.to}`;
    case 'row': return `fila ${l.row}`;
    case 'key': return `clave ${l.path}`;
  }
}

/** Página y diapositiva son fronteras duras: un chunk cita una sola. */
function boundary(l: Locator): string | undefined {
  if (l.type === 'page') return `p${l.page}`;
  if (l.type === 'slide') return `s${l.slide}`;
  if (l.type === 'cell') return `h${l.sheet}`;
  return undefined;
}

const same = (a: Locator, b: Locator) => JSON.stringify(a) === JSON.stringify(b);

export function chunkUnits(doc: FileDocument, rev: FileRevision, units: ExtractUnit[], chunkChars: number): Chunk[] {
  const docPath = `${FILES_PATH_PREFIX}${doc.id}`;
  const max = Math.max(100, chunkChars);
  const chunks: Chunk[] = [];
  let parts: string[] = [];
  let first: Locator | undefined;
  let last: Locator | undefined;

  const flush = () => {
    if (!parts.length || !first || !last) return;
    const text = parts.join('\n');
    const label = same(first, last) ? locatorLabel(first) : `${locatorLabel(first)} → ${locatorLabel(last)}`;
    const heading = `${doc.name} › ${label}`;
    const ordinal = chunks.length;
    chunks.push({
      id: `${docPath}#${ordinal}`, path: docPath, ordinal, heading, text,
      embedText: `${heading}\n\n${text}`, hash: '',
      meta: { title: doc.name, modified: rev.createdAt, ...(doc.confidentiality ? { confidentiality: doc.confidentiality } : {}) },
      source: {
        kind: 'file', documentId: doc.id, revisionId: rev.id, name: doc.name, locator: first,
        ...(same(first, last) ? {} : { locatorEnd: last }),
      },
    });
    parts = [];
    first = last = undefined;
  };

  for (const u of units) {
    const text = u.text.trim();
    if (!text) continue;
    if (first && boundary(first) !== boundary(u.locator)) flush();
    // Unidad mayor que el chunk: se parte en trozos del mismo localizador.
    if (text.length > max) {
      flush();
      for (let i = 0; i < text.length; i += max) {
        parts = [text.slice(i, i + max)];
        first = last = u.locator;
        flush();
      }
      continue;
    }
    const size = parts.reduce((n, p) => n + p.length + 1, 0);
    if (parts.length && size + text.length > max) flush();
    parts.push(text);
    first ??= u.locator;
    last = u.locator;
  }
  flush();
  return chunks;
}

const INDEXABLE = new Set(['READY', 'PARTIAL']);

/** Fuentes virtuales de la cúpula: la revisión vigente de cada documento con extracción útil. */
export function fileSources(store: FileStore): VirtualSource[] {
  if (!fs.existsSync(store.dir)) return [];
  const out: VirtualSource[] = [];
  for (const doc of store.list()) {
    const rev = doc.revisions.find((r) => r.id === doc.currentRevision);
    if (!rev || !INDEXABLE.has(rev.extraction.status)) continue;
    const hash = createHash('sha256')
      .update(`${rev.sha256}\n${rev.id}\n${rev.extraction.digest ?? ''}\n${doc.name}\n${doc.confidentiality ?? ''}\n${FILES_CHUNKER_VERSION}`)
      .digest('hex');
    out.push({
      path: `${FILES_PATH_PREFIX}${doc.id}`,
      hash,
      mtimeMs: Date.parse(rev.createdAt) || 0,
      confidentiality: doc.confidentiality,
      chunks: ({ chunkChars }) => {
        try {
          return chunkUnits(doc, rev, store.readExtraction(rev.id, doc.id).units, chunkChars);
        } catch (e) {
          // SE-414 S5: extracción manipulada o perdida: no se publica, el resto de la cúpula sí.
          if (e instanceof FilesError && (e.code === 'INTEGRITY' || e.code === 'NOT_FOUND')) return [];
          throw e;
        }
      },
    });
  }
  return out;
}
