// SE-413 F4 — FilesService: acciones de vault_files y de la CLI, ACL y límites (AC1, AC5-AC7)
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash } from 'node:crypto';
import { FilesService, type FilesDomeRef } from '../../../src/files/service.js';

const b64 = (s: string | Buffer) => Buffer.from(s).toString('base64');
const sha = (b: Buffer) => createHash('sha256').update(b).digest('hex');

describe('FilesService', () => {
  let home: string;
  let domes: FilesDomeRef[];
  let changed: string[];
  let denied: Set<string>;
  let svc: FilesService;

  const make = (extra: Partial<ConstructorParameters<typeof FilesService>[0]> = {}) => new FilesService({
    domes: () => domes,
    env: { SAVIA_FILES_HOME: home },
    authorize: async (dome, action) => {
      if (denied.has(`${dome}:${action}`)) throw new Error(`denegado ${action} en ${dome}`);
    },
    onChange: (d) => changed.push(d),
    scanMode: 'off',
    ...extra,
  });

  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-files-svc-'));
    domes = [
      { name: 'D', confidentiality: 'N2', files: { enabled: true } },
      { name: 'Off', confidentiality: 'N2' },
    ];
    changed = [];
    denied = new Set();
    svc = make();
  });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  it('AC1: put → download devuelve los mismos bytes y hash', async () => {
    const bytes = Buffer.from('línea uno\n\nlínea dos');
    const put = await svc.put({ dome: 'D', name: 'nota.txt', contentBase64: b64(bytes), tags: ['x'] });
    expect(put).toMatchObject({ name: 'nota.txt', sha256: sha(bytes), size: bytes.length, status: 'READY', extracted: 2 });
    expect(put.documentId).toMatch(/^f_/);
    expect(put.revisionId).toMatch(/^r_/);
    const dl = await svc.download({ dome: 'D', id: put.documentId });
    expect(dl).toMatchObject({ name: 'nota.txt', mime: 'text/plain', sha256: sha(bytes) });
    expect(Buffer.from(dl.contentBase64, 'base64').equals(bytes)).toBe(true);
    expect(changed).toEqual(['D']);
  });

  it('list, get y text con filtro de localizador y maxChars', async () => {
    const put = await svc.put({ dome: 'D', name: 'a.csv', contentBase64: b64('k,v\nuno,1\ndos,2\n') });
    const list = await svc.list({ dome: 'D' });
    expect(list).toEqual({ documents: [expect.objectContaining({ id: put.documentId, name: 'a.csv', status: 'READY', revisions: 1 })], corrupt: 0 });
    expect((await svc.get({ dome: 'D', id: put.documentId })).revisions).toHaveLength(1);
    const all = await svc.text({ dome: 'D', id: put.documentId });
    expect(all.units).toHaveLength(2);
    const row3 = await svc.text({ dome: 'D', id: put.documentId, locator: { type: 'row', row: 3 } });
    expect(row3.units.map((u) => u.text)).toEqual(['k: dos | v: 2']);
    const short = await svc.text({ dome: 'D', id: put.documentId, maxChars: 5 });
    expect(short.truncated).toBe(true);
    expect(short.units.reduce((n, u) => n + u.text.length, 0)).toBeLessThanOrEqual(5);
  });

  it('replaces crea revisión nueva; reprocess recalcula', async () => {
    const v1 = await svc.put({ dome: 'D', name: 'a.txt', contentBase64: b64('uno') });
    const v2 = await svc.put({ dome: 'D', name: 'a.txt', contentBase64: b64('dos'), replaces: v1.documentId });
    expect(v2.documentId).toBe(v1.documentId);
    expect(v2.revisionId).not.toBe(v1.revisionId);
    const old = await svc.download({ dome: 'D', id: v1.documentId, revisionId: v1.revisionId });
    expect(Buffer.from(old.contentBase64, 'base64').toString()).toBe('uno');
    expect((await svc.reprocess({ dome: 'D', id: v1.documentId })).status).toBe('READY');
  });

  it('AC5: delete ⇒ get/download/text NOT_FOUND', async () => {
    const put = await svc.put({ dome: 'D', name: 'a.txt', contentBase64: b64('borrar') });
    expect(await svc.delete({ dome: 'D', id: put.documentId })).toEqual({ deleted: put.documentId, revisions: 1 });
    for (const fn of [svc.get, svc.download, svc.text]) {
      await expect(fn.call(svc, { dome: 'D', id: put.documentId })).rejects.toThrow(/NOT_FOUND/);
    }
  });

  it('AC6: sin read no hay datos; sin write no hay put/delete/reprocess', async () => {
    const put = await svc.put({ dome: 'D', name: 'a.txt', contentBase64: b64('x') });
    denied.add('D:read');
    for (const fn of [svc.list, svc.get, svc.text, svc.download]) {
      await expect(fn.call(svc, { dome: 'D', id: put.documentId })).rejects.toThrow(/denegado read/);
    }
    denied.clear();
    denied.add('D:write');
    await expect(svc.put({ dome: 'D', name: 'b.txt', contentBase64: b64('y') })).rejects.toThrow(/denegado write/);
    await expect(svc.delete({ dome: 'D', id: put.documentId })).rejects.toThrow(/denegado write/);
    await expect(svc.reprocess({ dome: 'D', id: put.documentId })).rejects.toThrow(/denegado write/);
  });

  it('AC6: confidencialidad superior a la cúpula se rechaza', async () => {
    await expect(svc.put({ dome: 'D', name: 'a.txt', contentBase64: b64('x'), confidentiality: 'N3' })).rejects.toThrow(/POLICY_DENIED/);
  });

  it('AC7: base64 inválido, nombre con ruta y exceso de tamaño fallan sin tocar disco', async () => {
    await expect(svc.put({ dome: 'D', name: 'a.txt', contentBase64: 'no es base64!!' })).rejects.toThrow(/INVALID_INPUT/);
    await expect(svc.put({ dome: 'D', name: '../x.txt', contentBase64: b64('x') })).rejects.toThrow(/INVALID_INPUT/);
    const small = make({ env: { SAVIA_FILES_HOME: home, SAVIA_FILES_MAX_TRANSFER_BYTES: '4' } });
    await expect(small.put({ dome: 'D', name: 'a.txt', contentBase64: b64('12345') })).rejects.toThrow(/TOO_LARGE/);
    expect(fs.existsSync(path.join(home, 'D', 'docs'))).toBe(false);
  });

  it('download por encima del límite de transferencia → TOO_LARGE', async () => {
    const put = await svc.put({ dome: 'D', name: 'a.txt', contentBase64: b64('123456789') });
    const small = make({ env: { SAVIA_FILES_HOME: home, SAVIA_FILES_MAX_TRANSFER_BYTES: '4' } });
    await expect(small.download({ dome: 'D', id: put.documentId })).rejects.toThrow(/TOO_LARGE/);
  });

  it('cúpula sin files.enabled → DISABLED; cúpula desconocida → NOT_FOUND', async () => {
    await expect(svc.list({ dome: 'Off' })).rejects.toThrow(/DISABLED/);
    await expect(svc.list({ dome: 'Nada' })).rejects.toThrow(/NOT_FOUND/);
  });

  it('AC8: scan required sin escáner rechaza antes de guardar', async () => {
    domes[0].files = { enabled: true, scan: 'required' };
    const strict = make({ scanMode: undefined, clamscan: path.join(home, 'no-existe') });
    await expect(strict.put({ dome: 'D', name: 'a.txt', contentBase64: b64('x') })).rejects.toThrow(/SCAN_REQUIRED/);
    expect(fs.existsSync(path.join(home, 'D', 'docs'))).toBe(false);
  });

  it('AC8: infectado ⇒ QUARANTINED y sin descarga', async () => {
    const scanner = path.join(home, 'clamscan');
    fs.writeFileSync(scanner, '#!/bin/sh\necho "$2: Eicar-Signature FOUND"\nexit 1\n', { mode: 0o700 });
    const scanning = make({ scanMode: undefined, clamscan: scanner });
    const put = await scanning.put({ dome: 'D', name: 'e.txt', contentBase64: b64('eicar') });
    expect(put.status).toBe('QUARANTINED');
    await expect(scanning.download({ dome: 'D', id: put.documentId })).rejects.toThrow(/NOT_FOUND/);
  });
});
