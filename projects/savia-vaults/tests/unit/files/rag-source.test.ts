// SE-413 F3 — ficheros como fuente de Savia RAG: troceado por localizador y fuentes virtuales
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { chunkUnits, fileSources, locatorLabel, FILES_PATH_PREFIX } from '../../../src/files/rag-source.js';
import { FileStore } from '../../../src/files/store.js';
import { processRevision } from '../../../src/files/extract.js';
import type { ExtractUnit, FileDocument, FileRevision } from '../../../src/files/types.js';

const rev = { id: 'r_0000000000000001', sha256: 'a'.repeat(64), createdAt: '2026-09-30T00:00:00.000Z' } as FileRevision;
const doc = { id: 'f_0000000000000001', name: 'contrato.pdf', currentRevision: rev.id, confidentiality: 'N2' } as FileDocument;

describe('locatorLabel', () => {
  it('etiqueta legible para citar', () => {
    expect(locatorLabel({ type: 'page', page: 3 })).toBe('p. 3');
    expect(locatorLabel({ type: 'slide', slide: 2 })).toBe('diapositiva 2');
    expect(locatorLabel({ type: 'cell', sheet: 'Hoja', cell: 'B3' })).toBe('Hoja!B3');
    expect(locatorLabel({ type: 'lines', from: 3, to: 4 })).toBe('líneas 3–4');
    expect(locatorLabel({ type: 'row', row: 2 })).toBe('fila 2');
    expect(locatorLabel({ type: 'key', path: 'a.b' })).toBe('clave a.b');
    expect(locatorLabel({ type: 'element', index: 5 })).toBe('elemento 5');
  });
});

describe('chunkUnits', () => {
  it('no mezcla páginas: cada chunk cita una sola página', () => {
    const units: ExtractUnit[] = [
      { locator: { type: 'page', page: 1 }, kind: 'text', text: 'Cláusula 1' },
      { locator: { type: 'page', page: 1 }, kind: 'text', text: 'sigue' },
      { locator: { type: 'page', page: 2 }, kind: 'text', text: 'Cláusula 7' },
    ];
    const chunks = chunkUnits(doc, rev, units, 1200);
    expect(chunks).toHaveLength(2);
    expect(chunks[0]).toMatchObject({
      id: `${FILES_PATH_PREFIX}${doc.id}#0`, path: `${FILES_PATH_PREFIX}${doc.id}`,
      heading: 'contrato.pdf › p. 1', text: 'Cláusula 1\nsigue',
      source: { kind: 'file', documentId: doc.id, revisionId: rev.id, name: 'contrato.pdf', locator: { type: 'page', page: 1 } },
    });
    expect(chunks[0].source?.locatorEnd).toBeUndefined();
    expect(chunks[1].source?.locator).toEqual({ type: 'page', page: 2 });
    expect(chunks[1].embedText).toContain('contrato.pdf › p. 2');
    expect(chunks[0].meta).toMatchObject({ title: 'contrato.pdf', modified: rev.createdAt, confidentiality: 'N2' });
  });

  it('celdas: agrupa por tamaño y declara rango de localizadores', () => {
    const units: ExtractUnit[] = Array.from({ length: 40 }, (_, i) => ({
      locator: { type: 'cell', sheet: 'H', cell: `A${i + 1}` }, kind: 'cell', text: `H!A${i + 1}: valor número ${i}`,
    }));
    const chunks = chunkUnits(doc, rev, units, 200);
    expect(chunks.length).toBeGreaterThan(3);
    for (const c of chunks) expect(c.text.length).toBeLessThanOrEqual(200);
    expect(chunks[0].source?.locator).toEqual({ type: 'cell', sheet: 'H', cell: 'A1' });
    expect(chunks[0].source?.locatorEnd?.type).toBe('cell');
    expect(chunks.map((c) => c.text).join('\n')).toContain('H!A40');
  });

  it('una unidad mayor que chunkChars se parte sin perder texto', () => {
    const big = 'x'.repeat(2500);
    const chunks = chunkUnits(doc, rev, [{ locator: { type: 'page', page: 1 }, kind: 'text', text: big }], 1000);
    expect(chunks).toHaveLength(3);
    expect(chunks.map((c) => c.text).join('')).toBe(big);
  });
});

describe('fileSources', () => {
  let home: string;
  let store: FileStore;
  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-src-'));
    store = new FileStore({ home, dome: 'D' });
  });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  it('solo revisiones vigentes con extracción READY/PARTIAL', async () => {
    const ok = store.add({ name: 'a.txt', bytes: Buffer.from('uno\n\ndos') });
    await processRevision(store, ok.document.id, { scan: 'off' });
    store.add({ name: 'b.bin', bytes: Buffer.from([0, 1]) }); // ARCHIVE_ONLY
    store.add({ name: 'c.txt', bytes: Buffer.from('pendiente') }); // PENDING
    const broken = store.add({ name: 'd.json', bytes: Buffer.from('{') });
    await processRevision(store, broken.document.id, { scan: 'off' }); // FAILED
    const sources = fileSources(store);
    expect(sources.map((s) => s.path)).toEqual([`${FILES_PATH_PREFIX}${ok.document.id}`]);
    expect(sources[0].chunks({ chunkChars: 1200, overlap: 0 }).map((c) => c.text)).toEqual(['uno\ndos']);
  });

  it('una revisión nueva cambia el hash de la fuente; la misma no', async () => {
    const v1 = store.add({ name: 'a.txt', bytes: Buffer.from('uno') });
    await processRevision(store, v1.document.id, { scan: 'off' });
    const h1 = fileSources(store)[0].hash;
    expect(fileSources(store)[0].hash).toBe(h1);
    store.add({ name: 'a.txt', bytes: Buffer.from('dos'), replaces: v1.document.id });
    await processRevision(store, v1.document.id, { scan: 'off' });
    const s = fileSources(store)[0];
    expect(s.hash).not.toBe(h1);
    expect(s.chunks({ chunkChars: 1200, overlap: 0 })[0].text).toBe('dos');
  });

  it('sin almacén creado devuelve lista vacía', () => {
    expect(fileSources(new FileStore({ home: path.join(home, 'nada'), dome: 'X' }))).toEqual([]);
  });
});
