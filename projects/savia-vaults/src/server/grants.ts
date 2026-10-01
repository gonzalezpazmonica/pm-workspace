// SE-422 — autorizaciones acotadas de la API HTTP de ficheros: permiten que un tercero (un
// navegador, curl, otra persona) suba un fichero o descargue uno sin conocer el token del usuario.
// HMAC-SHA256 con clave propia (`<keys home>/_http/token.key`, 0600); formato
// `svt1.<payload b64url>.<mac b64url>`. El servidor revalida al usuario en cada uso y consume el
// `jti` de las subidas (un solo uso).
import * as fs from 'node:fs';
import * as path from 'node:path';
import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { ensureSafeHome, writeAtomic } from '../rag/store.js';

export interface ScopedTokenInput {
  kind: 'upload' | 'download';
  dome: string;
  /** Usuario en cuyo nombre actúa. */
  sub: string;
  /** SE-423: credencial que la emitió; revocarla (o que caduque) invalida la autorización. */
  cid?: string;
  maxBytes?: number;
  name?: string;
  tags?: string[];
  confidentiality?: string;
  replaces?: string;
  documentId?: string;
  revisionId?: string;
}

export interface ScopedToken extends ScopedTokenInput { exp: number; jti: string }

export class TokenError extends Error {
  readonly code = 'unauthorized';
  constructor(message: string) {
    super(message);
    this.name = 'TokenError';
  }
}

const PREFIX = 'svt1';
const MAX_CHARS = 4096;

export class TokenSigner {
  private readonly dir: string;

  constructor(keysHome: string) {
    this.dir = path.join(keysHome, '_http');
  }

  static looksLike(value: string): boolean {
    return typeof value === 'string' && value.startsWith(`${PREFIX}.`);
  }

  private get keyPath(): string { return path.join(this.dir, 'token.key'); }

  private key(): Buffer {
    try {
      const k = fs.readFileSync(this.keyPath);
      if (k.length === 32) return k;
    } catch { /* se crea */ }
    return this.rotate();
  }

  /** Clave nueva: todo lo emitido deja de valer. */
  rotate(): Buffer {
    ensureSafeHome(path.dirname(this.dir));
    fs.mkdirSync(this.dir, { recursive: true, mode: 0o700 });
    fs.chmodSync(this.dir, 0o700);
    const k = randomBytes(32);
    writeAtomic(this.keyPath, k);
    fs.chmodSync(this.keyPath, 0o600);
    return k;
  }

  sign(input: ScopedTokenInput, ttlMs: number): string {
    const payload: ScopedToken = { ...input, exp: Date.now() + ttlMs, jti: randomBytes(16).toString('hex') };
    const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const mac = createHmac('sha256', this.key()).update(`${PREFIX}.${body}`).digest('base64url');
    return `${PREFIX}.${body}.${mac}`;
  }

  verify(value: string): ScopedToken {
    if (typeof value !== 'string' || value.length > MAX_CHARS) throw new TokenError('token no válido');
    const parts = value.split('.');
    if (parts.length !== 3 || parts[0] !== PREFIX || !parts[1] || !parts[2]) throw new TokenError('token no válido');
    const expected = createHmac('sha256', this.key()).update(`${PREFIX}.${parts[1]}`).digest();
    const got = Buffer.from(parts[2], 'base64url');
    if (got.length !== expected.length || !timingSafeEqual(got, expected)) throw new TokenError('token no válido: firma incorrecta');
    let p: ScopedToken;
    try {
      p = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf-8')) as ScopedToken;
    } catch {
      throw new TokenError('token no válido');
    }
    if (!p || (p.kind !== 'upload' && p.kind !== 'download') || typeof p.dome !== 'string' || typeof p.sub !== 'string'
      || typeof p.exp !== 'number' || typeof p.jti !== 'string') throw new TokenError('token no válido');
    if (p.exp <= Date.now()) throw new TokenError('token caducado');
    return p;
  }
}
