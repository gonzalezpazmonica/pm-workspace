import { minRole as lowerRole, type UserStore } from './store.js';
import type { DomeRegistry } from '../registry/domes.js';
import type { Credential, UserRole } from './types.js';
import type { DomeInfo, ConfidentialityLevel } from '../registry/domes.js';
import type { AuditLogger } from './audit-logger.js';
import type { UserQuotaStore } from './quota-store.js';

export type AuthAction = 'read' | 'write' | 'admin';

export interface Authorization {
  username: string;
  role: UserRole;
  dome: string;
  /** SE-423: identidad estable y credencial usada (ausentes para el acceso anónimo N1). */
  subjectId?: string;
  credentialId?: string;
  /** SE-423 AC7: nombres anteriores del Subject (listas por documento con nombres antiguos). */
  aliases?: string[];
}

export class AuthError extends Error {
  code: 'unauthorized' | 'forbidden' | 'dome_not_found';

  constructor(code: 'unauthorized' | 'forbidden' | 'dome_not_found', message: string) {
    super(message);
    this.code = code;
    this.name = 'AuthError';
  }
}

const ROLE_LEVEL: Record<UserRole, number> = { reader: 1, writer: 2, admin: 3 };
const ACTION_LEVEL: Record<AuthAction, number> = { read: 1, write: 2, admin: 3 };

const CONFIDENTIALITY_READ_MIN: Record<ConfidentialityLevel, UserRole> = {
  N1: 'reader',
  N2: 'reader',
  N3: 'writer',
  N4: 'admin',
};

const CONFIDENTIALITY_WRITE_MIN: Record<ConfidentialityLevel, UserRole> = {
  N1: 'writer',
  N2: 'writer',
  N3: 'writer',
  N4: 'admin',
};

export class AccessController {
  private userStore: UserStore;
  private domeRegistry: DomeRegistry;
  private auditLogger: AuditLogger | undefined;
  private quotaStore: UserQuotaStore | undefined;

  constructor(
    userStore: UserStore,
    domeRegistry: DomeRegistry,
    auditLogger?: AuditLogger,
    quotaStore?: UserQuotaStore,
  ) {
    this.userStore = userStore;
    this.domeRegistry = domeRegistry;
    this.auditLogger = auditLogger;
    this.quotaStore = quotaStore;
  }

  get isActive(): boolean {
    return this.userStore.exists();
  }

  /** SE-423: recarga el fichero de usuarios si cambió (revocaciones en caliente en todas las vías). */
  /** SE-423 AC7: nombre ↔ subjectId para las listas por documento (solo con usuarios). */
  get subjects(): { idOf(n: string): string | undefined; nameOf(id: string): string | undefined } {
    return {
      idOf: (n) => (this.isActive ? this.userStore.subjectOf(n) : undefined),
      nameOf: (id) => (this.isActive ? this.userStore.nameOf(id) : undefined),
    };
  }

  reloadUsers(): boolean {
    return this.userStore.reloadIfChanged();
  }

  /** SE-423: identidad de un token sin cúpula concreta (listados). Caducado o revocado ⇒ unauthorized. */
  identify(authToken?: string): { username: string; subjectId: string; credentialId: string } {
    const found = authToken ? this.userStore.validateCredential(authToken) : null;
    if (!found) throw new AuthError('unauthorized', 'Invalid or expired token');
    return { username: found.user.username, subjectId: found.user.subjectId, credentialId: found.credential.id };
  }

  async authorize(params: {
    authToken?: string;
    dome: string;
    action: AuthAction;
    tool?: string;
  }): Promise<Authorization> {
    let username: string | undefined;
    let result: 'allowed' | 'denied' = 'denied';
    let reason: string | undefined;

    try {
      const domeInfo = this.domeRegistry.get(params.dome);
      if (!domeInfo || !domeInfo.active) {
        reason = `Dome "${params.dome}" not found or inactive`;
        throw new AuthError('dome_not_found', reason);
      }

      if (!this.isActive) {
        reason = 'No users configured. Create an admin user with: savia-vaults user create <name>';
        throw new AuthError('unauthorized', reason);
      }

      if (domeInfo.confidentiality === 'N1' && params.action === 'read') {
        username = 'anonymous';
        result = 'allowed';
        this.recordAudit(username, params.dome, params.action, result, undefined, params.tool);
        return { username, role: 'reader', dome: params.dome };
      }

      if (!params.authToken) {
        reason = `Authentication required for "${params.dome}". Set SAVIA_AUTH_TOKEN in your MCP client config.`;
        throw new AuthError('unauthorized', reason);
      }

      const found = this.userStore.validateCredential(params.authToken);
      if (!found) {
        reason = 'Invalid or expired token';
        throw new AuthError('unauthorized', reason);
      }
      username = found.user.username;
      return this.checkUser(found.user, domeInfo, params, found.credential);
    } catch (e) {
      if (e instanceof AuthError) {
        this.recordAudit(username || 'anonymous', params.dome, params.action, 'denied', e.message, params.tool);
      }
      throw e;
    }
  }

  /**
   * SE-422: autoriza a un usuario ya identificado por otra vía (token acotado firmado por el
   * servidor HTTP). Se revalida contra el fichero de usuarios: revocar al usuario invalida sus tokens.
   */
  async authorizeUser(params: { username: string; credentialId?: string; dome: string; action: AuthAction; tool?: string }): Promise<Authorization> {
    try {
      const domeInfo = this.domeRegistry.get(params.dome);
      if (!domeInfo || !domeInfo.active) throw new AuthError('dome_not_found', `Dome "${params.dome}" not found or inactive`);
      if (!this.isActive) throw new AuthError('unauthorized', 'No users configured');
      const user = this.userStore.getUser(params.username);
      if (!user) throw new AuthError('unauthorized', `User "${params.username}" no longer exists`);
      // SE-423: la credencial con la que se identificó sigue vigente (revocar o caducar corta el acceso).
      let credential: Credential | undefined;
      if (params.credentialId) {
        credential = this.userStore.activeCredential(params.username, params.credentialId);
        if (!credential) throw new AuthError('unauthorized', 'Credencial revocada o caducada');
      }
      return this.checkUser(user, domeInfo, params, credential);
    } catch (e) {
      if (e instanceof AuthError) this.recordAudit(params.username, params.dome, params.action, 'denied', e.message, params.tool);
      throw e;
    }
  }

  private checkUser(
    user: { username: string; subjectId?: string; formerNames?: string[]; permissions: Record<string, { role: UserRole }> },
    domeInfo: DomeInfo, params: { dome: string; action: AuthAction; tool?: string }, credential?: Credential,
  ): Authorization {
    let reason: string | undefined;
    const username = user.username;
    const perm = user.permissions[params.dome];
    if (!perm) {
      reason = `User "${username}" has no access to dome "${params.dome}"`;
      throw new AuthError('forbidden', reason);
    }
    // SE-423: el alcance de la credencial solo restringe (cúpulas y rol máximo).
    if (credential?.domes && !credential.domes.includes(params.dome)) {
      reason = `La credencial "${credential.name}" de "${username}" no da acceso a la cúpula "${params.dome}"`;
      throw new AuthError('forbidden', reason);
    }

    const userRole = lowerRole(perm.role, credential?.maxRole);

    if (ROLE_LEVEL[userRole] < ACTION_LEVEL[params.action]) {
      reason = `User "${username}" is ${userRole} on "${params.dome}" — ${params.action} requires writer or admin`;
      throw new AuthError('forbidden', reason);
    }

    const minRole = params.action === 'read'
      ? CONFIDENTIALITY_READ_MIN[domeInfo.confidentiality]
      : CONFIDENTIALITY_WRITE_MIN[domeInfo.confidentiality];

    if (ROLE_LEVEL[userRole] < ROLE_LEVEL[minRole]) {
      reason = `Dome "${params.dome}" has confidentiality ${domeInfo.confidentiality} — ${params.action} requires ${minRole} (user is ${userRole})`;
      throw new AuthError('forbidden', reason);
    }

    if (this.quotaStore && this.quotaStore.isActive()) {
      const quota = this.quotaStore.check(username);
      if (!quota.allowed) {
        reason = `Quota exceeded for "${username}"`;
        this.recordAudit(username, params.dome, params.action, 'denied', reason, params.tool);
        throw new AuthError('forbidden', reason);
      }
    }

    this.recordAudit(username, params.dome, params.action, 'allowed', undefined, params.tool);

    if (this.quotaStore && this.quotaStore.isActive()) {
      this.quotaStore.record(username);
    }

    return {
      username, role: userRole, dome: params.dome,
      ...(user.subjectId ? { subjectId: user.subjectId } : {}),
      ...(credential ? { credentialId: credential.id } : {}),
      ...(user.formerNames?.length ? { aliases: [...user.formerNames] } : {}),
    };
  }

  private recordAudit(
    username: string,
    dome: string,
    action: AuthAction,
    result: 'allowed' | 'denied',
    reason?: string,
    tool?: string,
  ): void {
    if (!this.auditLogger) return;
    this.auditLogger.record({ username, dome, action, result, reason, tool });
  }
}
