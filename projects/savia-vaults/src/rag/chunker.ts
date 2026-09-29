import * as path from 'node:path';
import YAML from 'yaml';
import type { Chunk, ChunkMeta } from './types.js';

/**
 * SE-410 — Chunking markdown por encabezados.
 * Subir la versión cambia el contrato de embeddings (P8) y fuerza generación nueva.
 */
export const CHUNKER_VERSION = 'md-headings-v1';

export interface ChunkOptions {
  chunkChars: number;   // objetivo
  overlap: number;      // fracción 0..0.5
  maxChars?: number;    // tope duro (def. max(2000, chunkChars))
  minChars?: number;    // secciones menores se fusionan con la siguiente (def. 200)
  mtime?: Date;
}

interface Section {
  headings: string[];
  text: string;
}

export interface ParsedNote {
  meta: ChunkMeta;
  body: string;
}

function asString(v: unknown): string | undefined {
  if (v === undefined || v === null) return undefined;
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  const s = String(v).trim();
  return s.length ? s : undefined;
}

/** Separa frontmatter YAML y extrae los metadatos de frescura (P6). */
export function parseNote(relPath: string, raw: string, mtime?: Date): ParsedNote {
  let body = raw;
  let fm: Record<string, unknown> = {};
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (match) {
    body = match[2];
    try {
      const parsed = YAML.parse(match[1]);
      if (parsed && typeof parsed === 'object') fm = parsed as Record<string, unknown>;
    } catch {
      // frontmatter inválido: se indexa el cuerpo sin metadatos
    }
  }
  let title = asString(fm.title);
  if (!title) {
    const h1 = body.match(/^#\s+(.+)$/m);
    title = h1 ? h1[1].trim() : path.basename(relPath, path.extname(relPath));
  }
  const modified = asString(fm.modified) ?? asString(fm.updated) ?? asString(fm.date)
    ?? (mtime ? mtime.toISOString() : new Date(0).toISOString());
  return {
    meta: {
      title,
      status: asString(fm.status)?.toLowerCase(),
      validUntil: asString(fm.valid_until),
      supersededBy: asString(fm.superseded_by),
      modified,
      confidentiality: asString(fm.confidentiality)?.toUpperCase(),
    },
    body,
  };
}

/** Divide el cuerpo en secciones por encabezado, ignorando bloques de código. */
function splitSections(body: string): Section[] {
  const sections: Section[] = [];
  const stack: { level: number; text: string }[] = [];
  let current: string[] = [];
  let inFence = false;

  const flush = () => {
    const text = current.join('\n').trim();
    if (text) sections.push({ headings: stack.map(h => h.text), text });
    current = [];
  };

  for (const line of body.split(/\r?\n/)) {
    if (/^\s*(```|~~~)/.test(line)) inFence = !inFence;
    const h = !inFence ? line.match(/^(#{1,6})\s+(.+?)\s*#*\s*$/) : null;
    if (h) {
      flush();
      const level = h[1].length;
      while (stack.length && stack[stack.length - 1].level >= level) stack.pop();
      stack.push({ level, text: h[2].trim() });
      continue;
    }
    current.push(line);
  }
  flush();
  return sections;
}

/** Corta un texto largo en ventanas con solape, prefiriendo límites de párrafo o frase. */
function windows(text: string, target: number, maxChars: number, overlap: number): string[] {
  if (text.length <= maxChars) return [text];
  const out: string[] = [];
  const overlapChars = Math.floor(target * overlap);
  let start = 0;
  while (start < text.length) {
    let end = Math.min(text.length, start + target);
    if (end < text.length) {
      const slice = text.slice(start, end);
      const para = slice.lastIndexOf('\n\n');
      const sentence = Math.max(slice.lastIndexOf('. '), slice.lastIndexOf('.\n'));
      const cut = para > target * 0.5 ? para : sentence > target * 0.5 ? sentence + 1 : -1;
      if (cut > 0) end = start + cut;
    }
    const piece = text.slice(start, end).trim();
    if (piece) out.push(piece);
    if (end >= text.length) break;
    start = Math.max(start + 1, end - overlapChars);
  }
  return out;
}

export function chunkMarkdown(relPath: string, raw: string, opts: ChunkOptions): Chunk[] {
  const { meta, body } = parseNote(relPath, raw, opts.mtime);
  const target = Math.max(200, opts.chunkChars);
  const maxChars = opts.maxChars ?? Math.max(2000, target);
  const minChars = opts.minChars ?? 200;
  const overlap = Math.min(0.5, Math.max(0, opts.overlap));

  // Fusiona secciones cortas con la siguiente, conservando el encabezado de la primera.
  const merged: Section[] = [];
  let pending: Section | undefined;
  for (const s of splitSections(body)) {
    if (pending) {
      const headingLine = s.headings.length ? `${s.headings[s.headings.length - 1]}\n` : '';
      pending = { headings: pending.headings, text: `${pending.text}\n\n${headingLine}${s.text}` };
    } else {
      pending = s;
    }
    if (pending.text.length >= minChars) {
      merged.push(pending);
      pending = undefined;
    }
  }
  if (pending) {
    if (merged.length) {
      const last = merged[merged.length - 1];
      last.text = `${last.text}\n\n${pending.text}`;
    } else {
      merged.push(pending);
    }
  }

  const chunks: Chunk[] = [];
  for (const s of merged) {
    const headingPath = [meta.title, ...s.headings.filter(h => h !== meta.title)].join(' › ');
    for (const piece of windows(s.text, target, maxChars, overlap)) {
      const ordinal = chunks.length;
      chunks.push({
        id: `${relPath}#${ordinal}`,
        path: relPath,
        ordinal,
        heading: headingPath,
        text: piece,
        embedText: `${headingPath}\n\n${piece}`,
        hash: '',
        meta,
      });
    }
  }
  return chunks;
}
