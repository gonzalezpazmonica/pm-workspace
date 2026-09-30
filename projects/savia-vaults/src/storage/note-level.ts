// SE-420 — nivel por nota: una nota cuyo `confidentiality` (frontmatter) supera el de su cúpula
// está «fuera de nivel» y no se sirve por ninguna vista (almacén, búsqueda, grafo, A2A, RAG).
// Única fuente de la regla: el indexador de Savia RAG usa la misma función (CRIT-001).
import * as fs from 'node:fs';
import { parseNote } from '../rag/chunker.js';

const LEVELS = ['N1', 'N2', 'N3', 'N4', 'N4B'];

/** CRIT-001: true si el nivel de la nota supera el de la cúpula. Niveles desconocidos no cuentan. */
export function exceedsDomeLevel(noteLevel: string | undefined, domeLevel: string): boolean {
  if (!noteLevel) return false;
  const n = LEVELS.indexOf(noteLevel.toUpperCase());
  const d = LEVELS.indexOf(domeLevel.toUpperCase());
  if (n < 0) return false;
  return n > (d < 0 ? 1 : d);
}

/**
 * Nivel declarado en el frontmatter de un markdown, con la misma semántica que `parseNote` de RAG.
 * Atajo: sin frontmatter o sin la clave `confidentiality` en él, no hay nivel (evita el YAML).
 */
export function noteLevel(relPath: string, raw: string): string | undefined {
  if (!raw.startsWith('---')) return undefined;
  const fm = raw.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/);
  if (fm && !fm[1].includes('confidentiality')) return undefined; // si no casa, decide parseNote
  return parseNote(relPath, raw).meta.confidentiality;
}

export function contentOutOfLevel(relPath: string, raw: string, domeLevel: string | undefined): boolean {
  return !!domeLevel && exceedsDomeLevel(noteLevel(relPath, raw), domeLevel);
}

const MD = /\.(md|markdown)$/i;
const cache = new Map<string, { key: string; level: string | undefined }>();

/** Nota en disco fuera de nivel; caché por ruta + mtime + tamaño. Sin nivel de cúpula, nunca. */
export function fileOutOfLevel(fullPath: string, relPath: string, domeLevel: string | undefined): boolean {
  if (!domeLevel || !MD.test(fullPath)) return false;
  let st: fs.Stats;
  try { st = fs.statSync(fullPath); } catch { return false; }
  const key = `${st.mtimeMs}:${st.size}`;
  let hit = cache.get(fullPath);
  if (!hit || hit.key !== key) {
    let level: string | undefined;
    try { level = noteLevel(relPath, fs.readFileSync(fullPath, 'utf-8')); } catch { level = undefined; }
    hit = { key, level };
    cache.set(fullPath, hit);
  }
  return exceedsDomeLevel(hit.level, domeLevel);
}
