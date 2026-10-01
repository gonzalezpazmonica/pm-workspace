export type UserRole = 'admin' | 'writer' | 'reader';

export interface DomePermission {
  dome: string;
  role: UserRole;
}

/**
 * SE-423: credencial personal (PAT) de un Subject. Caduca siempre; `domes` y `maxRole` solo
 * restringen lo que el Subject ya tiene. El secreto no se guarda: solo su hash bcrypt.
 */
export interface Credential {
  id: string;
  name: string;
  prefix: string;
  hash: string;
  createdAt: string;
  expiresAt: string;
  domes?: string[];
  maxRole?: UserRole;
  revokedAt?: string;
  /** Token v1 migrado (SE-423 D1: caduca a los 365 días de la migración). */
  migrated?: boolean;
}

/** Vista de una credencial sin secretos (listados, CLI). */
export type CredentialInfo = Omit<Credential, 'hash' | 'prefix'>;

export interface User {
  /** SE-423: identidad estable, independiente del nombre y de las credenciales. */
  subjectId: string;
  type: 'human' | 'service';
  username: string;
  createdAt: string;
  permissions: Record<string, DomePermission>;
  credentials: Credential[];
}

export interface UsersFile {
  version: number;
  users: Record<string, User>;
}

/** Formato v1 (antes de SE-423): un token por usuario, sin caducidad. */
export interface UserV1 {
  username: string;
  tokenHash: string;
  tokenPrefix: string;
  createdAt: string;
  permissions: Record<string, DomePermission>;
}
