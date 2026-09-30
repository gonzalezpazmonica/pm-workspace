// SE-413 F1 — almacén de ficheros: originales inmutables, revisiones, borrado, límites
import { describe, it, expect, beforeAll, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { FileStore, detectType, sanitizeName } from '../../../src/files/store.js';
import { FilesError } from '../../../src/files/types.js';
import { sodiumReady } from '../../../src/files/crypto.js';

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


describe('SE-417 almacén cifrado', () => {
  let base: string;
  let home: string;
  let keysHome: string;
  const marker = 'CLÁUSULA-SECRETA-7731';
  const pdf = Buffer.concat([Buffer.from('%PDF-1.7\n'), Buffer.from(`contenido ${marker} fin`)]);
  const mk = (encrypt = true) => new FileStore({ home, dome: 'D', encrypt, keysHome });
  const units = [{ locator: { type: 'page' as const, page: 1 }, kind: 'text', text: `texto ${marker}` }];
  const ready = { status: 'READY' as const, method: 'fake', units: 1, extracted: 1, skipped: [] };

  /** Todos los ficheros bajo un directorio (sin seguir symlinks). */
  const walk = (d: string): string[] => fs.readdirSync(d, { withFileTypes: true })
    .flatMap((e) => (e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)]));
  const leaks = (needles: string[]) => walk(home).filter((f) => {
    const b = fs.readFileSync(f);
    return needles.some((n) => b.includes(Buffer.from(n)));
  });

  beforeAll(async () => { await sodiumReady(); });
  beforeEach(() => {
    base = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-enc-'));
    home = path.join(base, 'files');
    keysHome = path.join(base, 'keys');
  });
  afterEach(() => fs.rmSync(base, { recursive: true, force: true }));

  it('AC1: ni contenido, ni nombre, ni SHA-256 en claro en el almacén; los bytes vuelven idénticos', () => {
    const s = mk();
    const { document, revision } = s.add({ name: 'contrato-confidencial.pdf', bytes: pdf, tags: ['etiqueta-secreta'] });
    s.saveExtraction(revision.id, { units }, ready, document.id);
    expect(s.isEncrypted()).toBe(true);
    expect(leaks([marker, 'contrato-confidencial', 'etiqueta-secreta', revision.sha256])).toEqual([]);
    expect(s.readBytes(document.id).equals(pdf)).toBe(true);
    expect(s.get(document.id)).toMatchObject({ name: 'contrato-confidencial.pdf', tags: ['etiqueta-secreta'] });
    expect(s.readExtraction(revision.id, document.id).units[0].text).toContain(marker);
    expect(fs.statSync(path.join(keysHome, 'D', 'kek')).mode & 0o777).toBe(0o600);
  });

  it('AC2: original, extracción o manifiesto manipulados fallan cerrados', () => {
    const s = mk();
    const { document, revision } = s.add({ name: 'a.pdf', bytes: pdf });
    s.saveExtraction(revision.id, { units }, ready, document.id);
    const flip = (f: string) => { fs.chmodSync(f, 0o600); const b = fs.readFileSync(f); b[b.length - 5] ^= 1; fs.writeFileSync(f, b); };
    const blobs = walk(path.join(home, 'D', 'blobs'));
    expect(blobs).toHaveLength(1);
    flip(blobs[0]);
    expect(() => s.readBytes(document.id)).toThrow(/INTEGRITY/);
    flip(path.join(home, 'D', 'extract', `${revision.id}.json`));
    expect(() => s.readExtraction(revision.id, document.id)).toThrow(/INTEGRITY/);
    const docFile = path.join(home, 'D', 'docs', `${document.id}.json`);
    const j = JSON.parse(fs.readFileSync(docFile, 'utf-8'));
    const sealed = Buffer.from(j.sealed, 'base64'); sealed[30] ^= 1;
    fs.writeFileSync(docFile, JSON.stringify({ ...j, sealed: sealed.toString('base64') }));
    expect(s.list()).toEqual([]);
    expect(s.corruptCount()).toBe(1);
  });

  it('AC3: borrado criptográfico; una copia previa del almacén no sirve aunque se tenga la KEK', () => {
    const s = mk();
    const { document, revision } = s.add({ name: 'a.pdf', bytes: pdf });
    const copy = path.join(base, 'copia');
    fs.cpSync(home, copy, { recursive: true });
    s.delete(document.id);
    expect(fs.existsSync(path.join(keysHome, 'D', 'wraps', `${revision.id}.json`))).toBe(false);
    const fromCopy = new FileStore({ home: copy, dome: 'D', encrypt: true, keysHome });
    expect(() => fromCopy.readBytes(document.id)).toThrow(/NOT_FOUND/);
  });

  it('AC4: rotar la KEK re-sella metadatos y re-envuelve; todo sigue legible', () => {
    const s = mk();
    const { document, revision } = s.add({ name: 'a.pdf', bytes: pdf });
    s.saveExtraction(revision.id, { units }, ready, document.id);
    const docFile = path.join(home, 'D', 'docs', `${document.id}.json`);
    const before = fs.readFileSync(docFile, 'utf-8');
    const oldKek = fs.readFileSync(path.join(keysHome, 'D', 'kek'));
    s.rotateKeys();
    expect(fs.readFileSync(docFile, 'utf-8')).not.toBe(before);
    expect(fs.readFileSync(path.join(keysHome, 'D', 'kek')).equals(oldKek)).toBe(false);
    const again = mk();
    expect(again.get(document.id).name).toBe('a.pdf');
    expect(again.readBytes(document.id).equals(pdf)).toBe(true);
    expect(again.readExtraction(revision.id, document.id).units).toEqual(units);
  });

  it('AC5: migra un almacén en claro (formato SE-414) sin pérdida y sin restos en claro', () => {
    const plain = mk(false);
    const a = plain.add({ name: 'uno-secreto.pdf', bytes: pdf });
    plain.saveExtraction(a.revision.id, { units }, ready, a.document.id);
    const b = plain.add({ name: 'dos.txt', bytes: Buffer.from(`nota ${marker}`) });
    expect(plain.isEncrypted()).toBe(false);
    const enc = mk(true);
    const report = enc.encryptExisting();
    expect(report).toMatchObject({ documents: 2, revisions: 2 });
    expect(enc.isEncrypted()).toBe(true);
    expect(leaks([marker, 'uno-secreto', a.revision.sha256])).toEqual([]);
    expect(enc.readBytes(a.document.id).equals(pdf)).toBe(true);
    expect(enc.readBytes(b.document.id).toString()).toBe(`nota ${marker}`);
    expect(enc.readExtraction(a.revision.id, a.document.id).units).toEqual(units);
    expect(enc.encryptExisting()).toMatchObject({ documents: 0, revisions: 0 }); // idempotente
  });

  it('una cúpula cifrada no vuelve a claro aunque se abra sin encrypt', () => {
    mk(true).add({ name: 'a.txt', bytes: Buffer.from('x') });
    const s = mk(false);
    expect(s.isEncrypted()).toBe(true);
    s.add({ name: `b-${marker}.txt`, bytes: Buffer.from(marker) });
    expect(leaks([marker])).toEqual([]);
  });

  it('AC6: sin KEK en una cúpula cifrada, KEY_MISSING y no se crea otra clave', () => {
    const s = mk();
    const { document } = s.add({ name: 'a.txt', bytes: Buffer.from('x') });
    fs.renameSync(path.join(keysHome, 'D'), path.join(base, 'claves-perdidas'));
    const t = mk();
    expect(() => t.list()).toThrow(/KEY_MISSING/);
    expect(() => t.readBytes(document.id)).toThrow(/KEY_MISSING/);
    expect(() => t.add({ name: 'b.txt', bytes: Buffer.from('y') })).toThrow(/KEY_MISSING/);
    expect(fs.existsSync(path.join(keysHome, 'D', 'kek'))).toBe(false);
  });

  it('AC8: la copia en claro para worker/antivirus vive en memoria y se borra', () => {
    const s = mk();
    const { document, revision } = s.add({ name: 'a.pdf', bytes: pdf });
    const p = s.plainPath(document.id, revision.id);
    if (fs.existsSync('/dev/shm')) expect(p.startsWith('/dev/shm/')).toBe(true);
    expect(fs.readFileSync(p).equals(pdf)).toBe(true);
    expect(fs.statSync(path.dirname(p)).mode & 0o777).toBe(0o700);
    s.releasePlain(p);
    expect(fs.existsSync(p)).toBe(false);
    expect(fs.existsSync(path.dirname(p))).toBe(false);
  });

  it('en claro, plainPath devuelve el blob sin copiar', () => {
    const s = mk(false);
    const { document, revision } = s.add({ name: 'a.txt', bytes: Buffer.from('x') });
    expect(s.plainPath(document.id, revision.id)).toBe(s.blobPath(revision.sha256));
  });
});
