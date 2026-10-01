// SE-413 F2 — extracción con localizador (TS + worker Python) y escaneo opcional
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { extractTextual, processRevision, processRevisions, defaultPython, workerEnv } from '../../../src/files/extract.js';
import { Tools } from '../../../src/files/setup.js';
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

  it('SE-415 AC2: JSON ancho declara las hojas omitidas por el tope', () => {
    const wide = JSON.stringify(Object.fromEntries(Array.from({ length: 200_000 }, (_, i) => [`k${i}`, i])));
    const r = extractTextual('json', Buffer.from(wide));
    expect(r.units).toHaveLength(50_000);
    expect(r.skipped).toEqual([{ reason: 'max-units', count: 150_000 }]);
  });

  it('SE-415 AC2: JSON profundo se extrae hasta el nivel 64 y declara el resto', () => {
    let v: unknown = 'hoja';
    for (let i = 0; i < 200; i++) v = { n: v, [`x${i}`]: i };
    const r = extractTextual('json', Buffer.from(JSON.stringify(v)));
    expect(r.units.length).toBeGreaterThan(60);
    expect(r.skipped).toEqual([{ reason: 'max-depth', count: 1 }]);
    expect(Math.max(...r.units.map((u) => (u.locator as { path: string }).path.split('.').length))).toBeLessThanOrEqual(65);
  });

  it('SE-415 AC5: texto en Windows-1252 se decodifica', () => {
    const r = extractTextual('csv', Buffer.from('nombre;importe\nPeña;10\n', 'latin1'), 'windows-1252');
    expect(r.method).toBe('text-windows-1252');
    expect(r.units[0].text).toBe('nombre: Peña | importe: 10');
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

  it('SE-415 AC1: un TXT vacío queda ARCHIVE_ONLY (empty), nunca READY sin unidades', async () => {
    const { document } = store.add({ name: 'vacío.txt', bytes: Buffer.from('\n\n  \n') });
    const info = await processRevision(store, document.id, { scan: 'off' });
    expect(info).toMatchObject({ status: 'ARCHIVE_ONLY', extracted: 0, skipped: [{ reason: 'empty', count: 1 }] });
  });

  it('SE-415 AC5: CSV en Windows-1252 queda READY y se descarga idéntico', async () => {
    const bytes = Buffer.from('nombre;importe\nPeña;10\nAñil;20\n', 'latin1');
    const { document, revision } = store.add({ name: 'gastos.csv', bytes });
    expect(revision).toMatchObject({ type: 'csv', encoding: 'windows-1252' });
    const info = await processRevision(store, document.id, { scan: 'off' });
    expect(info).toMatchObject({ status: 'READY', method: 'text-windows-1252', extracted: 2 });
    expect(store.readExtraction(revision.id).units[0].text).toBe('nombre: Peña | importe: 10');
    expect(store.readBytes(document.id).equals(bytes)).toBe(true);
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

describe('SE-415 worker por lotes', () => {
  let home: string;
  let store: FileStore;
  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-b-'));
    store = new FileStore({ home, dome: 'D' });
  });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  it('AC6: varios ficheros ofimáticos se extraen en un solo worker, cada uno con su resultado', async () => {
    const log = path.join(home, 'calls');
    const py = path.join(home, 'py');
    // Worker falso en modo lote: una línea JSON por línea de entrada, página = nº de orden
    fs.writeFileSync(py, `#!/bin/sh\necho call >> '${log}'\nn=0\nwhile read line; do n=$((n+1)); echo "{\\"method\\":\\"fake\\",\\"units\\":[{\\"locator\\":{\\"type\\":\\"page\\",\\"page\\":$n},\\"kind\\":\\"text\\",\\"text\\":\\"f$n\\"}],\\"skipped\\":[]}"; done\n`, { mode: 0o700 });
    const pdf = fs.readFileSync(path.join(FIX, 'contrato.pdf'));
    const items = [1, 2, 3].map((i) => store.add({ name: `c${i}.pdf`, bytes: Buffer.concat([pdf, Buffer.from(String(i))]) }));
    const txt = store.add({ name: 'n.txt', bytes: Buffer.from('texto') });
    const infos = await processRevisions(store, [...items, txt].map((r) => ({ documentId: r.document.id })), { scan: 'off', python: py });
    expect(infos.map((i) => i.status)).toEqual(['READY', 'READY', 'READY', 'READY']);
    expect(fs.readFileSync(log, 'utf-8').trim().split('\n')).toHaveLength(1);
    expect(items.map((r) => store.readExtraction(r.revision.id).units[0].text)).toEqual(['f1', 'f2', 'f3']);
  });

  it('si el lote muere a mitad, los ya devueltos se guardan y el resto queda FAILED', async () => {
    const py = path.join(home, 'py');
    fs.writeFileSync(py, `#!/bin/sh\nread line\necho '{"method":"fake","units":[{"locator":{"type":"page","page":1},"kind":"text","text":"uno"}],"skipped":[]}'\nexit 1\n`, { mode: 0o700 });
    const pdf = fs.readFileSync(path.join(FIX, 'contrato.pdf'));
    const items = [1, 2].map((i) => store.add({ name: `c${i}.pdf`, bytes: Buffer.concat([pdf, Buffer.from(String(i))]) }));
    const infos = await processRevisions(store, items.map((r) => ({ documentId: r.document.id })), { scan: 'off', python: py });
    expect(infos[0].status).toBe('READY');
    expect(infos[1].status).toBe('FAILED');
  });
});

describe('SE-417 extracción en una cúpula cifrada', () => {
  let base: string;
  let store: FileStore;
  beforeEach(() => {
    base = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-encx-'));
    store = new FileStore({ home: path.join(base, 'files'), dome: 'D', encrypt: true, keysHome: path.join(base, 'keys') });
  });
  afterEach(() => fs.rmSync(base, { recursive: true, force: true }));

  const fakeWorker = (exitCode: number) => {
    const log = path.join(base, 'rutas');
    const py = path.join(base, 'py');
    fs.writeFileSync(py, `#!/bin/sh\nwhile read line; do echo "$line" >> '${log}'; ${exitCode ? `exit ${exitCode}` : `echo '{"method":"fake","units":[{"locator":{"type":"page","page":1},"kind":"text","text":"ok"}],"skipped":[]}'`}; done\n`, { mode: 0o700 });
    return { py, log };
  };

  it('AC8: el worker recibe una copia en memoria que desaparece al terminar', async () => {
    const { py, log } = fakeWorker(0);
    const { document } = store.add({ name: 'c.pdf', bytes: fs.readFileSync(path.join(FIX, 'contrato.pdf')) });
    const info = await processRevision(store, document.id, { scan: 'off', python: py });
    expect(info.status).toBe('READY');
    const received = JSON.parse(fs.readFileSync(log, 'utf-8').trim()).path as string;
    if (fs.existsSync('/dev/shm')) expect(received.startsWith('/dev/shm/savia-files-')).toBe(true);
    expect(fs.existsSync(received)).toBe(false);
    expect(fs.existsSync(path.dirname(received))).toBe(false);
  });

  it('AC8: también desaparece si el worker falla', async () => {
    const { py, log } = fakeWorker(3);
    const { document } = store.add({ name: 'c.pdf', bytes: fs.readFileSync(path.join(FIX, 'contrato.pdf')) });
    expect((await processRevision(store, document.id, { scan: 'off', python: py })).status).toBe('FAILED');
    const received = JSON.parse(fs.readFileSync(log, 'utf-8').trim()).path as string;
    expect(fs.existsSync(path.dirname(received))).toBe(false);
  });

  it('texto en una cúpula cifrada: extracción sellada y legible', async () => {
    const { document, revision } = store.add({ name: 'n.md', bytes: Buffer.from('# Título secreto\n\nPárrafo') });
    expect((await processRevision(store, document.id, { scan: 'off' })).status).toBe('READY');
    expect(fs.readFileSync(path.join(base, 'files', 'D', 'extract', `${revision.id}.json`)).includes(Buffer.from('secreto'))).toBe(false);
    expect(store.readExtraction(revision.id, document.id).units[0].text).toBe('# Título secreto');
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

describe.skipIf(!hasPython)('SE-415 fidelidad con el worker real', () => {
  let home: string;
  let store: FileStore;
  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-f-'));
    store = new FileStore({ home, dome: 'D' });
  });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  const run = async (name: string) => {
    const { document, revision } = store.add({ name, bytes: fs.readFileSync(path.join(FIX, name)) });
    const info = await processRevision(store, document.id, { scan: 'off' });
    return { info, revision };
  };

  it('AC1: PDF escaneado sin capa de texto ⇒ ARCHIVE_ONLY con page-without-text', async () => {
    const { info } = await run('escaneado.pdf');
    expect(info.status).toBe('ARCHIVE_ONLY');
    expect(info.extracted).toBe(0);
    expect(info.skipped).toContainEqual({ reason: 'page-without-text', count: 1 });
  }, 180_000);

  it('AC3: PPTX con notas del presentador por diapositiva', async () => {
    const { info, revision } = await run('continuidad.pptx');
    expect(info.status).toBe('READY');
    const notes = store.readExtraction(revision.id).units.filter((u) => u.kind === 'notes');
    expect(notes.map((u) => u.locator)).toEqual([1, 2, 3].map((slide) => ({ type: 'slide', slide })));
    expect(notes[2].text).toContain('dos horas y diez minutos');
  }, 180_000);

  it('AC4: celdas XLSX con cabecera de columna y etiqueta de fila', async () => {
    const { info, revision } = await run('inventario.xlsx');
    expect(info.status).toBe('READY');
    const d2 = store.readExtraction(revision.id).units.find((u) => u.locator.type === 'cell' && u.locator.cell === 'D2');
    expect(d2?.text).toBe('Inventario!D2 · Coste anual · Servidor de copias: 4200');
    const a1 = store.readExtraction(revision.id).units.find((u) => u.locator.type === 'cell' && u.locator.cell === 'A1');
    expect(a1?.text).toBe('Inventario!A1: Equipo');
  }, 60_000);

  it('AC4: la fórmula conserva el formato con contexto', async () => {
    const { revision } = await run('presupuesto.xlsx');
    const b3 = store.readExtraction(revision.id).units.find((u) => u.locator.type === 'cell' && u.locator.cell === 'B3');
    expect(b3).toMatchObject({ formula: '=SUM(B2:B2)' });
    expect(b3?.text).toBe('Presupuesto!B3 · Coste · Total: 1500 (=SUM(B2:B2))');
  }, 60_000);
});


// SE-424 H4: el worker va sin red; los modelos de docling le llegan por ruta.
describe('SE-424 H4: modelos del lector de PDF', () => {
  const saved = process.env.SAVIA_FILES_DOCLING_MODELS;
  afterEach(() => { if (saved === undefined) delete process.env.SAVIA_FILES_DOCLING_MODELS; else process.env.SAVIA_FILES_DOCLING_MODELS = saved; });

  it('workerEnv sigue sin red y pasa la carpeta de modelos (explícita o la gestionada)', () => {
    process.env.SAVIA_FILES_DOCLING_MODELS = '/ruta/de/modelos';
    const env = workerEnv(1000);
    expect(env).toMatchObject({ HF_HUB_OFFLINE: '1', TRANSFORMERS_OFFLINE: '1', SAVIA_FILES_DOCLING_MODELS: '/ruta/de/modelos' });
    delete process.env.SAVIA_FILES_DOCLING_MODELS;
    expect(workerEnv(1000).SAVIA_FILES_DOCLING_MODELS).toBe(new Tools().doclingModelsPath());
  });

  it('real: con los modelos gestionados y un HOME sin caché de HuggingFace, el PDF queda READY con cita', async () => {
    const models = new Tools().doclingModelsPath();
    if (!hasPython || !models) return; // sin extractor o sin modelos gestionados en esta máquina
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-h4-'));
    const savedHome = process.env.HOME;
    try {
      process.env.SAVIA_FILES_DOCLING_MODELS = models; // las herramientas siguen fuera del HOME vacío
      process.env.HOME = path.join(root, 'home-vacio'); // sin ~/.cache/huggingface
      fs.mkdirSync(process.env.HOME);
      const store = new FileStore({ home: path.join(root, 'files'), dome: 'D' });
      const { document, revision } = store.add({ name: 'contrato.pdf', bytes: fs.readFileSync(path.join(FIX, 'contrato.pdf')) });
      const info = await processRevision(store, document.id, { scan: 'off', python: PY });
      expect(info.status).toBe('READY');
      expect(store.readExtraction(revision.id).units.some((u) => (u.locator as { page?: number }).page === 2)).toBe(true);
    } finally {
      process.env.HOME = savedHome;
      fs.rmSync(root, { recursive: true, force: true });
    }
  }, 300_000);
});
