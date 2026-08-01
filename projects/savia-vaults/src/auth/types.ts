export type UserRole = 'admin' | 'writer' | 'reader';

export interface DomePermission {
  dome: string;
  role: UserRole;
}

export interface User {
  username: string;
  tokenHash: string;
  tokenPrefix: string;
  createdAt: string;
  permissions: Record<string, DomePermission>;
}

export interface UsersFile {
  version: number;
  users: Record<string, User>;
}
