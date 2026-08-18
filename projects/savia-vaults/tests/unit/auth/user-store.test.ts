import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { UserStore } from '../../../src/auth/store.js';

describe('UserStore', () => {
  let tmpDir: string;
  let usersFile: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'vaults-users-'));
    usersFile = path.join(tmpDir, 'users.json');
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('creates user and returns token', () => {
    const store = new UserStore(usersFile);
    const token = store.createUser('alice');
    expect(token).toMatch(/^sv_/);
    expect(token.length).toBeGreaterThan(20);
    store.save();

    const store2 = new UserStore(usersFile);
    store2.load();
    const user = store2.getUser('alice');
    expect(user).toBeDefined();
    expect(user!.username).toBe('alice');
    expect(user!.tokenHash).not.toBe(token);
  });

  it('validates correct token', () => {
    const store = new UserStore(usersFile);
    const token = store.createUser('bob');
    store.save();
    store.load();

    const validated = store.validateToken(token);
    expect(validated).not.toBeNull();
    expect(validated!.username).toBe('bob');
  });

  it('rejects invalid token', () => {
    const store = new UserStore(usersFile);
    store.createUser('bob');
    store.save();

    expect(store.validateToken('sv_invalidtoken123')).toBeNull();
    expect(store.validateToken('not_a_token')).toBeNull();
    expect(store.validateToken('')).toBeNull();
  });

  it('sets and retrieves permissions', () => {
    const store = new UserStore(usersFile);
    store.createUser('alice');
    store.setPermission('alice', 'example-context', 'writer');
    store.setPermission('alice', 'Labs', 'reader');
    store.save();

    const store2 = new UserStore(usersFile);
    store2.load();
    const perms = store2.getPermissions('alice');
    expect(perms['example-context'].role).toBe('writer');
    expect(perms['Labs'].role).toBe('reader');
  });

  it('removes permission', () => {
    const store = new UserStore(usersFile);
    store.createUser('alice');
    store.setPermission('alice', 'example-context', 'admin');
    store.removePermission('alice', 'example-context');
    store.save();

    const store2 = new UserStore(usersFile);
    store2.load();
    const perms = store2.getPermissions('alice');
    expect(Object.keys(perms)).toHaveLength(0);
  });

  it('regenerates token and invalidates old one', () => {
    const store = new UserStore(usersFile);
    const oldToken = store.createUser('alice');
    store.save();

    const newToken = store.regenerateToken('alice');
    expect(newToken).not.toBe(oldToken);
    expect(newToken).toMatch(/^sv_/);
    store.save();

    store.load();
    expect(store.validateToken(oldToken)).toBeNull();
    expect(store.validateToken(newToken)!.username).toBe('alice');
  });

  it('throws on duplicate username', () => {
    const store = new UserStore(usersFile);
    store.createUser('alice');
    expect(() => store.createUser('alice')).toThrow('already exists');
  });

  it('throws on nonexistent user operations', () => {
    const store = new UserStore(usersFile);
    expect(() => store.getPermissions('ghost')).toThrow('not found');
    expect(() => store.setPermission('ghost', 'D', 'reader')).toThrow('not found');
    expect(() => store.regenerateToken('ghost')).toThrow('not found');
  });

  it('deletes user', () => {
    const store = new UserStore(usersFile);
    store.createUser('alice');
    store.deleteUser('alice');
    store.save();

    const store2 = new UserStore(usersFile);
    store2.load();
    expect(store2.getUser('alice')).toBeUndefined();
  });

  it('lists all users', () => {
    const store = new UserStore(usersFile);
    store.createUser('a');
    store.createUser('b');
    store.createUser('c');
    const users = store.listUsers();
    expect(users).toHaveLength(3);
    expect(users.map(u => u.username).sort()).toEqual(['a', 'b', 'c']);
  });

  it('exists() returns false when file missing', () => {
    const store = new UserStore(usersFile);
    expect(store.exists()).toBe(false);
    store.createUser('x');
    store.save();
    expect(store.exists()).toBe(true);
  });
});
