import * as fs from 'node:fs';
import * as path from 'node:path';
import * as crypto from 'node:crypto';
import { hashSync, compareSync } from 'bcryptjs';
import type { User, UserRole, UsersFile } from './types.js';

function generateToken(): string {
  const random = crypto.randomBytes(32).toString('base64url');
  return `sv_${random}`;
}

function hashToken(token: string): string {
  return hashSync(token, 12);
}

export class UserStore {
  private filePath: string;
  private users: Map<string, User> = new Map();

  constructor(filePath: string = 'savia-vaults.users.json') {
    this.filePath = filePath;
  }

  exists(): boolean {
    return fs.existsSync(this.filePath);
  }

  load(): void {
    if (!fs.existsSync(this.filePath)) return;
    const raw = fs.readFileSync(this.filePath, 'utf-8');
    const data: UsersFile = JSON.parse(raw);

    this.users.clear();
    for (const [username, user] of Object.entries(data.users)) {
      this.users.set(username, user);
    }
  }

  save(): void {
    const data: UsersFile = { version: 1, users: {} };
    for (const [username, user] of this.users) {
      data.users[username] = user;
    }
    const dir = path.dirname(this.filePath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(this.filePath, JSON.stringify(data, null, 2) + '\n');
  }

  createUser(username: string): string {
    if (this.users.has(username)) {
      throw new Error(`User "${username}" already exists`);
    }

    const token = generateToken();
    const tokenHash = hashToken(token);

    const user: User = {
      username,
      tokenHash,
      tokenPrefix: token.slice(0, 6),
      createdAt: new Date().toISOString(),
      permissions: {},
    };

    this.users.set(username, user);
    return token;
  }

  deleteUser(username: string): void {
    if (!this.users.has(username)) {
      throw new Error(`User "${username}" not found`);
    }
    this.users.delete(username);
  }

  validateToken(token: string): User | null {
    if (!token || !token.startsWith('sv_')) return null;
    const prefix = token.slice(0, 6);
    for (const user of this.users.values()) {
      if (user.tokenPrefix === prefix) {
        if (compareSync(token, user.tokenHash)) {
          return user;
        }
      }
    }
    return null;
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

  regenerateToken(username: string): string {
    const user = this.users.get(username);
    if (!user) throw new Error(`User "${username}" not found`);

    const token = generateToken();
    user.tokenHash = hashToken(token);
    user.tokenPrefix = token.slice(0, 6);
    return token;
  }

  listUsers(): User[] {
    return [...this.users.values()].map(u => ({
      username: u.username,
      tokenHash: u.tokenHash,
      tokenPrefix: u.tokenPrefix,
      createdAt: u.createdAt,
      permissions: { ...u.permissions },
    }));
  }
}
