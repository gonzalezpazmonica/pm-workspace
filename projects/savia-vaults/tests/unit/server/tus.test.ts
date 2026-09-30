// SE-422 — piezas puras del protocolo tus 1.0: Upload-Metadata y Upload-Checksum.
// El flujo completo (creation, PATCH, HEAD, DELETE, expiración) se prueba contra el servidor en
// tests/integration/server/http-files.test.ts y con tus-js-client en tests/e2e/http-tus-client.test.ts.
import { describe, it, expect } from 'vitest';
import { createHash } from 'node:crypto';
import { parseChecksum, parseMetadata, TUS_EXTENSIONS } from '../../../src/server/tus.js';

const b64 = (s: string) => Buffer.from(s).toString('base64');

describe('tus: cabeceras', () => {
  it('Upload-Metadata: base64 por clave, clave sin valor, claves desconocidas ignoradas', () => {
    expect(parseMetadata(`filename ${b64('informe ñ.pdf')},tags ${b64('a,b')},vacia,otra ${b64('x')}`))
      .toEqual({ filename: 'informe ñ.pdf', tags: 'a,b' });
    expect(parseMetadata(`filename ${b64('x')},vacia`)).toEqual({ filename: 'x' });
    expect(parseMetadata(`confidentiality ${b64('N2')},replaces ${b64('f_0000000000000001')},idempotencyKey ${b64('k')}`))
      .toEqual({ confidentiality: 'N2', replaces: 'f_0000000000000001', idempotencyKey: 'k' });
    expect(parseMetadata(undefined)).toEqual({});
    expect(() => parseMetadata('clave con espacios de más')).toThrow(/INVALID_INPUT/);
    expect(() => parseMetadata(`cl@ve ${b64('x')}`)).toThrow(/INVALID_INPUT/);
    expect(() => parseMetadata('x '.repeat(10_000))).toThrow(/INVALID_INPUT/);
  });

  it('Upload-Checksum: solo sha256 con digest de 32 bytes', () => {
    const d = createHash('sha256').update('hola').digest();
    expect(parseChecksum(`sha256 ${d.toString('base64')}`)).toEqual({ algorithm: 'sha256', digest: d });
    expect(parseChecksum(undefined)).toBeUndefined();
    expect(() => parseChecksum(`md5 ${d.toString('base64')}`)).toThrow(/sha256/);
    expect(() => parseChecksum('sha256 abc')).toThrow(/INVALID_INPUT/);
  });

  it('extensiones anunciadas = las implementadas', () => {
    expect(TUS_EXTENSIONS.split(',').sort()).toEqual(['checksum', 'creation', 'creation-with-upload', 'expiration', 'termination']);
  });
});
