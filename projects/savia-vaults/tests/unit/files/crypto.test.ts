// SE-417 — primitivas de cifrado de Savia Files (libsodium): streaming por frames, sellado
// con AAD, subclaves, nombres opacos y fichero de recuperación. Todo falla cerrado.
import { describe, it, expect, beforeAll } from 'vitest';
import { randomBytes } from 'node:crypto';
import {
  sodiumReady, canonicalJson, seal, open, encryptStream, decryptStream, deriveSubkey, opaqueName,
  sealRecovery, openRecovery, FRAME_PLAIN_BYTES,
} from '../../../src/files/crypto.js';

const key = () => randomBytes(32);
const aad = { schemaVersion: 1, domeId: 'D', documentId: 'f_1', revisionId: 'r_1', artifactKind: 'original' };

beforeAll(async () => { await sodiumReady(); });

describe('canonicalJson (RFC 8785 para AAD)', () => {
  it('ordena claves y no deja espacios', () => {
    expect(canonicalJson({ b: 1, a: 'x', c: { z: true, y: null } })).toBe('{"a":"x","b":1,"c":{"y":null,"z":true}}');
  });
});

describe('seal / open', () => {
  it('ida y vuelta con AAD', () => {
    const k = key();
    const s = seal(k, Buffer.from('hola'), aad);
    expect(s.includes(Buffer.from('hola'))).toBe(false);
    expect(open(k, s, aad).toString()).toBe('hola');
  });

  it('falla cerrado con otra clave, otro AAD o un bit cambiado', () => {
    const k = key();
    const s = seal(k, Buffer.from('hola'), aad);
    expect(() => open(key(), s, aad)).toThrow(/INTEGRITY/);
    expect(() => open(k, s, { ...aad, revisionId: 'r_2' })).toThrow(/INTEGRITY/);
    const t = Buffer.from(s); t[t.length - 1] ^= 1;
    expect(() => open(k, t, aad)).toThrow(/INTEGRITY/);
    expect(() => open(k, s.subarray(0, 10), aad)).toThrow(/INTEGRITY/);
  });
});

describe('encryptStream / decryptStream', () => {
  const big = randomBytes(FRAME_PLAIN_BYTES * 2 + 12345);

  it('varios frames, ida y vuelta exacta; vacío también', () => {
    const k = key();
    const c = encryptStream(k, big, aad);
    expect(c.subarray(0, 4).toString()).toBe('SVF1');
    expect(decryptStream(k, c, aad).equals(big)).toBe(true);
    expect(decryptStream(k, encryptStream(k, Buffer.alloc(0), aad), aad).length).toBe(0);
  });

  it('bit cambiado, frames reordenados, truncado o sin TAG_FINAL: falla cerrado', () => {
    const k = key();
    const c = encryptStream(k, big, aad);
    const flip = Buffer.from(c); flip[100] ^= 1;
    expect(() => decryptStream(k, flip, aad)).toThrow(/INTEGRITY/);
    // Truncado justo tras el primer frame completo (sin TAG_FINAL)
    const first = 4 + 24 + 4 + c.readUInt32BE(28);
    expect(() => decryptStream(k, c.subarray(0, first), aad)).toThrow(/INTEGRITY/);
    // Reordenar los dos primeros frames
    const f1len = c.readUInt32BE(28);
    const f1 = c.subarray(28, 28 + 4 + f1len);
    const f2len = c.readUInt32BE(28 + 4 + f1len);
    const f2 = c.subarray(28 + 4 + f1len, 28 + 4 + f1len + 4 + f2len);
    const swapped = Buffer.concat([c.subarray(0, 28), f2, f1, c.subarray(28 + f1.length + f2.length)]);
    expect(() => decryptStream(k, swapped, aad)).toThrow(/INTEGRITY/);
    expect(() => decryptStream(k, c, { ...aad, artifactKind: 'extract' })).toThrow(/INTEGRITY/);
    expect(() => decryptStream(k, Buffer.from('SVF1basura'), aad)).toThrow(/INTEGRITY/);
    // Bytes añadidos tras el frame final
    expect(() => decryptStream(k, Buffer.concat([c, Buffer.from([0, 0, 0, 1, 7])]), aad)).toThrow(/INTEGRITY/);
  });
});

describe('subclaves y nombres opacos', () => {
  it('subclaves distintas por uso y deterministas', () => {
    const kek = key();
    expect(deriveSubkey(kek, 'meta').equals(deriveSubkey(kek, 'meta'))).toBe(true);
    expect(deriveSubkey(kek, 'meta').equals(deriveSubkey(kek, 'index'))).toBe(false);
    expect(deriveSubkey(kek, 'meta').equals(kek)).toBe(false);
  });

  it('nombre opaco: no revela el revisionId ni coincide entre claves', () => {
    const k = deriveSubkey(key(), 'name');
    const n = opaqueName(k, 'r_0123456789abcdef');
    expect(n).toMatch(/^[0-9a-f]{64}$/);
    expect(n).not.toContain('0123456789abcdef');
    expect(opaqueName(deriveSubkey(key(), 'name'), 'r_0123456789abcdef')).not.toBe(n);
  });
});

describe('fichero de recuperación', () => {
  it('se abre con la frase correcta y falla con otra', () => {
    const payload = Buffer.from(JSON.stringify({ D: randomBytes(32).toString('base64') }));
    const { file, phrase } = sealRecovery(payload);
    expect(phrase.split('-').length).toBeGreaterThanOrEqual(6);
    expect(file.includes(payload)).toBe(false);
    expect(openRecovery(file, phrase).equals(payload)).toBe(true);
    expect(() => openRecovery(file, `${phrase}x`)).toThrow(/INTEGRITY/);
  }, 30_000);
});
