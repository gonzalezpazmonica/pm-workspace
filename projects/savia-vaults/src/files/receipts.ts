// SE-418 — receipts firmados de Savia Files. Ed25519 (node:crypto) sobre
// UTF8("savia-files-receipt-v1\n") + JCS(receipt sin signature), firma en base64url sin relleno.
// Clave propia de Files, separada de KEK/DEK y de la de VaultSecurity:
//   <keys home>/_signing/<keyId>.pem   clave privada (0600)
//   <keys home>/_signing/registry.json claves públicas con periodos; rotar conserva las anteriores
// Solo el registro crea confianza: una clave que viniera en el receipt no cuenta.
import * as fs from 'node:fs';
import * as path from 'node:path';
import { createHash, createPrivateKey, createPublicKey, generateKeyPairSync, sign, verify } from 'node:crypto';
import { ensureSafeHome, writeAtomic } from '../rag/store.js';
import { RagError } from '../rag/types.js';
import { canonicalJson } from './crypto.js';
import { FilesError } from './types.js';

export type ReceiptStatus = 'pending' | 'committed' | 'failed';
export interface ReceiptRef { documentId: string; revisionId?: string }

export interface Receipt {
  operationId: string;
  dome: string;
  kind: string;
  refs?: ReceiptRef[];
  status: ReceiptStatus;
  commitSha?: string;
  manifestHash?: string;
  errorCode?: string;
  at: string;
  algorithm: 'Ed25519';
  keyId: string;
  signature: string;
}

export type UnsignedReceipt = Omit<Receipt, 'algorithm' | 'keyId' | 'signature'>;

interface RegistryEntry { keyId: string; publicKey: string; createdAt: string; retiredAt?: string }
interface Registry { v: 1; keys: RegistryEntry[] }
export interface SigningSnapshot { registry: Registry; keys: Record<string, string> }

const DOMAIN = Buffer.from('savia-files-receipt-v1\n', 'utf-8');
const KEY_ID_RE = /^[0-9a-f]{16}$/;

const payloadOf = (r: Omit<Receipt, 'signature'>) => Buffer.concat([DOMAIN, Buffer.from(canonicalJson(r), 'utf-8')]);
const rawPublic = (pem: string) => Buffer.from(createPublicKey(pem).export({ format: 'jwk' }).x!, 'base64url');
const idOf = (raw: Buffer) => createHash('sha256').update(raw).digest('hex').slice(0, 16);

/** Quita los campos `undefined`: la firma es la misma antes y después de un JSON.parse. */
function clean<T extends object>(o: T): T {
  return Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined)) as T;
}

export class ReceiptSigner {
  readonly dir: string;

  constructor(keysHome: string) {
    this.dir = path.join(keysHome, '_signing');
  }

  private get registryPath(): string { return path.join(this.dir, 'registry.json'); }

  registry(): Registry {
    try {
      const r = JSON.parse(fs.readFileSync(this.registryPath, 'utf-8')) as Registry;
      if (r?.v === 1 && Array.isArray(r.keys)) return r;
    } catch { /* sin registro */ }
    return { v: 1, keys: [] };
  }

  /** Clave vigente; si no hay ninguna, crea la primera. */
  private active(): { entry: RegistryEntry; pem: string } {
    const entry = this.registry().keys.filter((k) => !k.retiredAt).at(-1) ?? this.rotate();
    return { entry, pem: fs.readFileSync(path.join(this.dir, `${entry.keyId}.pem`), 'utf-8') };
  }

  /** Clave nueva; la anterior queda retirada en el registro (sus receipts siguen verificando). */
  rotate(): RegistryEntry {
    try {
      ensureSafeHome(path.dirname(this.dir));
    } catch (e) {
      if (e instanceof RagError && e.code === 'UNSAFE_HOME') throw new FilesError('UNSAFE_HOME', `las claves de firma (${this.dir}) estarían dentro de un repo git`);
      throw e;
    }
    fs.mkdirSync(this.dir, { recursive: true, mode: 0o700 });
    fs.chmodSync(this.dir, 0o700);
    const { privateKey, publicKey } = generateKeyPairSync('ed25519');
    const raw = rawPublic(publicKey.export({ type: 'spki', format: 'pem' }) as string);
    const entry: RegistryEntry = { keyId: idOf(raw), publicKey: raw.toString('base64'), createdAt: new Date().toISOString() };
    const pemFile = path.join(this.dir, `${entry.keyId}.pem`);
    writeAtomic(pemFile, privateKey.export({ type: 'pkcs8', format: 'pem' }) as string);
    fs.chmodSync(pemFile, 0o600);
    const reg = this.registry();
    for (const k of reg.keys) if (!k.retiredAt) k.retiredAt = entry.createdAt;
    reg.keys.push(entry);
    writeAtomic(this.registryPath, JSON.stringify(reg, null, 1));
    return entry;
  }

  sign(r: UnsignedReceipt): Receipt {
    const { entry, pem } = this.active();
    const body = clean({ ...r, algorithm: 'Ed25519' as const, keyId: entry.keyId });
    const signature = sign(null, payloadOf(body), createPrivateKey(pem)).toString('base64url');
    return { ...body, signature };
  }

  /** true si la firma es válida con una clave del registro no retirada en la fecha del receipt. */
  verify(r: Receipt): boolean {
    if (!r || r.algorithm !== 'Ed25519' || typeof r.signature !== 'string' || !KEY_ID_RE.test(String(r.keyId))) return false;
    const entry = this.registry().keys.find((k) => k.keyId === r.keyId);
    // Tras retirarla, una clave no firma nada nuevo. (Antedatar sigue siendo posible para quien la robe:
    // el periodo no sustituye a proteger la clave.)
    if (!entry || typeof r.at !== 'string' || (entry.retiredAt && r.at > entry.retiredAt)) return false;
    const { signature, ...body } = r;
    try {
      const x = Buffer.from(entry.publicKey, 'base64').toString('base64url');
      const key = createPublicKey({ key: { kty: 'OKP', crv: 'Ed25519', x }, format: 'jwk' });
      return verify(null, payloadOf(body), key, Buffer.from(signature, 'base64url'));
    } catch {
      return false;
    }
  }

  /** Para la copia de claves sellada (SE-417): registro y claves privadas. */
  snapshot(): SigningSnapshot | undefined {
    const registry = this.registry();
    if (!registry.keys.length) return undefined;
    const keys: Record<string, string> = {};
    for (const k of registry.keys) {
      const f = path.join(this.dir, `${k.keyId}.pem`);
      if (fs.existsSync(f)) keys[k.keyId] = fs.readFileSync(f, 'utf-8');
    }
    return { registry, keys };
  }

  /** Restaura una instantánea: une los registros y añade las claves que falten (verificando su keyId). */
  restore(snap: SigningSnapshot): void {
    if (snap?.registry?.v !== 1 || !Array.isArray(snap.registry.keys)) throw new FilesError('INVALID_INPUT', 'copia de claves de firma no válida');
    fs.mkdirSync(this.dir, { recursive: true, mode: 0o700 });
    const reg = this.registry();
    for (const k of snap.registry.keys) {
      if (!KEY_ID_RE.test(String(k.keyId)) || idOf(Buffer.from(String(k.publicKey), 'base64')) !== k.keyId) continue;
      if (!reg.keys.some((x) => x.keyId === k.keyId)) reg.keys.push(k);
      const pem = snap.keys?.[k.keyId];
      const file = path.join(this.dir, `${k.keyId}.pem`);
      if (pem && !fs.existsSync(file) && idOf(rawPublic(pem)) === k.keyId) {
        writeAtomic(file, pem);
        fs.chmodSync(file, 0o600);
      }
    }
    reg.keys.sort((a, b) => (a.createdAt < b.createdAt ? -1 : a.createdAt > b.createdAt ? 1 : 0));
    writeAtomic(this.registryPath, JSON.stringify(reg, null, 1));
  }
}
