// SE-417 — almacén de claves de Savia Files, fuera del almacén y de cualquier repo git:
//   <keys home>/<cúpula>/kek               KEK de la cúpula (32 B, 0600)
//   <keys home>/<cúpula>/kek.prev          solo durante una rotación
//   <keys home>/<cúpula>/wraps/<rev>.json  DEK de la revisión envuelta con la KEK
//   <keys home>/recovery.pub               clave pública de recuperación (tras exportar)
// Borrar la envoltura = borrado criptográfico de la revisión. Las copias nocturnas de claves
// se sellan para la clave pública de recuperación: solo las abre quien tiene la frase.
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { ensureSafeHome, writeAtomic } from '../rag/store.js';
import { RagError } from '../rag/types.js';
import {
  boxKeypair, deriveSubkey, keyId, open, openRecovery, openSealedBox, randomKey, seal, sealRecovery, sealTo, type SubkeyKind,
} from './crypto.js';
import { FilesError } from './types.js';
import type { IndexCipher } from '../rag/types.js';

const DOME_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
const REV_RE = /^r_[0-9a-f]{16}$/;

export function keysHome(env: NodeJS.ProcessEnv = process.env): string {
  return env.SAVIA_FILES_KEYS_HOME || path.join(env.HOME || os.homedir(), '.savia-vaults', 'keys', 'files');
}

export interface DekRef { documentId: string; revisionId: string }

function safeHome(home: string): void {
  try {
    ensureSafeHome(home);
  } catch (e) {
    if (e instanceof RagError && e.code === 'UNSAFE_HOME') throw new FilesError('UNSAFE_HOME', `el almacén de claves (${home}) está dentro de un repo git`);
    throw e;
  }
}

const writeSecret = (file: string, data: Uint8Array | string) => {
  writeAtomic(file, data);
  fs.chmodSync(file, 0o600);
};

export class KeyStore {
  readonly home: string;
  readonly dome: string;
  readonly dir: string;

  constructor(o: { home?: string; dome: string; env?: NodeJS.ProcessEnv }) {
    if (!DOME_RE.test(o.dome)) throw new FilesError('INVALID_INPUT', `cúpula no válida: ${o.dome}`);
    this.home = path.resolve(o.home ?? keysHome(o.env));
    this.dome = o.dome;
    this.dir = path.join(this.home, o.dome);
  }

  private get wrapsDir(): string { return path.join(this.dir, 'wraps'); }

  hasKey(): boolean {
    return fs.existsSync(path.join(this.dir, 'kek'));
  }

  /** Crea la KEK si no existe. Nunca la sustituye. */
  init(): void {
    safeHome(this.home);
    fs.mkdirSync(this.wrapsDir, { recursive: true, mode: 0o700 });
    fs.chmodSync(this.dir, 0o700);
    if (!this.hasKey()) writeSecret(path.join(this.dir, 'kek'), randomKey());
  }

  private readKey(name: 'kek' | 'kek.prev'): Buffer | undefined {
    try {
      const k = fs.readFileSync(path.join(this.dir, name));
      if (k.length !== 32) throw new FilesError('INTEGRITY', `la clave ${name} de ${this.dome} está dañada`);
      return k;
    } catch (e) {
      if ((e as NodeJS.ErrnoException).code === 'ENOENT') return undefined;
      throw e;
    }
  }

  kek(): Buffer {
    const k = this.readKey('kek');
    if (!k) {
      throw new FilesError('KEY_MISSING', `falta la clave de cifrado de la cúpula "${this.dome}": restáurala con files keys import (fichero y frase de recuperación)`);
    }
    return k;
  }

  kekId(): string {
    return keyId(this.kek());
  }

  /** Subclave de la KEK actual o, durante una rotación, de la anterior. */
  subkey(kind: SubkeyKind, which: 'current' | 'prev' = 'current'): Buffer | undefined {
    const k = which === 'current' ? this.kek() : this.readKey('kek.prev');
    return k ? deriveSubkey(k, kind) : undefined;
  }

  private aad(ref: DekRef) {
    return { schemaVersion: 1, domeId: this.dome, documentId: ref.documentId, revisionId: ref.revisionId, artifactKind: 'dek' };
  }

  private wrapPath(revisionId: string): string {
    if (!REV_RE.test(revisionId)) throw new FilesError('INVALID_INPUT', `revisionId no válido: ${revisionId}`);
    return path.join(this.wrapsDir, `${revisionId}.json`);
  }

  private writeWrap(ref: DekRef, dek: Uint8Array, kek: Buffer): void {
    fs.mkdirSync(this.wrapsDir, { recursive: true, mode: 0o700 });
    writeSecret(this.wrapPath(ref.revisionId), JSON.stringify({ v: 1, documentId: ref.documentId, kekId: keyId(kek), sealed: seal(kek, dek, this.aad(ref)).toString('base64') }));
  }

  newDek(ref: DekRef): Buffer {
    const dek = randomKey();
    this.writeWrap(ref, dek, this.kek());
    return dek;
  }

  dek(ref: DekRef): Buffer {
    let raw: string;
    try {
      raw = fs.readFileSync(this.wrapPath(ref.revisionId), 'utf-8');
    } catch {
      throw new FilesError('NOT_FOUND', `la clave de la revisión ${ref.revisionId} no existe (borrada)`);
    }
    let w: { kekId: string; sealed: string };
    try { w = JSON.parse(raw); } catch { throw new FilesError('INTEGRITY', `envoltura de ${ref.revisionId} dañada`); }
    const current = this.kek();
    const prev = this.readKey('kek.prev');
    const kek = w.kekId === keyId(current) ? current : prev && w.kekId === keyId(prev) ? prev : undefined;
    if (!kek) throw new FilesError('KEY_MISSING', `la envoltura de ${ref.revisionId} es de una clave que ya no está`);
    return open(kek, Buffer.from(w.sealed, 'base64'), this.aad(ref));
  }

  destroyDek(revisionId: string): void {
    fs.rmSync(this.wrapPath(revisionId), { force: true });
  }

  /**
   * Rotación reanudable: kek.prev = KEK actual, KEK nueva, re-envolver todas las DEK,
   * `reseal(prev, next)` para lo sellado con subclaves (metadatos, índice) y borrar kek.prev.
   * Si se corta, repetirla la completa: `dek()` sabe abrir con cualquiera de las dos.
   */
  rotate(onStep: (step: string) => void, reseal?: () => void): void {
    this.kek();
    if (!this.readKey('kek.prev')) {
      const next = path.join(this.dir, 'kek.next');
      writeSecret(next, randomKey());
      fs.renameSync(path.join(this.dir, 'kek'), path.join(this.dir, 'kek.prev'));
      fs.renameSync(next, path.join(this.dir, 'kek'));
    }
    onStep('kek');
    const current = this.kek();
    const currentId = keyId(current);
    let n = 0;
    for (const f of fs.existsSync(this.wrapsDir) ? fs.readdirSync(this.wrapsDir) : []) {
      if (!f.endsWith('.json')) continue;
      const revisionId = f.slice(0, -5);
      const w = JSON.parse(fs.readFileSync(path.join(this.wrapsDir, f), 'utf-8')) as { kekId: string; documentId: string };
      if (w.kekId === currentId) continue;
      const ref = { documentId: w.documentId, revisionId };
      this.writeWrap(ref, this.dek(ref), current);
      n++;
      onStep(`rewrapped:${n}`);
    }
    reseal?.();
    onStep('resealed');
    fs.rmSync(path.join(this.dir, 'kek.prev'), { force: true });
  }

  /** KEK (y la anterior si hay rotación en curso) y envolturas, para la copia de claves. */
  snapshot(): { kek: string; prev?: string; wraps: Record<string, string> } {
    const wraps: Record<string, string> = {};
    for (const f of fs.existsSync(this.wrapsDir) ? fs.readdirSync(this.wrapsDir) : []) {
      if (f.endsWith('.json')) wraps[f.slice(0, -5)] = fs.readFileSync(path.join(this.wrapsDir, f), 'utf-8');
    }
    const prev = this.readKey('kek.prev');
    return { kek: this.kek().toString('base64'), ...(prev ? { prev: prev.toString('base64') } : {}), wraps };
  }

  /** Restaura desde una copia; rechaza pisar una KEK distinta. */
  restore(snap: { kek: string; prev?: string; wraps?: Record<string, string> }): void {
    safeHome(this.home);
    const kek = Buffer.from(snap.kek, 'base64');
    const existing = this.readKey('kek');
    if (existing && !existing.equals(kek)) {
      throw new FilesError('INVALID_INPUT', `la cúpula "${this.dome}" ya tiene otra clave; no se sobrescribe`);
    }
    fs.mkdirSync(this.wrapsDir, { recursive: true, mode: 0o700 });
    fs.chmodSync(this.dir, 0o700);
    if (!existing) writeSecret(path.join(this.dir, 'kek'), kek);
    if (snap.prev) writeSecret(path.join(this.dir, 'kek.prev'), Buffer.from(snap.prev, 'base64'));
    for (const [rev, content] of Object.entries(snap.wraps ?? {})) {
      if (!fs.existsSync(this.wrapPath(rev))) writeSecret(this.wrapPath(rev), content);
    }
  }
}

function domesIn(home: string): string[] {
  if (!fs.existsSync(home)) return [];
  return fs.readdirSync(home).filter((d) => DOME_RE.test(d) && fs.existsSync(path.join(home, d, 'kek'))).sort();
}

export function hasRecovery(home: string = keysHome()): boolean {
  return fs.existsSync(path.join(home, 'recovery.pub'));
}

/**
 * Fichero de recuperación: clave privada de recuperación + KEK de todas las cúpulas, cifrado
 * con una frase nueva que se muestra una sola vez. Deja `recovery.pub` para sellar las copias.
 */
export function exportRecovery(home: string = keysHome()): { file: Buffer; phrase: string; domes: string[] } {
  const domes = domesIn(home);
  if (!domes.length) throw new FilesError('KEY_MISSING', 'no hay claves de cúpula que exportar');
  const kp = boxKeypair();
  const payload = {
    v: 1, recoveryPublicKey: kp.publicKey.toString('base64'), recoveryPrivateKey: kp.privateKey.toString('base64'),
    domes: Object.fromEntries(domes.map((d) => [d, { kek: new KeyStore({ home, dome: d }).kek().toString('base64') }])),
  };
  const out = sealRecovery(Buffer.from(JSON.stringify(payload)));
  writeSecret(path.join(home, 'recovery.pub'), kp.publicKey.toString('base64'));
  return { file: out.file, phrase: out.phrase, domes };
}

/** Copia de todas las claves (KEK + envolturas) sellada para la clave pública de recuperación. */
export function sealKeyBackup(home: string = keysHome()): Buffer {
  if (!hasRecovery(home)) throw new FilesError('KEY_MISSING', 'sin copia de recuperación: exporta antes el fichero de recuperación (files keys export)');
  const pub = Buffer.from(fs.readFileSync(path.join(home, 'recovery.pub'), 'utf-8'), 'base64');
  const all = Object.fromEntries(domesIn(home).map((d) => [d, new KeyStore({ home, dome: d }).snapshot()]));
  return sealTo(pub, Buffer.from(JSON.stringify({ v: 1, createdAt: new Date().toISOString(), domes: all })));
}

/**
 * Restaura claves en `home` con el fichero y la frase de recuperación. Con `backup` (copia
 * nocturna sellada) recupera también las envolturas; sin ella, solo las KEK.
 */
export function importRecovery(home: string, recoveryFile: Uint8Array, phrase: string, backup?: Uint8Array): string[] {
  const rec = JSON.parse(openRecovery(recoveryFile, phrase).toString('utf-8')) as {
    recoveryPublicKey: string; recoveryPrivateKey: string; domes: Record<string, { kek: string }>;
  };
  let snaps: Record<string, { kek: string; prev?: string; wraps?: Record<string, string> }> = rec.domes;
  if (backup) {
    const opened = openSealedBox(Buffer.from(rec.recoveryPublicKey, 'base64'), Buffer.from(rec.recoveryPrivateKey, 'base64'), backup);
    snaps = { ...snaps, ...(JSON.parse(opened.toString('utf-8')) as { domes: typeof snaps }).domes };
  }
  // Comprobar todas antes de escribir ninguna
  for (const [d, snap] of Object.entries(snaps)) {
    const existing = new KeyStore({ home, dome: d });
    if (existing.hasKey() && !existing.kek().equals(Buffer.from(snap.kek, 'base64'))) {
      throw new FilesError('INVALID_INPUT', `la cúpula "${d}" ya tiene otra clave; no se sobrescribe`);
    }
  }
  for (const [d, snap] of Object.entries(snaps)) new KeyStore({ home, dome: d }).restore(snap);
  writeSecret(path.join(home, 'recovery.pub'), rec.recoveryPublicKey);
  return Object.keys(snaps);
}

/**
 * SE-417: cifrador del índice de Savia RAG de una cúpula cifrada (subclave `index`; durante una
 * rotación abre también con la anterior).
 */
export function indexCipher(keys: KeyStore): IndexCipher {
  const aad = (part: string) => ({ schemaVersion: 1, domeId: keys.dome, part, artifactKind: 'index' });
  return {
    seal: (data, part) => seal(keys.subkey('index')!, data, aad(part)),
    open: (data, part) => {
      try {
        return open(keys.subkey('index')!, data, aad(part));
      } catch (e) {
        const prev = keys.subkey('index', 'prev');
        if (!prev) throw e;
        return open(prev, data, aad(part));
      }
    },
  };
}
