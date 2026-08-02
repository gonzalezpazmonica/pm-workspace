import type { UserStore } from './store.js';
import type { DomeRegistry } from '../registry/domes.js';
import type { UserRole } from './types.js';
import type { DomeInfo, ConfidentialityLevel } from '../registry/domes.js';

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

  constructor(userStore: UserStore, domeRegistry: DomeRegistry) {
    this.userStore = userStore;
    this.domeRegistry = domeRegistry;
  }

  get isActive(): boolean {
    return this.userStore.exists();
  }

  async authorize(params: {
    authToken?: string;
    dome: string;
    action: AuthAction;
  }): Promise<Authorization> {
    // Resolve dome
    const domeInfo = this.domeRegistry.get(params.dome);
    if (!domeInfo || !domeInfo.active) {
      throw new AuthError('dome_not_found', `Dome "${params.dome}" not found or inactive`);
    }

    // Auth not configured → deny (no legacy mode)
    if (!this.isActive) {
      throw new AuthError('unauthorized', 'No users configured. Create an admin user with: savia-vaults user create <name>');
    }

    // N1 domes allow read without token
    if (domeInfo.confidentiality === 'N1' && params.action === 'read') {
      return { username: 'anonymous', role: 'reader', dome: params.dome };
    }

    // Require token for everything else
    if (!params.authToken) {
      throw new AuthError('unauthorized', `Authentication required for "${params.dome}". Set SAVIA_AUTH_TOKEN in your MCP client config.`);
    }

    const user = this.userStore.validateToken(params.authToken);
    if (!user) {
      throw new AuthError('unauthorized', 'Invalid or expired token');
    }

    // Check dome permission
    const perm = user.permissions[params.dome];
    if (!perm) {
      throw new AuthError('forbidden', `User "${user.username}" has no access to dome "${params.dome}"`);
    }

    const userRole = perm.role;

    // Check action permission
    if (ROLE_LEVEL[userRole] < ACTION_LEVEL[params.action]) {
      throw new AuthError('forbidden', `User "${user.username}" is ${userRole} on "${params.dome}" — ${params.action} requires writer or admin`);
    }

    // Check confidentiality gate
    const minRole = params.action === 'read'
      ? CONFIDENTIALITY_READ_MIN[domeInfo.confidentiality]
      : CONFIDENTIALITY_WRITE_MIN[domeInfo.confidentiality];

    if (ROLE_LEVEL[userRole] < ROLE_LEVEL[minRole]) {
      throw new AuthError('forbidden', `Dome "${params.dome}" has confidentiality ${domeInfo.confidentiality} — ${params.action} requires ${minRole} (user is ${userRole})`);
    }

    return { username: user.username, role: userRole, dome: params.dome };
  }
}
