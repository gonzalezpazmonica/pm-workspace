// SE-414 S1 — guardia de descompresión para OOXML (DOCX, PPTX, XLSX) antes del worker
import { describe, it, expect } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { inspectZip, inspectZipFile } from '../../../src/files/zip-guard.js';
import * as os from 'node:os';
import { craftZip } from './craft-zip.js';

const FIX = path.resolve('tests/fixtures/files');

const LIMITS = { maxUnzippedBytes: 256 * 1024 * 1024, maxRatio: 200, maxEntries: 10_000 };

describe('inspectZip', () => {
  it('los fixtures legítimos pasan y declaran su tamaño', () => {
    for (const f of ['contrato.docx', 'plan.pptx', 'presupuesto.xlsx']) {
      const r = inspectZip(fs.readFileSync(path.join(FIX, f)), LIMITS);
      expect(r.ok, f).toBe(true);
      expect(r.entries).toBeGreaterThan(3);
      expect(r.unzippedBytes).toBeGreaterThan(1000);
    }
  });

  it('AC1: suma descomprimida por encima del límite', () => {
    const z = craftZip([{ name: 'word/document.xml', comp: 1_000_000, uncomp: 414_000_000 }]);
    const r = inspectZip(z, LIMITS);
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/descomprimido|unzipped/);
  });

  it('razón de compresión excesiva en una entrada grande', () => {
    const z = craftZip([{ name: 'word/document.xml', comp: 10_000, uncomp: 50_000_000 }]);
    expect(inspectZip(z, LIMITS)).toMatchObject({ ok: false, reason: expect.stringMatching(/razón/) });
  });

  it('entradas pequeñas muy comprimibles no se penalizan', () => {
    const z = craftZip([{ name: 'word/styles.xml', comp: 100, uncomp: 900_000 }]);
    expect(inspectZip(z, LIMITS).ok).toBe(true);
  });

  it('zip64: lee los tamaños del campo extra', () => {
    const z = craftZip([{ name: 'word/document.xml', comp: 1_000_000, uncomp: 5_000_000_000, zip64: true }]);
    expect(inspectZip(z, LIMITS).ok).toBe(false);
  });

  it('demasiadas entradas', () => {
    const z = craftZip(Array.from({ length: 30 }, (_, i) => ({ name: `x${i}.xml`, comp: 10, uncomp: 10 })));
    expect(inspectZip(z, { ...LIMITS, maxEntries: 20 })).toMatchObject({ ok: false, reason: expect.stringMatching(/entradas/) });
  });

  it('ZIP sin directorio central o truncado', () => {
    expect(inspectZip(Buffer.from('PK\x03\x04 basura'), LIMITS)).toMatchObject({ ok: false, reason: expect.stringMatching(/ZIP/) });
    const z = craftZip([{ name: 'a.xml', comp: 10, uncomp: 10 }]);
    expect(inspectZip(z.subarray(0, z.length - 30), LIMITS).ok).toBe(false);
  });

  it('SE-421 AC7: inspectZipFile (solo cola y directorio central) da lo mismo que en memoria', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-zipfile-'));
    try {
      const cases: Buffer[] = [
        ...['contrato.docx', 'plan.pptx', 'presupuesto.xlsx'].map((f) => fs.readFileSync(path.join(FIX, f))),
        craftZip([{ name: 'bomba.xml', comp: 1000, uncomp: 900 * 1024 * 1024 }]),
        craftZip([{ name: 'grande.xml', comp: 5000, uncomp: 400_000, zip64: true }]),
        Buffer.from('PK\x03\x04 basura'),
      ];
      cases.forEach((b, i) => {
        const f = path.join(dir, `z${i}.zip`);
        fs.writeFileSync(f, b);
        expect(inspectZipFile(f, LIMITS), `caso ${i}`).toEqual(inspectZip(b, LIMITS));
      });
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
});
