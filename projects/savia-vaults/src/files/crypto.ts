// SE-417 — primitivas de cifrado de Savia Files sobre libsodium (sin criptografía propia).
//  · seal/open: XChaCha20-Poly1305 IETF con AAD en JSON canónico (RFC 8785).
//  · encryptStream/decryptStream: crypto_secretstream_xchacha20poly1305 por frames
//    ("SVF1" | cabecera 24 B | [uint32BE longitud | ciphertext]*), TAG_FINAL obligatorio.
//  · deriveSubkey (crypto_kdf), opaqueName (BLAKE2b con clave), recuperación con Argon2id.
import sodium from 'libsodium-wrappers-sumo';
import { FilesError } from './types.js';

export const FRAME_PLAIN_BYTES = 1024 * 1024;
const MAGIC = Buffer.from('SVF1');
const RECOVERY_MAGIC = Buffer.from('SVFR1');
const KDF_CONTEXT = 'savfiles'; // 8 bytes exactos (crypto_kdf_CONTEXTBYTES)
const SUBKEY_IDS = { meta: 1, index: 2, name: 3 } as const;
export type SubkeyKind = keyof typeof SUBKEY_IDS;

let ready = false;
export async function sodiumReady(): Promise<void> {
  if (!ready) { await sodium.ready; ready = true; }
}
function s(): typeof sodium {
  if (!ready) throw new Error('libsodium no inicializado: llamar antes a sodiumReady()');
  return sodium;
}

const integrity = (what: string) => new FilesError('INTEGRITY', `${what}: autenticación fallida (dato manipulado, truncado o clave incorrecta)`);

/** JSON canónico (RFC 8785) para los valores usados como AAD: objetos con claves ordenadas, sin espacios. */
export function canonicalJson(v: unknown): string {
  if (v === null || typeof v !== 'object') return JSON.stringify(v);
  if (Array.isArray(v)) return `[${v.map(canonicalJson).join(',')}]`;
  const o = v as Record<string, unknown>;
  return `{${Object.keys(o).sort().filter((k) => o[k] !== undefined).map((k) => `${JSON.stringify(k)}:${canonicalJson(o[k])}`).join(',')}}`;
}

const aadBytes = (aad: object) => Buffer.from(canonicalJson(aad), 'utf-8');

/** nonce(24) || ciphertext+tag. */
export function seal(key: Uint8Array, plain: Uint8Array, aad: object): Buffer {
  const so = s();
  const nonce = so.randombytes_buf(so.crypto_aead_xchacha20poly1305_ietf_NPUBBYTES);
  const ct = so.crypto_aead_xchacha20poly1305_ietf_encrypt(plain, aadBytes(aad), null, nonce, key);
  return Buffer.concat([Buffer.from(nonce), Buffer.from(ct)]);
}

export function open(key: Uint8Array, sealed: Uint8Array, aad: object): Buffer {
  const so = s();
  const n = so.crypto_aead_xchacha20poly1305_ietf_NPUBBYTES;
  if (sealed.length < n + so.crypto_aead_xchacha20poly1305_ietf_ABYTES) throw integrity('sellado');
  try {
    return Buffer.from(so.crypto_aead_xchacha20poly1305_ietf_decrypt(null, sealed.subarray(n), aadBytes(aad), sealed.subarray(0, n), key));
  } catch {
    throw integrity('sellado');
  }
}

export function encryptStream(key: Uint8Array, plain: Uint8Array, aad: object): Buffer {
  const so = s();
  const { state, header } = so.crypto_secretstream_xchacha20poly1305_init_push(key);
  const ad = aadBytes(aad);
  const parts: Buffer[] = [MAGIC, Buffer.from(header)];
  let off = 0;
  do {
    const end = Math.min(off + FRAME_PLAIN_BYTES, plain.length);
    const last = end >= plain.length;
    const tag = last ? so.crypto_secretstream_xchacha20poly1305_TAG_FINAL : so.crypto_secretstream_xchacha20poly1305_TAG_MESSAGE;
    const ct = so.crypto_secretstream_xchacha20poly1305_push(state, plain.subarray(off, end), ad, tag);
    const len = Buffer.alloc(4);
    len.writeUInt32BE(ct.length, 0);
    parts.push(len, Buffer.from(ct));
    off = end;
  } while (off < plain.length);
  return Buffer.concat(parts);
}

export function decryptStream(key: Uint8Array, data: Uint8Array, aad: object): Buffer {
  const so = s();
  const b = Buffer.from(data.buffer, data.byteOffset, data.byteLength);
  const H = so.crypto_secretstream_xchacha20poly1305_HEADERBYTES;
  if (b.length < 4 + H || !b.subarray(0, 4).equals(MAGIC)) throw integrity('fichero cifrado');
  let state;
  try {
    state = so.crypto_secretstream_xchacha20poly1305_init_pull(b.subarray(4, 4 + H), key);
  } catch {
    throw integrity('fichero cifrado');
  }
  const ad = aadBytes(aad);
  const out: Buffer[] = [];
  let p = 4 + H;
  let final = false;
  while (p < b.length) {
    if (final || p + 4 > b.length) throw integrity('fichero cifrado');
    const len = b.readUInt32BE(p);
    p += 4;
    if (len < so.crypto_secretstream_xchacha20poly1305_ABYTES || len > FRAME_PLAIN_BYTES + so.crypto_secretstream_xchacha20poly1305_ABYTES || p + len > b.length) {
      throw integrity('fichero cifrado');
    }
    let r;
    try {
      r = so.crypto_secretstream_xchacha20poly1305_pull(state, b.subarray(p, p + len), ad);
    } catch {
      throw integrity('fichero cifrado');
    }
    if (!r) throw integrity('fichero cifrado');
    out.push(Buffer.from(r.message));
    final = r.tag === so.crypto_secretstream_xchacha20poly1305_TAG_FINAL;
    p += len;
  }
  if (!final) throw integrity('fichero cifrado (sin frame final)');
  return Buffer.concat(out);
}

export function deriveSubkey(kek: Uint8Array, kind: SubkeyKind): Buffer {
  return Buffer.from(s().crypto_kdf_derive_from_key(32, SUBKEY_IDS[kind], KDF_CONTEXT, kek));
}

/** Nombre de fichero opaco y estable para una revisión (BLAKE2b-256 con clave). */
export function opaqueName(nameKey: Uint8Array, id: string): string {
  return Buffer.from(s().crypto_generichash(32, Buffer.from(id), nameKey)).toString('hex');
}

/** Identificador público de una clave (no la revela): BLAKE2b-128 de la clave. */
export function keyId(key: Uint8Array): string {
  return Buffer.from(s().crypto_generichash(16, key, null)).toString('hex');
}

export function randomKey(): Buffer {
  return Buffer.from(s().randombytes_buf(32));
}

const WORDS = ['ala', 'bruma', 'cedro', 'duna', 'eco', 'faro', 'granito', 'hiedra', 'isla', 'jara', 'lince', 'marea',
  'nube', 'olmo', 'pino', 'quejigo', 'roble', 'sauce', 'tejo', 'umbral', 'valle', 'yedra', 'zarza', 'alba',
  'brisa', 'cierzo', 'delta', 'estepa', 'fresno', 'glaciar', 'helecho', 'iris'];

/** Frase de recuperación: 10 palabras de 32 + 4 dígitos ≈ 63 bits, reforzados con Argon2id. */
function newPhrase(): string {
  const so = s();
  const words = Array.from({ length: 10 }, () => WORDS[so.randombytes_uniform(WORDS.length)]);
  return `${words.join('-')}-${String(so.randombytes_uniform(10_000)).padStart(4, '0')}`;
}

/** Fichero de recuperación cifrado con una frase (Argon2id moderado + secretbox). */
export function sealRecovery(payload: Uint8Array, phrase = newPhrase()): { file: Buffer; phrase: string } {
  const so = s();
  const salt = so.randombytes_buf(so.crypto_pwhash_SALTBYTES);
  const key = so.crypto_pwhash(32, phrase, salt, so.crypto_pwhash_OPSLIMIT_MODERATE, so.crypto_pwhash_MEMLIMIT_MODERATE, so.crypto_pwhash_ALG_ARGON2ID13);
  const nonce = so.randombytes_buf(so.crypto_secretbox_NONCEBYTES);
  const box = so.crypto_secretbox_easy(payload, nonce, key);
  return { file: Buffer.concat([RECOVERY_MAGIC, Buffer.from(salt), Buffer.from(nonce), Buffer.from(box)]), phrase };
}

export function openRecovery(file: Uint8Array, phrase: string): Buffer {
  const so = s();
  const b = Buffer.from(file);
  const S = so.crypto_pwhash_SALTBYTES;
  const N = so.crypto_secretbox_NONCEBYTES;
  if (!b.subarray(0, RECOVERY_MAGIC.length).equals(RECOVERY_MAGIC) || b.length < RECOVERY_MAGIC.length + S + N + so.crypto_secretbox_MACBYTES) {
    throw integrity('fichero de recuperación');
  }
  const salt = b.subarray(RECOVERY_MAGIC.length, RECOVERY_MAGIC.length + S);
  const nonce = b.subarray(RECOVERY_MAGIC.length + S, RECOVERY_MAGIC.length + S + N);
  const key = so.crypto_pwhash(32, phrase.trim(), salt, so.crypto_pwhash_OPSLIMIT_MODERATE, so.crypto_pwhash_MEMLIMIT_MODERATE, so.crypto_pwhash_ALG_ARGON2ID13);
  try {
    return Buffer.from(so.crypto_secretbox_open_easy(b.subarray(RECOVERY_MAGIC.length + S + N), nonce, key));
  } catch {
    throw integrity('fichero de recuperación');
  }
}

/** Par X25519 para sellar copias de claves que solo abre quien tiene la clave privada. */
export function boxKeypair(): { publicKey: Buffer; privateKey: Buffer } {
  const kp = s().crypto_box_keypair();
  return { publicKey: Buffer.from(kp.publicKey), privateKey: Buffer.from(kp.privateKey) };
}

/** crypto_box_seal: cifrado anónimo para una clave pública. */
export function sealTo(publicKey: Uint8Array, data: Uint8Array): Buffer {
  return Buffer.from(s().crypto_box_seal(data, publicKey));
}

export function openSealedBox(publicKey: Uint8Array, privateKey: Uint8Array, data: Uint8Array): Buffer {
  try {
    return Buffer.from(s().crypto_box_seal_open(data, publicKey, privateKey));
  } catch {
    throw integrity('copia de claves');
  }
}
