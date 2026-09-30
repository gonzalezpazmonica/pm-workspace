// SE-422 — tokens acotados de subida/descarga: HMAC con clave propia 0600, caducidad, tipo,
// manipulación y rotación de la clave.
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { TokenSigner, TokenError } from '../../../src/server/grants.js';

describe('TokenSigner', () => {
  let home: string;
  beforeEach(() => { home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-tokens-')); });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  it('firma y verifica; la clave es 0600 en un directorio propio', () => {
    const t = new TokenSigner(home);
    const tok = t.sign({ kind: 'upload', dome: 'D', sub: 'eva', maxBytes: 100, name: 'a.pdf' }, 60_000);
    expect(tok).toMatch(/^svt1\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
    const p = t.verify(tok);
    expect(p).toMatchObject({ kind: 'upload', dome: 'D', sub: 'eva', maxBytes: 100, name: 'a.pdf' });
    expect(p.jti).toMatch(/^[0-9a-f]{32}$/);
    expect(fs.statSync(path.join(home, '_http', 'token.key')).mode & 0o777).toBe(0o600);
    expect(TokenSigner.looksLike(tok)).toBe(true);
    expect(TokenSigner.looksLike('sv_abc')).toBe(false);
  });

  it('caducado, manipulado, de otra clave o mal formado ⇒ TokenError', () => {
    const t = new TokenSigner(home);
    expect(() => t.verify(t.sign({ kind: 'download', dome: 'D', sub: 'eva', documentId: 'f_0000000000000001' }, -1))).toThrow(TokenError);
    const tok = t.sign({ kind: 'upload', dome: 'D', sub: 'eva' }, 60_000);
    const [, body, mac] = tok.split('.');
    const forged = JSON.parse(Buffer.from(body, 'base64url').toString());
    forged.dome = 'OTRA';
    expect(() => t.verify(`svt1.${Buffer.from(JSON.stringify(forged)).toString('base64url')}.${mac}`)).toThrow(/firma/);
    const other = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-tokens-2-'));
    try {
      expect(() => new TokenSigner(other).verify(tok)).toThrow(TokenError);
    } finally {
      fs.rmSync(other, { recursive: true, force: true });
    }
    for (const bad of ['', 'svt1.', 'svt1.a.b', 'svt2.x.y', `svt1.${'a'.repeat(5000)}.b`]) expect(() => t.verify(bad)).toThrow(TokenError);
  });

  it('rotar la clave invalida los tokens emitidos', () => {
    const t = new TokenSigner(home);
    const tok = t.sign({ kind: 'upload', dome: 'D', sub: 'eva' }, 60_000);
    t.rotate();
    expect(() => t.verify(tok)).toThrow(TokenError);
    expect(t.verify(t.sign({ kind: 'upload', dome: 'D', sub: 'eva' }, 60_000)).sub).toBe('eva');
  });
});
