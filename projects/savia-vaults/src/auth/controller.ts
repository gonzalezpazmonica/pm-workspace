import type { UserStore } from './store.js';
import type { DomeRegistry } from '../registry/domes.js';
import type { UserRole } from './types.js';
import type { DomeInfo, ConfidentialityLevel } from '../registry/domes.js';
import type { AuditLogger } from './audit-logger.js';
import type { UserQuotaStore } from './quota-store.js';

export type AuthAction = 'read' | 'write' | 'admin';

export interface Authorization {
  username: string;
  role: UserRole;
  dome: string;
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

      const user = this.userStore.validateToken(params.authToken);
      if (!user) {
        reason = 'Invalid or expired token';
        throw new AuthError('unauthorized', reason);
      }

      username = user.username;

      const perm = user.permissions[params.dome];
      if (!perm) {
        reason = `User "${username}" has no access to dome "${params.dome}"`;
        throw new AuthError('forbidden', reason);
      }

      const userRole = perm.role;

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

      result = 'allowed';
      this.recordAudit(username, params.dome, params.action, result, undefined, params.tool);

      if (this.quotaStore && this.quotaStore.isActive()) {
        this.quotaStore.record(username);
      }

      return { username, role: userRole, dome: params.dome };
    } catch (e) {
      if (e instanceof AuthError) {
        this.recordAudit(username || 'anonymous', params.dome, params.action, 'denied', e.message, params.tool);
      }
      throw e;
    }
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
