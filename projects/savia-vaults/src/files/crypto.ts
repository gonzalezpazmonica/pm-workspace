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

/**
 * SE-421: cifrado SVF1 incremental. `header()` una vez, luego `push(trozo, final)`; cada `push`
 * parte en frames de hasta FRAME_PLAIN_BYTES. El último frame lleva TAG_FINAL (un fichero vacío es
 * un único frame final vacío). Memoria acotada: no guarda nada entre llamadas.
 */
export class StreamEncryptor {
  private readonly state: ReturnType<typeof sodium.crypto_secretstream_xchacha20poly1305_init_push>['state'];
  private readonly head: Buffer;
  private readonly ad: Buffer;
  private done = false;

  constructor(key: Uint8Array, aad: object) {
    const so = s();
    const { state, header } = so.crypto_secretstream_xchacha20poly1305_init_push(key);
    this.state = state;
    this.head = Buffer.concat([MAGIC, Buffer.from(header)]);
    this.ad = aadBytes(aad);
  }

  header(): Buffer { return this.head; }

  push(plain: Uint8Array, final: boolean): Buffer {
    if (this.done) throw new Error('StreamEncryptor: ya se envió el frame final');
    const so = s();
    const parts: Buffer[] = [];
    let off = 0;
    do {
      const end = Math.min(off + FRAME_PLAIN_BYTES, plain.length);
      const last = final && end >= plain.length;
      if (end === off && !last) break; // trozo vacío no final: nada que cifrar
      const tag = last ? so.crypto_secretstream_xchacha20poly1305_TAG_FINAL : so.crypto_secretstream_xchacha20poly1305_TAG_MESSAGE;
      const ct = so.crypto_secretstream_xchacha20poly1305_push(this.state, plain.subarray(off, end), this.ad, tag);
      const len = Buffer.alloc(4);
      len.writeUInt32BE(ct.length, 0);
      parts.push(len, Buffer.from(ct));
      off = end;
    } while (off < plain.length);
    if (final) this.done = true;
    return Buffer.concat(parts);
  }
}

/**
 * SE-421: descifrado SVF1 incremental. `feed(bytes)` devuelve el texto en claro de los frames
 * completos recibidos; `end()` exige haber visto TAG_FINAL y nada después. Cualquier fallo ⇒ INTEGRITY.
 */
export class StreamDecryptor {
  private readonly ad: Buffer;
  private buf = Buffer.alloc(0);
  private state: ReturnType<typeof sodium.crypto_secretstream_xchacha20poly1305_init_pull> | undefined;
  private final = false;

  constructor(private readonly key: Uint8Array, aad: object) {
    this.ad = aadBytes(aad);
  }

  get finished(): boolean { return this.final; }

  feed(data: Uint8Array): Buffer[] {
    const so = s();
    this.buf = this.buf.length ? Buffer.concat([this.buf, data]) : Buffer.from(data);
    const out: Buffer[] = [];
    const H = so.crypto_secretstream_xchacha20poly1305_HEADERBYTES;
    if (!this.state) {
      if (this.buf.length < 4 + H) return out;
      if (!this.buf.subarray(0, 4).equals(MAGIC)) throw integrity('fichero cifrado');
      try {
        this.state = so.crypto_secretstream_xchacha20poly1305_init_pull(this.buf.subarray(4, 4 + H), this.key);
      } catch {
        throw integrity('fichero cifrado');
      }
      this.buf = this.buf.subarray(4 + H);
    }
    while (this.buf.length >= 4) {
      if (this.final) throw integrity('fichero cifrado (datos tras el frame final)');
      const len = this.buf.readUInt32BE(0);
      if (len < so.crypto_secretstream_xchacha20poly1305_ABYTES || len > FRAME_PLAIN_BYTES + so.crypto_secretstream_xchacha20poly1305_ABYTES) {
        throw integrity('fichero cifrado');
      }
      if (this.buf.length < 4 + len) break;
      let r;
      try {
        r = so.crypto_secretstream_xchacha20poly1305_pull(this.state, this.buf.subarray(4, 4 + len), this.ad);
      } catch {
        throw integrity('fichero cifrado');
      }
      if (!r) throw integrity('fichero cifrado');
      out.push(Buffer.from(r.message));
      this.final = r.tag === so.crypto_secretstream_xchacha20poly1305_TAG_FINAL;
      this.buf = this.buf.subarray(4 + len);
    }
    return out;
  }

  end(): void {
    if (!this.state || !this.final || this.buf.length) throw integrity('fichero cifrado (sin frame final)');
  }
}

export function encryptStream(key: Uint8Array, plain: Uint8Array, aad: object): Buffer {
  const enc = new StreamEncryptor(key, aad);
  return Buffer.concat([enc.header(), enc.push(plain, true)]);
}

export function decryptStream(key: Uint8Array, data: Uint8Array, aad: object): Buffer {
  const dec = new StreamDecryptor(key, aad);
  const out = dec.feed(data);
  dec.end();
  return Buffer.concat(out);
}

/**
 * SE-421: subida parcial cifrada (SVFU1) para las subidas reanudables de SE-422. Cada trozo se
 * sella por separado (construcción STREAM: AAD con subida, índice y marca de final), así que la
 * subida se reanuda aunque el proceso se reinicie. Formato: "SVFU1" | [uint32BE longitud | sellado]*.
 */
export const UPLOAD_MAGIC = Buffer.from('SVFU1');

export function sealUploadChunk(key: Uint8Array, uploadId: string, index: number, plain: Uint8Array, final: boolean): Buffer {
  const sealed = seal(key, plain, { schemaVersion: 1, uploadId, index, final, artifactKind: 'upload' });
  const len = Buffer.alloc(4);
  len.writeUInt32BE(sealed.length, 0);
  return Buffer.concat([len, sealed]);
}

/** Recorre los trozos de una subida SVFU1 en orden, verificando índice y final. */
export function* openUploadChunks(key: Uint8Array, uploadId: string, data: Uint8Array): Generator<Buffer> {
  const b = Buffer.from(data.buffer, data.byteOffset, data.byteLength);
  if (!b.subarray(0, UPLOAD_MAGIC.length).equals(UPLOAD_MAGIC)) throw integrity('subida cifrada');
  let p = UPLOAD_MAGIC.length;
  let index = 0;
  let final = false;
  while (p < b.length) {
    if (final || p + 4 > b.length) throw integrity('subida cifrada');
    const len = b.readUInt32BE(p);
    p += 4;
    if (p + len > b.length) throw integrity('subida cifrada');
    const chunk = b.subarray(p, p + len);
    let plain: Buffer;
    try {
      plain = open(key, chunk, { schemaVersion: 1, uploadId, index, final: false, artifactKind: 'upload' });
    } catch {
      plain = open(key, chunk, { schemaVersion: 1, uploadId, index, final: true, artifactKind: 'upload' });
      final = true;
    }
    yield plain;
    index++;
    p += len;
  }
  if (!final) throw integrity('subida cifrada (sin trozo final)');
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
