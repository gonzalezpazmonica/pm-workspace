// SE-418 — receipts firmados: Ed25519 sobre JCS con dominio, registro de claves públicas,
// rotación que conserva las anteriores y copia/restauración de las claves de firma.
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { ReceiptSigner, type UnsignedReceipt } from '../../../src/files/receipts.js';

const base = (): UnsignedReceipt => ({
  operationId: 'o_0000000000000001', dome: 'D', kind: 'put', status: 'committed',
  refs: [{ documentId: 'f_0000000000000001', revisionId: 'r_0000000000000001' }],
  commitSha: 'a'.repeat(40), manifestHash: 'b'.repeat(64), at: new Date().toISOString(),
});

describe('ReceiptSigner', () => {
  let home: string;
  beforeEach(() => { home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-receipts-')); });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  it('AC6: firma verificable; cambiar cualquier campo o la firma la invalida', () => {
    const s = new ReceiptSigner(home);
    const r = s.sign(base());
    expect(r.algorithm).toBe('Ed25519');
    expect(r.signature).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(s.verify(r)).toBe(true);
    expect(s.verify(JSON.parse(JSON.stringify(r)))).toBe(true); // sobrevive a serializar
    expect(s.verify({ ...r, status: 'failed' })).toBe(false);
    expect(s.verify({ ...r, refs: [{ documentId: 'f_0000000000000002' }] })).toBe(false);
    const sig = Buffer.from(r.signature, 'base64url'); sig[0] ^= 1;
    expect(s.verify({ ...r, signature: sig.toString('base64url') })).toBe(false);
  });

  it('campos ausentes se omiten (sin undefined ni null) y la firma no depende del orden', () => {
    const s = new ReceiptSigner(home);
    const r = s.sign({ ...base(), commitSha: undefined, manifestHash: undefined, status: 'pending' });
    expect('commitSha' in r).toBe(false);
    const reordered = Object.fromEntries(Object.entries(r).reverse()) as typeof r;
    expect(s.verify(reordered)).toBe(true);
  });

  it('AC6: clave privada 0600 en un directorio 0700; distinta de la de VaultSecurity', () => {
    const s = new ReceiptSigner(home);
    const r = s.sign(base());
    expect(fs.statSync(s.dir).mode & 0o777).toBe(0o700);
    expect(fs.statSync(path.join(s.dir, `${r.keyId}.pem`)).mode & 0o777).toBe(0o600);
    expect(s.dir.startsWith(home)).toBe(true);
    expect(s.dir).not.toContain('ed25519-private');
  });

  it('AC6: tras rotar, los receipts antiguos siguen verificando y los nuevos usan otra clave', () => {
    const s = new ReceiptSigner(home);
    const old = s.sign(base());
    const entry = s.rotate();
    const fresh = s.sign(base());
    expect(fresh.keyId).toBe(entry.keyId);
    expect(fresh.keyId).not.toBe(old.keyId);
    expect(s.verify(old)).toBe(true);
    expect(s.verify(fresh)).toBe(true);
    // Firmado con la clave antigua pero fechado tras retirarla: no verifica (hay que re-firmar para probarlo)
    expect(s.verify({ ...old, at: new Date(Date.now() + 60_000).toISOString() })).toBe(false);
  });

  it('solo el registro crea confianza: una clave ajena o un keyId desconocido no verifican', () => {
    const a = new ReceiptSigner(home);
    const other = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-receipts-other-'));
    try {
      const forged = new ReceiptSigner(other).sign(base());
      expect(a.verify(forged)).toBe(false);
      a.sign(base()); // crea la clave de `a`
      expect(a.verify(forged)).toBe(false);
      expect(a.verify({ ...forged, keyId: '../../etc/passwd' })).toBe(false);
    } finally {
      fs.rmSync(other, { recursive: true, force: true });
    }
  });

  it('snapshot/restore: un directorio vacío verifica los receipts anteriores', () => {
    const s = new ReceiptSigner(home);
    const r = s.sign(base());
    s.rotate();
    const snap = s.snapshot()!;
    expect(Object.keys(snap.keys)).toHaveLength(2);
    const restored = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-receipts-restored-'));
    try {
      const t = new ReceiptSigner(restored);
      t.restore(snap);
      expect(t.verify(r)).toBe(true);
      expect(t.verify(t.sign(base()))).toBe(true);
      expect(() => t.restore({ registry: { v: 2 }, keys: {} } as never)).toThrow(/INVALID_INPUT/);
    } finally {
      fs.rmSync(restored, { recursive: true, force: true });
    }
  });
});
