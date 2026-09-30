// SE-417 — almacén de claves de Savia Files: KEK por cúpula fuera del almacén y de git,
// DEK por revisión envuelta, borrado criptográfico, rotación reanudable y recuperación.
import { describe, it, expect, beforeAll, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { KeyStore, exportRecovery, importRecovery, sealKeyBackup, hasRecovery } from '../../../src/files/keys.js';
import { sodiumReady } from '../../../src/files/crypto.js';

beforeAll(async () => { await sodiumReady(); });

describe('KeyStore', () => {
  let home: string;
  let ks: KeyStore;
  const ref = { documentId: 'f_0000000000000001', revisionId: 'r_0000000000000001' };
  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-keys-'));
    ks = new KeyStore({ home, dome: 'D' });
  });
  afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

  it('init crea la KEK con 0600 en un directorio 0700; sin init, KEY_MISSING', () => {
    expect(ks.hasKey()).toBe(false);
    expect(() => ks.kek()).toThrow(/KEY_MISSING/);
    ks.init();
    expect(fs.statSync(ks.dir).mode & 0o777).toBe(0o700);
    expect(fs.statSync(path.join(ks.dir, 'kek')).mode & 0o777).toBe(0o600);
    expect(ks.kek()).toHaveLength(32);
    const id = ks.kekId();
    ks.init(); // idempotente: no cambia la clave
    expect(ks.kekId()).toBe(id);
  });

  it('DEK por revisión: envuelta, recuperable y ligada a su documento y revisión', () => {
    ks.init();
    const dek = ks.newDek(ref);
    expect(ks.dek(ref).equals(dek)).toBe(true);
    const wrap = fs.readFileSync(path.join(ks.dir, 'wraps', `${ref.revisionId}.json`), 'utf-8');
    expect(wrap).not.toContain(dek.toString('base64'));
    expect(() => ks.dek({ ...ref, documentId: 'f_0000000000000002' })).toThrow(/INTEGRITY/);
  });

  it('borrado criptográfico: sin la envoltura, la DEK no existe', () => {
    ks.init();
    ks.newDek(ref);
    ks.destroyDek(ref.revisionId);
    expect(() => ks.dek(ref)).toThrow(/NOT_FOUND/);
  });

  it('envoltura manipulada ⇒ INTEGRITY; KEK perdida con datos ⇒ KEY_MISSING', () => {
    ks.init();
    ks.newDek(ref);
    const w = path.join(ks.dir, 'wraps', `${ref.revisionId}.json`);
    const j = JSON.parse(fs.readFileSync(w, 'utf-8'));
    const bad = Buffer.from(j.sealed, 'base64'); bad[bad.length - 1] ^= 1;
    fs.writeFileSync(w, JSON.stringify({ ...j, sealed: bad.toString('base64') }));
    expect(() => ks.dek(ref)).toThrow(/INTEGRITY/);
    fs.renameSync(path.join(ks.dir, 'kek'), path.join(home, 'kek-perdida'));
    expect(() => ks.kek()).toThrow(/KEY_MISSING/);
  });

  it('AC4 rotación: nueva KEK, envolturas re-cifradas, la antigua ya no sirve', () => {
    ks.init();
    const dek = ks.newDek(ref);
    const oldKek = ks.kek();
    const oldId = ks.kekId();
    ks.rotate(() => undefined);
    expect(ks.kekId()).not.toBe(oldId);
    expect(ks.dek(ref).equals(dek)).toBe(true);
    expect(fs.existsSync(path.join(ks.dir, 'kek.prev'))).toBe(false);
    const j = JSON.parse(fs.readFileSync(path.join(ks.dir, 'wraps', `${ref.revisionId}.json`), 'utf-8'));
    expect(j.kekId).toBe(ks.kekId());
    // Con la KEK antigua como actual, la envoltura nueva no abre
    fs.writeFileSync(path.join(ks.dir, 'kek'), oldKek, { mode: 0o600 });
    expect(() => new KeyStore({ home, dome: 'D' }).dek(ref)).toThrow(/INTEGRITY|KEY_MISSING/);
  });

  it('rotación interrumpida: todo sigue legible y repetirla la completa', () => {
    ks.init();
    const a = ks.newDek(ref);
    const ref2 = { documentId: ref.documentId, revisionId: 'r_0000000000000002' };
    const b = ks.newDek(ref2);
    expect(() => ks.rotate((step) => { if (step === 'rewrapped:1') throw new Error('corte'); })).toThrow(/corte/);
    const again = new KeyStore({ home, dome: 'D' });
    expect(again.dek(ref).equals(a)).toBe(true);
    expect(again.dek(ref2).equals(b)).toBe(true);
    again.rotate(() => undefined);
    expect(fs.existsSync(path.join(ks.dir, 'kek.prev'))).toBe(false);
    expect(again.dek(ref2).equals(b)).toBe(true);
  });

  it('no puede vivir dentro de un repo git', () => {
    const repo = path.join(home, 'repo');
    fs.mkdirSync(path.join(repo, '.git'), { recursive: true });
    fs.writeFileSync(path.join(repo, '.git', 'HEAD'), 'ref: refs/heads/main\n');
    expect(() => new KeyStore({ home: path.join(repo, 'keys'), dome: 'D' }).init()).toThrow(/UNSAFE_HOME/);
  });

  it('AC7 recuperación: frase + copia de claves sellada restauran en un directorio vacío', () => {
    ks.init();
    const dek = ks.newDek(ref);
    new KeyStore({ home, dome: 'E' }).init();
    expect(hasRecovery(home)).toBe(false);
    expect(() => sealKeyBackup(home)).toThrow(/KEY_MISSING|recuperación/);
    const { file, phrase, domes } = exportRecovery(home);
    expect(domes.sort()).toEqual(['D', 'E']);
    expect(hasRecovery(home)).toBe(true);
    // Copia nocturna: KEK + envolturas, sellada para la clave pública de recuperación.
    const ref2 = { documentId: ref.documentId, revisionId: 'r_0000000000000009' };
    const dek2 = ks.newDek(ref2); // creada después de exportar: la copia nocturna la incluye
    const backup = sealKeyBackup(home);
    expect(backup.includes(ks.kek())).toBe(false);
    const restored = path.join(home, 'restaurado');
    expect(() => importRecovery(restored, file, 'frase-mala', backup)).toThrow(/INTEGRITY/);
    expect(importRecovery(restored, file, phrase, backup).sort()).toEqual(['D', 'E']);
    const r = new KeyStore({ home: restored, dome: 'D' });
    expect(r.dek(ref).equals(dek)).toBe(true);
    expect(r.dek(ref2).equals(dek2)).toBe(true);
    // Solo con el fichero de recuperación vuelven las KEK (sin envolturas posteriores)
    const kekOnly = path.join(home, 'solo-kek');
    importRecovery(kekOnly, file, phrase);
    expect(new KeyStore({ home: kekOnly, dome: 'D' }).kekId()).toBe(ks.kekId());
    // Importar sobre una KEK distinta se rechaza
    const other = path.join(home, 'otro');
    new KeyStore({ home: other, dome: 'D' }).init();
    expect(() => importRecovery(other, file, phrase, backup)).toThrow(/INVALID_INPUT/);
  }, 60_000);
});
