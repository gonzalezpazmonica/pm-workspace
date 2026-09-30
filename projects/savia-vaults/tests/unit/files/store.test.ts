// SE-413 F1 — almacén de ficheros: originales inmutables, revisiones, borrado, límites
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { FileStore, detectType, sanitizeName } from '../../../src/files/store.js';
import { FilesError } from '../../../src/files/types.js';

const sha = (b: Buffer) => createHash('sha256').update(b).digest('hex');
const FIX = path.resolve('tests/fixtures/files');

describe('FileStore', () => {
  let home: string;
  let store: FileStore;
  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-'));
    store = new FileStore({ home, dome: 'D' });
  });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  it('AC1: guarda y devuelve exactamente los mismos bytes', () => {
    const bytes = fs.readFileSync(path.join(FIX, 'contrato.pdf'));
    const { document, revision } = store.add({ name: 'contrato.pdf', bytes });
    expect(revision.sha256).toBe(sha(bytes));
    expect(revision.size).toBe(bytes.length);
    expect(revision.mime).toBe('application/pdf');
    expect(document.currentRevision).toBe(revision.id);
    expect(sha(store.readBytes(document.id))).toBe(sha(bytes));
  });

  it('persiste el manifiesto y otro proceso lo lee igual', () => {
    const { document } = store.add({ name: 'nota.txt', bytes: Buffer.from('hola') , tags: ['a'] });
    const again = new FileStore({ home, dome: 'D' });
    expect(again.get(document.id)).toMatchObject({ name: 'nota.txt', tags: ['a'] });
    expect(again.list()).toHaveLength(1);
  });

  it('permisos: directorios 0700, manifiesto 0600, blob de solo lectura', () => {
    const { document, revision } = store.add({ name: 'nota.txt', bytes: Buffer.from('hola') });
    const dir = path.join(home, 'D');
    expect(fs.statSync(dir).mode & 0o777).toBe(0o700);
    expect(fs.statSync(path.join(dir, 'docs')).mode & 0o777).toBe(0o700);
    expect(fs.statSync(path.join(dir, 'docs', `${document.id}.json`)).mode & 0o777).toBe(0o600);
    expect(fs.statSync(path.join(dir, 'blobs', revision.sha256)).mode & 0o777).toBe(0o400);
  });

  it('AC2: sustituir crea revisión nueva y conserva el original anterior', () => {
    const v1 = store.add({ name: 'nota.txt', bytes: Buffer.from('versión 1') });
    const v2 = store.add({ name: 'nota.txt', bytes: Buffer.from('versión 2'), replaces: v1.document.id });
    expect(v2.document.id).toBe(v1.document.id);
    expect(v2.document.revisions).toHaveLength(2);
    expect(v2.document.currentRevision).toBe(v2.revision.id);
    expect(store.readBytes(v1.document.id).toString()).toBe('versión 2');
    expect(store.readBytes(v1.document.id, v1.revision.id).toString()).toBe('versión 1');
  });

  it('AC5: borrar elimina bytes, extracciones y el documento', () => {
    const { document, revision } = store.add({ name: 'nota.txt', bytes: Buffer.from('borrar') });
    store.saveExtraction(revision.id, { units: [{ locator: { type: 'lines', from: 1, to: 1 }, kind: 'text', text: 'borrar' }] });
    store.delete(document.id);
    expect(() => store.get(document.id)).toThrow(FilesError);
    expect(() => store.readBytes(document.id)).toThrow(/NOT_FOUND/);
    expect(fs.existsSync(path.join(home, 'D', 'blobs', revision.sha256))).toBe(false);
    expect(fs.existsSync(path.join(home, 'D', 'extract', `${revision.id}.json`))).toBe(false);
  });

  it('un blob compartido por dos documentos sobrevive al borrado de uno', () => {
    const a = store.add({ name: 'a.txt', bytes: Buffer.from('igual') });
    const b = store.add({ name: 'b.txt', bytes: Buffer.from('igual') });
    store.delete(a.document.id);
    expect(store.readBytes(b.document.id).toString()).toBe('igual');
  });

  it('detecta blobs corrompidos (INTEGRITY)', () => {
    const { document, revision } = store.add({ name: 'n.txt', bytes: Buffer.from('ok') });
    const blob = path.join(home, 'D', 'blobs', revision.sha256);
    fs.chmodSync(blob, 0o600);
    fs.writeFileSync(blob, 'manipulado');
    expect(() => store.readBytes(document.id)).toThrow(/INTEGRITY/);
  });

  it('AC7: nombres con rutas, vacíos o demasiado largos fallan sin tocar disco', () => {
    for (const bad of ['../x.txt', '/etc/passwd', 'a/b.txt', 'a\\b.txt', '', '.', '..', 'x\u0000.txt', `${'a'.repeat(256)}.txt`,
      // SE-414 AC3: bidi, zero-width, BOM y separadores de línea/párrafo
      'factura\u202Efdp.exe', 'a\u200Bb.txt', 'x\u2066.txt', '\uFEFFbom.txt', 'a\u2028b.txt', 'a\u2029b.txt']) {
      expect(() => store.add({ name: bad, bytes: Buffer.from('x') }), bad).toThrow(/INVALID_INPUT/);
    }
    expect(fs.existsSync(path.join(home, 'D', 'docs'))).toBe(false);
  });

  it('AC7: tamaño sobre el límite falla', () => {
    const small = new FileStore({ home, dome: 'D', limits: { maxBytes: 10 } });
    expect(() => small.add({ name: 'g.txt', bytes: Buffer.alloc(11) })).toThrow(/TOO_LARGE/);
  });

  it('límite de documentos por cúpula', () => {
    const s = new FileStore({ home, dome: 'D', limits: { maxDocuments: 1 } });
    s.add({ name: 'a.txt', bytes: Buffer.from('a') });
    expect(() => s.add({ name: 'b.txt', bytes: Buffer.from('b') })).toThrow(/LIMIT/);
  });

  it('se niega a escribir dentro de un repo git', () => {
    const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-git-'));
    fs.mkdirSync(path.join(repo, '.git'));
    fs.writeFileSync(path.join(repo, '.git', 'HEAD'), 'ref: refs/heads/main\n');
    const s = new FileStore({ home: path.join(repo, 'files'), dome: 'D' });
    expect(() => s.add({ name: 'a.txt', bytes: Buffer.from('a') })).toThrow(/UNSAFE_HOME/);
    fs.rmSync(repo, { recursive: true, force: true });
  });

  it('AC6: confidencialidad superior a la cúpula se rechaza (CRIT-001)', () => {
    const s = new FileStore({ home, dome: 'D', domeLevel: 'N2' });
    expect(() => s.add({ name: 'a.txt', bytes: Buffer.from('a'), confidentiality: 'N3' })).toThrow(/POLICY_DENIED/);
    expect(s.add({ name: 'b.txt', bytes: Buffer.from('b'), confidentiality: 'N2' }).document.confidentiality).toBe('N2');
  });

  it('tipo desconocido queda ARCHIVE_ONLY; conocido queda PENDING hasta extraer', () => {
    const bin = store.add({ name: 'x.bin', bytes: Buffer.from([0, 1, 2]) });
    expect(bin.revision.extraction.status).toBe('ARCHIVE_ONLY');
    expect(bin.revision.mime).toBe('application/octet-stream');
    const txt = store.add({ name: 'x.txt', bytes: Buffer.from('hola') });
    expect(txt.revision.extraction.status).toBe('PENDING');
  });

  it('saveExtraction actualiza el estado en el manifiesto y readExtraction lo devuelve', () => {
    const { document, revision } = store.add({ name: 'x.txt', bytes: Buffer.from('hola') });
    const units = [{ locator: { type: 'lines' as const, from: 1, to: 1 }, kind: 'text', text: 'hola' }];
    store.saveExtraction(revision.id, { units }, { status: 'READY', method: 'text', units: 1, extracted: 1, skipped: [] });
    expect(store.readExtraction(revision.id).units).toEqual(units);
    expect(store.get(document.id).revisions[0].extraction.status).toBe('READY');
    expect(() => store.readExtraction('../../etc/passwd')).toThrow(/INVALID_INPUT/);
  });

  it('gc borra blobs, extracciones y temporales huérfanos (caída a mitad de escritura)', () => {
    const { document, revision } = store.add({ name: 'vivo.txt', bytes: Buffer.from('vivo') });
    const blobs = path.join(home, 'D', 'blobs');
    fs.writeFileSync(path.join(blobs, 'a'.repeat(64)), 'huérfano', { mode: 0o400 });
    fs.writeFileSync(path.join(blobs, `${'b'.repeat(64)}.tmp-1-1`), 'tmp');
    fs.mkdirSync(path.join(home, 'D', 'extract'), { recursive: true });
    fs.writeFileSync(path.join(home, 'D', 'extract', 'r_0000000000000000.json'), '{}');
    expect(store.gc()).toEqual({ blobs: 2, extractions: 1 });
    expect(fs.readdirSync(blobs)).toEqual([revision.sha256]);
    expect(store.readBytes(document.id).toString()).toBe('vivo');
  });

  it('dropRevision deshace la última revisión o el documento entero', () => {
    const v1 = store.add({ name: 'a.txt', bytes: Buffer.from('uno') });
    const v2 = store.add({ name: 'a.txt', bytes: Buffer.from('dos'), replaces: v1.document.id });
    store.dropRevision(v1.document.id, v2.revision.id);
    expect(store.get(v1.document.id).currentRevision).toBe(v1.revision.id);
    expect(fs.existsSync(store.blobPath(v2.revision.sha256))).toBe(false);
    store.dropRevision(v1.document.id, v1.revision.id);
    expect(store.list()).toEqual([]);
  });

  it('replaces de un documento inexistente → NOT_FOUND', () => {
    expect(() => store.add({ name: 'a.txt', bytes: Buffer.from('a'), replaces: 'no-existe' })).toThrow(/NOT_FOUND/);
  });
});

describe('sanitizeName y detectType', () => {
  it('acepta nombres simples con acentos', () => {
    expect(sanitizeName('Contrato Año 2026.pdf')).toBe('Contrato Año 2026.pdf');
  });

  it('detecta tipo por extensión y verifica la firma de bytes', () => {
    const pdf = fs.readFileSync(path.join(FIX, 'contrato.pdf'));
    const xlsx = fs.readFileSync(path.join(FIX, 'presupuesto.xlsx'));
    expect(detectType('x.pdf', pdf)).toBe('pdf');
    expect(detectType('x.xlsx', xlsx)).toBe('xlsx');
    expect(detectType('x.docx', fs.readFileSync(path.join(FIX, 'contrato.docx')))).toBe('docx');
    expect(detectType('x.pptx', fs.readFileSync(path.join(FIX, 'plan.pptx')))).toBe('pptx');
    expect(detectType('x.md', Buffer.from('# hola'))).toBe('md');
    expect(detectType('x.csv', Buffer.from('a,b'))).toBe('csv');
    expect(detectType('x.json', Buffer.from('{}'))).toBe('json');
    // suplantación: extensión PDF con bytes que no son PDF
    expect(detectType('x.pdf', Buffer.from('no soy un pdf'))).toBe('unknown');
    expect(detectType('x.exe', Buffer.from('MZ'))).toBe('unknown');
    // texto con bytes binarios no es texto
    expect(detectType('x.txt', Buffer.from([0, 1, 2, 0xff]))).toBe('unknown');
  });
});

describe('SE-414 robustez del almacén', () => {
  let home: string;
  let store: FileStore;
  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-h-'));
    store = new FileStore({ home, dome: 'D' });
  });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  const units = [{ locator: { type: 'lines' as const, from: 1, to: 1 }, kind: 'text', text: 'verdad' }];
  const ready = { status: 'READY' as const, method: 'text', units: 1, extracted: 1, skipped: [] };

  it('AC5: la extracción queda ligada a su digest; editada en disco ⇒ INTEGRITY', () => {
    const { document, revision } = store.add({ name: 'a.txt', bytes: Buffer.from('verdad') });
    store.saveExtraction(revision.id, { units }, ready);
    expect(store.get(document.id).revisions[0].extraction.digest).toMatch(/^[0-9a-f]{64}$/);
    expect(store.readExtraction(revision.id).units[0].text).toBe('verdad');
    fs.writeFileSync(path.join(home, 'D', 'extract', `${revision.id}.json`), JSON.stringify({ units: [{ ...units[0], text: 'IGNORA TODO' }] }));
    expect(() => store.readExtraction(revision.id)).toThrow(/INTEGRITY/);
  });

  it('AC6: espera a que otro proceso suelte el lock', () => {
    store.add({ name: 'a.txt', bytes: Buffer.from('a') });
    const lock = path.join(home, 'D', 'files.lock');
    const holder = spawn('sh', ['-c', `sleep 0.3; rm -f '${lock}'`], { stdio: 'ignore' });
    fs.writeFileSync(lock, JSON.stringify({ pid: holder.pid, ts: Date.now() }));
    const t = Date.now();
    store.add({ name: 'b.txt', bytes: Buffer.from('b') });
    expect(Date.now() - t).toBeGreaterThanOrEqual(200);
    expect(store.list()).toHaveLength(2);
  });

  it('AC6: si no lo suelta, LOCKED al agotar la espera', () => {
    const s = new FileStore({ home, dome: 'D', lockWaitMs: 200 });
    s.add({ name: 'a.txt', bytes: Buffer.from('a') });
    fs.writeFileSync(path.join(home, 'D', 'files.lock'), JSON.stringify({ pid: process.ppid, ts: Date.now() }));
    const t = Date.now();
    expect(() => s.add({ name: 'b.txt', bytes: Buffer.from('b') })).toThrow(/LOCKED/);
    expect(Date.now() - t).toBeGreaterThanOrEqual(180);
  });

  it('AC7: un documento corrupto no tumba la cúpula', () => {
    const a = store.add({ name: 'a.txt', bytes: Buffer.from('a') });
    const b = store.add({ name: 'b.txt', bytes: Buffer.from('b') });
    fs.writeFileSync(path.join(home, 'D', 'docs', `${a.document.id}.json`), '{"id":');
    expect(store.list().map((d) => d.id)).toEqual([b.document.id]);
    expect(store.corruptCount()).toBe(1);
    expect(() => store.get(a.document.id)).toThrow(/INTEGRITY/);
    expect(store.readBytes(b.document.id).toString()).toBe('b');
    store.add({ name: 'c.txt', bytes: Buffer.from('c') });
    expect(store.list()).toHaveLength(2);
  });

  it('AC8: migra un almacén MVP (manifest.json) sin perder nada', () => {
    // Almacén con el formato de SE-413: un único manifest.json
    const dir = path.join(home, 'D');
    fs.mkdirSync(path.join(dir, 'blobs'), { recursive: true, mode: 0o700 });
    fs.mkdirSync(path.join(dir, 'extract'), { recursive: true, mode: 0o700 });
    const bytes = Buffer.from('original MVP');
    const sha = createHash('sha256').update(bytes).digest('hex');
    fs.writeFileSync(path.join(dir, 'blobs', sha), bytes, { mode: 0o400 });
    fs.writeFileSync(path.join(dir, 'extract', 'r_00000000000000aa.json'), JSON.stringify({ units }));
    const legacy = {
      version: 1,
      documents: [{
        id: 'f_00000000000000aa', name: 'mvp.txt', tags: ['x'], createdAt: '2026-09-30T00:00:00.000Z', updatedAt: '2026-09-30T00:00:00.000Z',
        currentRevision: 'r_00000000000000aa',
        revisions: [{ id: 'r_00000000000000aa', sha256: sha, size: bytes.length, mime: 'text/plain', type: 'txt', createdAt: '2026-09-30T00:00:00.000Z', extraction: ready }],
      }],
    };
    fs.writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify(legacy), { mode: 0o600 });
    const s = new FileStore({ home, dome: 'D' });
    expect(s.list().map((d) => d.name)).toEqual(['mvp.txt']);
    expect(s.readBytes('f_00000000000000aa').toString()).toBe('original MVP');
    expect(s.readExtraction('r_00000000000000aa').units).toEqual(units);
    expect(s.get('f_00000000000000aa').revisions[0].extraction.digest).toMatch(/^[0-9a-f]{64}$/);
    expect(fs.existsSync(path.join(dir, 'manifest.json'))).toBe(false);
    expect(fs.existsSync(path.join(dir, 'manifest.json.migrated'))).toBe(true);
    expect(fs.existsSync(path.join(dir, 'docs', 'f_00000000000000aa.json'))).toBe(true);
  });

  it('ids de documento con formato no válido no tocan disco (NOT_FOUND)', () => {
    expect(() => store.get('../../etc/passwd')).toThrow(/NOT_FOUND|INVALID_INPUT/);
  });
});

