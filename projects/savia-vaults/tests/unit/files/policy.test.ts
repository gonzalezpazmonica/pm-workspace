// SE-419 — reglas de acceso por documento: nivel con la tabla de roles de las cúpulas y
// listas readers/writers que solo restringen; sin principal (modo local) todo permitido.
import { describe, it, expect } from 'vitest';
import { canRead, canWrite, canCreateAt, validatePolicy } from '../../../src/files/policy.js';
import type { FileDocument } from '../../../src/files/types.js';

const doc = (o: Partial<FileDocument> = {}): FileDocument => ({
  id: 'f_0000000000000001', name: 'a.txt', tags: [], createdAt: '', updatedAt: '', currentRevision: 'r_0000000000000001',
  revisions: [], ...o,
});
const reader = (username = 'ana') => ({ username, role: 'reader' as const });
const writer = (username = 'eva') => ({ username, role: 'writer' as const });
const admin = { username: 'root', role: 'admin' as const };

describe('policy', () => {
  it('sin principal (modo local) todo permitido', () => {
    expect(canRead(undefined, doc({ confidentiality: 'N4', acl: { readers: [] } }), 'N4')).toBe(true);
    expect(canWrite(undefined, doc({ acl: { writers: [] } }), 'N2')).toBe(true);
  });

  it('AC1: el nivel del documento aplica la tabla de roles (hereda el de la cúpula)', () => {
    expect(canRead(reader(), doc(), 'N2')).toBe(true);
    expect(canRead(reader(), doc({ confidentiality: 'N3' }), 'N3')).toBe(false);
    expect(canRead(reader(), doc(), 'N3')).toBe(false); // hereda N3 de la cúpula
    expect(canRead(writer(), doc({ confidentiality: 'N3' }), 'N3')).toBe(true);
    expect(canRead(writer(), doc({ confidentiality: 'N4' }), 'N4')).toBe(false);
    expect(canRead(admin, doc({ confidentiality: 'N4' }), 'N4')).toBe(true);
    expect(canWrite(reader(), doc(), 'N2')).toBe(false);
    expect(canWrite(writer(), doc({ confidentiality: 'N3' }), 'N3')).toBe(true);
  });

  it('AC2: listas que restringen; writers implica lectura; [] solo admin; null hereda', () => {
    const d = doc({ acl: { readers: ['ana'] } });
    expect(canRead(reader('ana'), d, 'N2')).toBe(true);
    expect(canRead(reader('luis'), d, 'N2')).toBe(false);
    expect(canRead(admin, doc({ acl: { readers: [], writers: [] } }), 'N2')).toBe(true);
    expect(canRead(writer('eva'), doc({ acl: { readers: [] } }), 'N2')).toBe(false);
    const w = doc({ acl: { readers: ['ana'], writers: ['eva'] } });
    expect(canRead(writer('eva'), w, 'N2')).toBe(true);
    expect(canWrite(writer('eva'), w, 'N2')).toBe(true);
    expect(canWrite(writer('otro'), doc({ acl: { writers: ['eva'] } }), 'N2')).toBe(false);
    expect(canRead(writer('otro'), doc({ acl: { writers: ['eva'] } }), 'N2')).toBe(true); // readers null: hereda
    expect(canRead(reader('ana'), doc({ acl: { readers: null } }), 'N2')).toBe(true);
    // Una lista nunca amplía: un reader en writers no escribe
    expect(canWrite(reader('ana'), doc({ acl: { writers: ['ana'] } }), 'N2')).toBe(false);
  });

  it('AC5: crear a un nivel exige poder escribir ese nivel', () => {
    expect(canCreateAt(writer(), 'N3')).toBe(true);
    expect(canCreateAt(writer(), 'N4')).toBe(false);
    expect(canCreateAt(admin, 'N4')).toBe(true);
    expect(canCreateAt(undefined, 'N4')).toBe(true);
  });

  it('validatePolicy: nivel ≤ cúpula, nombres válidos, sin duplicados, tope de tamaño', () => {
    expect(validatePolicy({ confidentiality: 'N3', readers: ['ana', 'luis'], writers: null }, 'N3'))
      .toEqual({ confidentiality: 'N3', readers: ['ana', 'luis'], writers: null });
    expect(() => validatePolicy({ confidentiality: 'N4' }, 'N3')).toThrow(/INVALID_INPUT/);
    expect(() => validatePolicy({ confidentiality: 'N9' }, 'N3')).toThrow(/INVALID_INPUT/);
    expect(() => validatePolicy({ readers: ['ana', 'ana'] }, 'N2')).toThrow(/INVALID_INPUT/);
    expect(() => validatePolicy({ readers: ['../x'] }, 'N2')).toThrow(/INVALID_INPUT/);
    expect(() => validatePolicy({ writers: Array.from({ length: 257 }, (_, i) => `u${i}`) }, 'N2')).toThrow(/INVALID_INPUT/);
    expect(() => validatePolicy({ readers: 'ana' as never }, 'N2')).toThrow(/INVALID_INPUT/);
    expect(() => validatePolicy({}, 'N2')).toThrow(/INVALID_INPUT/); // nada que cambiar
  });
});
