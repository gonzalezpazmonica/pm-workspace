// SE-413 F2 — extracción con localizador (TS + worker Python) y escaneo opcional
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { extractTextual, processRevision, defaultPython } from '../../../src/files/extract.js';
import { FileStore } from '../../../src/files/store.js';
import { craftZip } from './craft-zip.js';

const FIX = path.resolve('tests/fixtures/files');
const PY = defaultPython();
const hasPython = fs.existsSync(PY);
const EICAR = 'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*';

describe('extractTextual', () => {
  it('md: bloques separados por línea en blanco con rango de líneas', () => {
    const r = extractTextual('md', Buffer.from('# Título\n\nPárrafo uno\nsigue\n\n\nFinal'));
    expect(r.units.map((u) => u.locator)).toEqual([
      { type: 'lines', from: 1, to: 1 }, { type: 'lines', from: 3, to: 4 }, { type: 'lines', from: 7, to: 7 },
    ]);
    expect(r.units[1].text).toBe('Párrafo uno\nsigue');
  });

  it('csv: una unidad por fila con cabecera (comillas y comas internas)', () => {
    const r = extractTextual('csv', Buffer.from('nombre,importe\n"Pérez, Ana",10\nLuis,"2,5"\n'));
    expect(r.units).toHaveLength(2);
    expect(r.units[0]).toMatchObject({ locator: { type: 'row', row: 2 }, text: 'nombre: Pérez, Ana | importe: 10' });
    expect(r.units[1].text).toBe('nombre: Luis | importe: 2,5');
  });

  it('json: una unidad por hoja con su ruta', () => {
    const r = extractTextual('json', Buffer.from('{"a":{"b":[1,"dos"]},"c":null}'));
    expect(r.units.map((u) => [u.locator, u.text])).toEqual([
      [{ type: 'key', path: 'a.b[0]' }, 'a.b[0]: 1'],
      [{ type: 'key', path: 'a.b[1]' }, 'a.b[1]: dos'],
      [{ type: 'key', path: 'c' }, 'c: null'],
    ]);
  });

  it('json inválido lanza para que el llamador marque FAILED', () => {
    expect(() => extractTextual('json', Buffer.from('{nope'))).toThrow();
  });
});

describe('processRevision', () => {
  let home: string;
  let store: FileStore;
  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-x-'));
    store = new FileStore({ home, dome: 'D' });
  });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  it('texto: READY con cobertura', async () => {
    const { document, revision } = store.add({ name: 'n.md', bytes: Buffer.from('# A\n\nB') });
    const info = await processRevision(store, document.id, { scan: 'off' });
    expect(info).toMatchObject({ status: 'READY', method: 'text', units: 2, extracted: 2, skipped: [] });
    expect(store.readExtraction(revision.id).units).toHaveLength(2);
  });

  it('AC4: ARCHIVE_ONLY no se extrae', async () => {
    const { document } = store.add({ name: 'x.bin', bytes: Buffer.from([1, 2, 3]) });
    expect((await processRevision(store, document.id, { scan: 'off' })).status).toBe('ARCHIVE_ONLY');
  });

  it('JSON roto: FAILED con error y sin unidades', async () => {
    const { document } = store.add({ name: 'x.json', bytes: Buffer.from('{roto') });
    const info = await processRevision(store, document.id, { scan: 'off' });
    expect(info.status).toBe('FAILED');
    expect(info.error).toMatch(/JSON/);
  });

  it('worker ausente: ARCHIVE_ONLY declarado (nunca READY sin extracción)', async () => {
    const bytes = fs.readFileSync(path.join(FIX, 'contrato.pdf'));
    const { document } = store.add({ name: 'c.pdf', bytes });
    const info = await processRevision(store, document.id, { scan: 'off', python: path.join(home, 'no-python') });
    expect(info.status).toBe('ARCHIVE_ONLY');
    expect(info.skipped).toEqual([{ reason: 'worker-missing', count: 1 }]);
  });

  it('AC8: infectado ⇒ QUARANTINED, sin bytes, registro conservado', async () => {
    const scanner = path.join(home, 'clamscan');
    fs.writeFileSync(scanner, '#!/bin/sh\necho "$2: Eicar-Signature FOUND"\nexit 1\n', { mode: 0o700 });
    const { document, revision } = store.add({ name: 'eicar.txt', bytes: Buffer.from(EICAR) });
    const info = await processRevision(store, document.id, { scan: 'auto', clamscan: scanner });
    expect(info).toMatchObject({ status: 'QUARANTINED', error: 'Eicar-Signature' });
    expect(store.get(document.id).revisions[0].extraction.status).toBe('QUARANTINED');
    expect(fs.existsSync(store.blobPath(revision.sha256))).toBe(false);
    expect(() => store.readBytes(document.id)).toThrow(/NOT_FOUND/);
  });

  it('AC8: required sin escáner rechaza y no extrae', async () => {
    const { document } = store.add({ name: 'n.txt', bytes: Buffer.from('x') });
    await expect(processRevision(store, document.id, { scan: 'required', clamscan: path.join(home, 'nada') }))
      .rejects.toThrow(/SCAN_REQUIRED/);
    expect(store.get(document.id).revisions[0].extraction.status).toBe('PENDING');
  });

  it('worker que excede el tiempo: FAILED por timeout', async () => {
    const slow = path.join(home, 'slow-python');
    fs.writeFileSync(slow, '#!/bin/sh\nsleep 5\n', { mode: 0o700 });
    const { document } = store.add({ name: 'c.pdf', bytes: fs.readFileSync(path.join(FIX, 'contrato.pdf')) });
    const info = await processRevision(store, document.id, { scan: 'off', python: slow, timeoutMs: 300 });
    expect(info.status).toBe('FAILED');
    expect(info.error).toMatch(/timeout/i);
  });
});

describe('SE-414 límites del worker', () => {
  let home: string;
  let store: FileStore;
  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-l-'));
    store = new FileStore({ home, dome: 'D' });
  });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  it('AC1: una bomba de descompresión queda FAILED sin lanzar el worker', async () => {
    const bomb = craftZip([{ name: 'word/document.xml', comp: 1_000_000, uncomp: 414_000_000 }]);
    const { document } = store.add({ name: 'bomba.docx', bytes: bomb });
    expect(store.get(document.id).revisions[0].type).toBe('docx');
    const marker = path.join(home, 'worker-ran');
    const py = path.join(home, 'py');
    fs.writeFileSync(py, `#!/bin/sh\ntouch '${marker}'\necho '{"method":"x","units":[],"skipped":[]}'\n`, { mode: 0o700 });
    const t = Date.now();
    const info = await processRevision(store, document.id, { scan: 'off', python: py });
    expect(Date.now() - t).toBeLessThan(1000);
    expect(info.status).toBe('FAILED');
    expect(info.error).toMatch(/^decompression-limit: /);
    expect(fs.existsSync(marker)).toBe(false);
  });

  it('AC2: con SAVIA_FILES_WORKERS=1 nunca hay dos workers a la vez', async () => {
    const log = path.join(home, 'log');
    const py = path.join(home, 'py');
    // Worker falso: marca inicio y fin con marca de tiempo en ms
    fs.writeFileSync(py, `#!/bin/sh\necho "start $(date +%s%3N)" >> '${log}'\nsleep 0.2\necho "end $(date +%s%3N)" >> '${log}'\necho '{"method":"fake","units":[{"locator":{"type":"page","page":1},"kind":"text","text":"x"}],"skipped":[]}'\n`, { mode: 0o700 });
    const pdf = fs.readFileSync(path.join(FIX, 'contrato.pdf'));
    const ids = [1, 2, 3, 4].map((i) => store.add({ name: `c${i}.pdf`, bytes: Buffer.concat([pdf, Buffer.from(String(i))]) }).document.id);
    const prev = process.env.SAVIA_FILES_WORKERS;
    process.env.SAVIA_FILES_WORKERS = '1';
    try {
      const infos = await Promise.all(ids.map((id) => processRevision(store, id, { scan: 'off', python: py })));
      expect(infos.map((i) => i.status)).toEqual(['READY', 'READY', 'READY', 'READY']);
    } finally {
      if (prev === undefined) delete process.env.SAVIA_FILES_WORKERS; else process.env.SAVIA_FILES_WORKERS = prev;
    }
    let live = 0;
    let peak = 0;
    for (const line of fs.readFileSync(log, 'utf-8').trim().split('\n')) {
      live += line.startsWith('start') ? 1 : -1;
      peak = Math.max(peak, live);
    }
    expect(peak).toBe(1);
  });
});

describe.skipIf(!hasPython)('worker Python (Docling + openpyxl)', () => {
  let home: string;
  let store: FileStore;
  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-w-'));
    store = new FileStore({ home, dome: 'D' });
  });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  const run = async (name: string) => {
    const { document, revision } = store.add({ name, bytes: fs.readFileSync(path.join(FIX, name)) });
    const info = await processRevision(store, document.id, { scan: 'off' });
    return { info, units: store.readExtraction(revision.id).units };
  };

  it('AC3: PDF por página', async () => {
    const { info, units } = await run('contrato.pdf');
    expect(info.status).toBe('READY');
    expect(info.method).toMatch(/^docling/);
    const c1 = units.find((u) => u.text.includes('Cláusula 1'));
    const c7 = units.find((u) => u.text.includes('Cláusula 7'));
    expect(c1?.locator).toEqual({ type: 'page', page: 1 });
    expect(c7?.locator).toEqual({ type: 'page', page: 2 });
  }, 180_000);

  it('AC3: XLSX con valor y fórmula por celda', async () => {
    const { info, units } = await run('presupuesto.xlsx');
    expect(info.status).toBe('READY');
    const b3 = units.find((u) => u.locator.type === 'cell' && u.locator.cell === 'B3');
    expect(b3).toMatchObject({ locator: { type: 'cell', sheet: 'Presupuesto', cell: 'B3' }, formula: '=SUM(B2:B2)' });
    expect(b3?.text).toContain('1500');
  }, 60_000);

  it('AC3: PPTX por diapositiva y DOCX por elemento', async () => {
    const pptx = await run('plan.pptx');
    expect(pptx.units.find((u) => u.text.includes('Latencia'))?.locator).toEqual({ type: 'slide', slide: 2 });
    const docx = await run('contrato.docx');
    const c7 = docx.units.find((u) => u.text.includes('Cláusula 7'));
    expect(c7?.locator.type).toBe('element');
    expect(docx.units.some((u) => u.kind === 'table' && u.text.includes('Licencia'))).toBe(true);
  }, 180_000);
});
