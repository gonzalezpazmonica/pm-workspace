import * as fs from 'node:fs';
import * as path from 'node:path';
import * as crypto from 'node:crypto';
import { hashSync, compareSync } from 'bcryptjs';
import type { Credential, CredentialInfo, User, UserRole, UsersFile, UserV1 } from './types.js';

const DAY_MS = 86_400_000;
/** SE-423: caducidad por defecto de una credencial nueva y la de los tokens v1 migrados (D1). */
const DEFAULT_DAYS = 90;
const MIGRATED_DAYS = 365;
const ROLE_LEVEL: Record<UserRole, number> = { reader: 1, writer: 2, admin: 3 };
const CACHE_MS = 60_000;

function generateToken(): string {
  const random = crypto.randomBytes(32).toString('base64url');
  return `sv_${random}`;
}

function hashToken(token: string): string {
  return hashSync(token, 12);
}

/** Máximo de días de una credencial: `SAVIA_VAULTS_PAT_MAX_DAYS` (por defecto 365). */
function maxDays(): number {
  const v = Number(process.env.SAVIA_VAULTS_PAT_MAX_DAYS);
  return Number.isInteger(v) && v > 0 ? v : 365;
}

function isActive(c: Credential, now = Date.now()): boolean {
  return !c.revokedAt && Date.parse(c.expiresAt) > now;
}

/** El rol menor de dos (el de la credencial nunca amplía el del Subject). */
export function minRole(a: UserRole, b?: UserRole): UserRole {
  return b && ROLE_LEVEL[b] < ROLE_LEVEL[a] ? b : a;
}

export interface TokenOptions { name: string; expiresDays?: number; domes?: string[]; maxRole?: UserRole }

const USERNAME_RE = /^[A-Za-z0-9._-]{1,64}$/;

export class UserStore {
  private filePath: string;
  private users: Map<string, User> = new Map();
  private loadedKey = '';
  /**
   * SE-423 AC9: tokens ya validados (sha256 del token → credencial), 60 s como mucho. Cada uso
   * vuelve a comprobar que la credencial siga vigente: revocar o caducar vale al momento.
   */
  private validated = new Map<string, { username: string; credentialId: string; until: number }>();

  constructor(filePath: string = 'savia-vaults.users.json') {
    this.filePath = filePath;
  }

  exists(): boolean {
    return fs.existsSync(this.filePath);
  }

  /**
   * Carga el fichero. SE-423: un fichero v1 se migra y se guarda en el acto (con copia
   * `.v1.bak` en 0600), para que el Subject y la caducidad sean los mismos en todos los procesos.
   */
  load(): void {
    if (!fs.existsSync(this.filePath)) return;
    const raw = fs.readFileSync(this.filePath, 'utf-8');
    const data = JSON.parse(raw) as { version?: number; users: Record<string, User | UserV1> };
    this.users.clear();
    this.validated.clear();
    let migrated = false;
    for (const [username, u] of Object.entries(data.users ?? {})) {
      if ('credentials' in u && Array.isArray(u.credentials)) {
        this.users.set(username, u);
      } else {
        this.users.set(username, migrateV1(u as UserV1));
        migrated = true;
      }
    }
    if (migrated) {
      const bak = `${this.filePath}.v1.bak`;
      if (!fs.existsSync(bak)) fs.writeFileSync(bak, raw, { mode: 0o600 });
      fs.chmodSync(bak, 0o600);
      this.save();
    }
  }

  /** Escritura atómica (temporal + rename) en 0600: el fichero guarda hashes de credenciales. */
  save(): void {
    const data: UsersFile = { version: 2, users: {} };
    for (const [username, user] of this.users) {
      data.users[username] = user;
    }
    const dir = path.dirname(this.filePath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    const tmp = `${this.filePath}.tmp-${process.pid}-${Date.now()}`;
    try {
      fs.writeFileSync(tmp, JSON.stringify(data, null, 2) + '\n', { mode: 0o600 });
      fs.chmodSync(tmp, 0o600);
      fs.renameSync(tmp, this.filePath);
    } finally {
      fs.rmSync(tmp, { force: true });
    }
  }

  createUser(username: string, opts: { type?: 'human' | 'service'; expiresDays?: number } = {}): string {
    if (this.users.has(username)) {
      throw new Error(`User "${username}" already exists`);
    }
    this.assertNameFree(username);
    const user: User = {
      subjectId: crypto.randomUUID(),
      type: opts.type ?? 'human',
      username,
      createdAt: new Date().toISOString(),
      permissions: {},
      credentials: [],
    };
    this.users.set(username, user);
    return this.createToken(username, { name: 'principal', expiresDays: opts.expiresDays });
  }

  /** Un nombre anterior de otro usuario no se reutiliza: seguiría apareciendo en listas por documento. */
  private assertNameFree(username: string, self?: User): void {
    const owner = [...this.users.values()].find((u) => u !== self && u.formerNames?.includes(username));
    if (owner) throw new Error(`El nombre "${username}" fue de otro usuario (${owner.username}) y no se reutiliza`);
  }

  /**
   * SE-423 AC7: cambia el nombre conservando `subjectId`, credenciales y permisos. El nombre
   * anterior queda como alias para las listas readers/writers que lo citan por nombre.
   */
  renameUser(oldName: string, newName: string): void {
    const user = this.users.get(oldName);
    if (!user) throw new Error(`User "${oldName}" not found`);
    if (!USERNAME_RE.test(newName)) throw new Error('Nombre de usuario: 1 a 64 caracteres [A-Za-z0-9._-]');
    if (this.users.has(newName)) throw new Error(`User "${newName}" already exists`);
    this.assertNameFree(newName, user);
    this.users.delete(oldName);
    user.formerNames = [...new Set([...(user.formerNames ?? []).filter((n) => n !== newName), oldName])];
    user.username = newName;
    this.users.set(newName, user);
    this.validated.clear();
  }

  /** SE-423 AC7: `subjectId` de un nombre actual, o el nombre actual de un `subjectId`. */
  subjectOf(username: string): string | undefined {
    return this.users.get(username)?.subjectId;
  }

  nameOf(subjectId: string): string | undefined {
    for (const u of this.users.values()) if (u.subjectId === subjectId) return u.username;
    return undefined;
  }

  deleteUser(username: string): void {
    if (!this.users.has(username)) {
      throw new Error(`User "${username}" not found`);
    }
    this.users.delete(username);
  }

  /** SE-423: nueva credencial con caducidad y alcance opcional. Devuelve el token (se muestra una vez). */
  createToken(username: string, opts: TokenOptions): string {
    const user = this.users.get(username);
    if (!user) throw new Error(`User "${username}" not found`);
    const days = opts.expiresDays ?? DEFAULT_DAYS;
    const max = maxDays();
    if (!Number.isInteger(days) || days < 1 || days > max) {
      throw new Error(`La caducidad debe estar entre 1 y ${max} días (SAVIA_VAULTS_PAT_MAX_DAYS)`);
    }
    if (opts.domes && !opts.domes.length) throw new Error('domes vacío: omitirlo para no restringir por cúpula');
    const token = generateToken();
    const now = Date.now();
    user.credentials.push({
      id: `c_${crypto.randomBytes(8).toString('hex')}`,
      name: opts.name,
      prefix: token.slice(0, 6),
      hash: hashToken(token),
      createdAt: new Date(now).toISOString(),
      expiresAt: new Date(now + days * DAY_MS).toISOString(),
      ...(opts.domes ? { domes: [...opts.domes] } : {}),
      ...(opts.maxRole ? { maxRole: opts.maxRole } : {}),
    });
    return token;
  }

  /** Credenciales de un usuario, sin secretos. */
  listTokens(username: string): CredentialInfo[] {
    const user = this.users.get(username);
    if (!user) throw new Error(`User "${username}" not found`);
    return user.credentials.map(({ hash: _h, prefix: _p, ...info }) => ({ ...info }));
  }

  revokeToken(username: string, credentialId: string): void {
    const user = this.users.get(username);
    if (!user) throw new Error(`User "${username}" not found`);
    const c = user.credentials.find((x) => x.id === credentialId);
    if (!c) throw new Error(`Credencial "${credentialId}" no encontrada para "${username}"`);
    c.revokedAt ??= new Date().toISOString();
  }

  /** SE-423: usuario y credencial de un token, si es válido (ni caducado ni revocado). */
  validateCredential(token: string): { user: User; credential: Credential } | null {
    if (!token || !token.startsWith('sv_')) return null;
    const now = Date.now();
    const key = crypto.createHash('sha256').update(token).digest('hex');
    const hit = this.validated.get(key);
    if (hit && hit.until > now) {
      const user = this.users.get(hit.username);
      const credential = user && this.activeCredential(hit.username, hit.credentialId);
      if (user && credential) return { user, credential };
    }
    this.validated.delete(key);
    const prefix = token.slice(0, 6);
    for (const user of this.users.values()) {
      for (const c of user.credentials) {
        if (c.prefix !== prefix || !isActive(c, now)) continue;
        if (compareSync(token, c.hash)) {
          this.validated.set(key, { username: user.username, credentialId: c.id, until: Math.min(now + CACHE_MS, Date.parse(c.expiresAt)) });
          return { user, credential: c };
        }
      }
    }
    return null;
  }

  validateToken(token: string): User | null {
    return this.validateCredential(token)?.user ?? null;
  }

  /** Credencial vigente de un usuario por id (vía HTTP tras la caché de tokens). */
  activeCredential(username: string, credentialId: string): Credential | undefined {
    const c = this.users.get(username)?.credentials.find((x) => x.id === credentialId);
    return c && isActive(c) ? c : undefined;
  }

  /** SE-422: recarga el fichero si cambió en disco (revocaciones sin reiniciar el servidor). true si recargó. */
  reloadIfChanged(): boolean {
    let key: string;
    try {
      const st = fs.statSync(this.filePath);
      key = `${st.mtimeMs}:${st.size}:${st.ino}`;
    } catch {
      key = 'missing';
    }
    if (key === this.loadedKey) return false;
    this.loadedKey = key;
    if (key === 'missing') { this.users.clear(); return true; }
    this.load();
    this.loadedKey = key;
    return true;
  }

  getUser(username: string): User | undefined {
    return this.users.get(username);
  }

  setPermission(username: string, dome: string, role: UserRole): void {
    const user = this.users.get(username);
    if (!user) throw new Error(`User "${username}" not found`);
    user.permissions[dome] = { dome, role };
  }

  removePermission(username: string, dome: string): void {
    const user = this.users.get(username);
    if (!user) throw new Error(`User "${username}" not found`);
    delete user.permissions[dome];
  }

  getPermissions(username: string): Record<string, { dome: string; role: UserRole }> {
    const user = this.users.get(username);
    if (!user) throw new Error(`User "${username}" not found`);
    return { ...user.permissions };
  }

  /** Revoca todas las credenciales vigentes del usuario y crea una nueva «principal». */
  regenerateToken(username: string): string {
    const user = this.users.get(username);
    if (!user) throw new Error(`User "${username}" not found`);
    const now = new Date().toISOString();
    for (const c of user.credentials) if (!c.revokedAt) c.revokedAt = now;
    return this.createToken(username, { name: 'principal' });
  }

  /** Usuarios sin secretos de credenciales. */
  listUsers(): Array<Omit<User, 'credentials'> & { credentials: CredentialInfo[] }> {
    return [...this.users.values()].map((u) => ({
      subjectId: u.subjectId,
      type: u.type,
      username: u.username,
      createdAt: u.createdAt,
      permissions: { ...u.permissions },
      credentials: this.listTokens(u.username),
      ...(u.formerNames?.length ? { formerNames: [...u.formerNames] } : {}),
    }));
  }
}

/** SE-423: usuario v1 → v2. El token existente pasa a ser su primera credencial (caduca a 365 días). */
function migrateV1(u: UserV1): User {
  const now = Date.now();
  return {
    subjectId: crypto.randomUUID(),
    type: 'human',
    username: u.username,
    createdAt: u.createdAt,
    permissions: u.permissions ?? {},
    credentials: [{
      id: `c_${crypto.randomBytes(8).toString('hex')}`,
      name: 'migrado',
      prefix: u.tokenPrefix,
      hash: u.tokenHash,
      createdAt: new Date(now).toISOString(),
      expiresAt: new Date(now + MIGRATED_DAYS * DAY_MS).toISOString(),
      migrated: true,
    }],
  };
}
