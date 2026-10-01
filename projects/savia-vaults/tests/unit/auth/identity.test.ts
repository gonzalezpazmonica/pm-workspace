// SE-423 PR 1 — identidad mínima: Subject estable, varias credenciales (PAT) con caducidad,
// alcance (cúpulas y rol máximo) y revocación individual; migración del formato v1; fichero 0600.
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { hashSync } from 'bcryptjs';
import { UserStore } from '../../../src/auth/store.js';
import { AccessController, AuthError } from '../../../src/auth/controller.js';
import { DomeRegistry } from '../../../src/registry/domes.js';

const DAY = 86_400_000;
const mode = (f: string) => fs.statSync(f).mode & 0o777;

describe('SE-423 identidad mínima (PR 1)', () => {
  let dir: string;
  let file: string;
  const savedMax = process.env.SAVIA_VAULTS_PAT_MAX_DAYS;

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-identity-'));
    file = path.join(dir, 'savia-vaults.users.json');
  });
  afterEach(() => {
    if (savedMax === undefined) delete process.env.SAVIA_VAULTS_PAT_MAX_DAYS; else process.env.SAVIA_VAULTS_PAT_MAX_DAYS = savedMax;
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('crear usuario: Subject estable, una credencial de 90 días y fichero v2 en 0600 sin temporales', () => {
    const s = new UserStore(file);
    const token = s.createUser('eva');
    s.save();
    const u = s.getUser('eva')!;
    expect(u.subjectId).toMatch(/^[0-9a-f-]{36}$/);
    expect(u.type).toBe('human');
    expect(u.credentials).toHaveLength(1);
    const c = u.credentials[0];
    expect(Date.parse(c.expiresAt) - Date.now()).toBeGreaterThan(89 * DAY);
    expect(Date.parse(c.expiresAt) - Date.now()).toBeLessThan(91 * DAY);
    expect(s.validateCredential(token)).toMatchObject({ user: { username: 'eva' }, credential: { id: c.id } });
    expect(JSON.parse(fs.readFileSync(file, 'utf-8')).version).toBe(2);
    expect(mode(file)).toBe(0o600);
    expect(fs.readdirSync(dir).filter((f) => f.includes('.tmp'))).toEqual([]);
    const again = new UserStore(file);
    again.load();
    expect(again.getUser('eva')!.subjectId).toBe(u.subjectId);
  });

  it('un fichero existente con permisos abiertos pasa a 0600 al guardar', () => {
    fs.writeFileSync(file, JSON.stringify({ version: 2, users: {} }), { mode: 0o664 });
    fs.chmodSync(file, 0o664);
    const s = new UserStore(file);
    s.load();
    s.createUser('eva');
    s.save();
    expect(mode(file)).toBe(0o600);
  });

  it('varias credenciales con alcance; list sin secretos; revocar una no afecta a las demás', () => {
    const s = new UserStore(file);
    const t1 = s.createUser('eva');
    const t2 = s.createToken('eva', { name: 'portátil', expiresDays: 30, domes: ['A'], maxRole: 'reader' });
    const list = s.listTokens('eva');
    expect(list).toHaveLength(2);
    expect(JSON.stringify(list)).not.toMatch(/hash|\$2[aby]\$/);
    const portatil = list.find((c) => c.name === 'portátil')!;
    expect(portatil).toMatchObject({ domes: ['A'], maxRole: 'reader' });
    s.revokeToken('eva', portatil.id);
    expect(s.validateCredential(t2)).toBeNull();
    expect(s.validateCredential(t1)).not.toBeNull();
    expect(s.listTokens('eva').find((c) => c.id === portatil.id)!.revokedAt).toBeDefined();
  });

  it('caducidad: una credencial caducada no valida; el máximo de días es configurable', () => {
    const s = new UserStore(file);
    s.createUser('eva');
    const t = s.createToken('eva', { name: 'corta', expiresDays: 1 });
    const id = s.listTokens('eva').find((c) => c.name === 'corta')!.id;
    s.getUser('eva')!.credentials.find((c) => c.id === id)!.expiresAt = new Date(Date.now() - 1000).toISOString();
    expect(s.validateCredential(t)).toBeNull();
    expect(s.validateToken(t)).toBeNull();
    expect(() => s.createToken('eva', { name: 'larga', expiresDays: 366 })).toThrow(/365/);
    process.env.SAVIA_VAULTS_PAT_MAX_DAYS = '30';
    expect(() => s.createToken('eva', { name: 'media', expiresDays: 31 })).toThrow(/30/);
    expect(() => s.createToken('eva', { name: 'ok', expiresDays: 30 })).not.toThrow();
  });

  it('regenerar el token revoca las credenciales anteriores del usuario', () => {
    const s = new UserStore(file);
    const t1 = s.createUser('eva');
    const t2 = s.createToken('eva', { name: 'otra', expiresDays: 10 });
    const t3 = s.regenerateToken('eva');
    expect(s.validateCredential(t1)).toBeNull();
    expect(s.validateCredential(t2)).toBeNull();
    expect(s.validateCredential(t3)).not.toBeNull();
  });

  it('migración v1: el token sigue valiendo con caducidad a 365 días, copia .v1.bak 0600, idempotente', () => {
    const token = 'sv_' + 'x'.repeat(43);
    const v1 = { version: 1, users: { ana: {
      username: 'ana', tokenHash: hashSync(token, 4), tokenPrefix: token.slice(0, 6), createdAt: '2026-01-01T00:00:00.000Z',
      permissions: { A: { dome: 'A', role: 'writer' } },
    } } };
    fs.writeFileSync(file, JSON.stringify(v1), { mode: 0o644 });
    const s = new UserStore(file);
    s.load();
    const r = s.validateCredential(token)!;
    expect(r.user).toMatchObject({ username: 'ana', permissions: { A: { role: 'writer' } } });
    expect(r.credential).toMatchObject({ migrated: true });
    expect(Date.parse(r.credential.expiresAt) - Date.now()).toBeGreaterThan(364 * DAY);
    const disk = JSON.parse(fs.readFileSync(file, 'utf-8'));
    expect(disk.version).toBe(2);
    expect(disk.users.ana.tokenHash).toBeUndefined();
    expect(mode(file)).toBe(0o600);
    expect(JSON.parse(fs.readFileSync(`${file}.v1.bak`, 'utf-8'))).toEqual(v1);
    expect(mode(`${file}.v1.bak`)).toBe(0o600);
    // Segunda carga: mismo Subject y misma caducidad
    const s2 = new UserStore(file);
    s2.load();
    const r2 = s2.validateCredential(token)!;
    expect(r2.user.subjectId).toBe(r.user.subjectId);
    expect(r2.credential.expiresAt).toBe(r.credential.expiresAt);
  });

  describe('AccessController con credenciales', () => {
    const domes = () => {
      const f = path.join(dir, 'domes.json');
      for (const d of ['A', 'B']) fs.mkdirSync(path.join(dir, d), { recursive: true });
      fs.writeFileSync(f, JSON.stringify({ version: 1, defaultDome: 'A', domes: {
        A: { name: 'A', path: path.join(dir, 'A'), description: '', confidentiality: 'N2' },
        B: { name: 'B', path: path.join(dir, 'B'), description: '', confidentiality: 'N2' },
      } }));
      const reg = new DomeRegistry(f);
      reg.load();
      return reg;
    };

    it('AC4: el alcance de la credencial solo restringe (cúpulas y rol máximo), aunque el Subject sea admin', async () => {
      const s = new UserStore(file);
      s.createUser('eva');
      s.setPermission('eva', 'A', 'admin');
      s.setPermission('eva', 'B', 'admin');
      const t = s.createToken('eva', { name: 'lectura-A', expiresDays: 5, domes: ['A'], maxRole: 'reader' });
      s.save();
      const ac = new AccessController(s, domes());
      const ok = await ac.authorize({ authToken: t, dome: 'A', action: 'read' });
      expect(ok).toMatchObject({ username: 'eva', role: 'reader', subjectId: s.getUser('eva')!.subjectId });
      expect(ok.credentialId).toMatch(/^c_/);
      await expect(ac.authorize({ authToken: t, dome: 'A', action: 'write' })).rejects.toThrow(AuthError);
      await expect(ac.authorize({ authToken: t, dome: 'B', action: 'read' })).rejects.toThrow(/credencial|credential/i);
    });

    it('AC1: caducada o revocada ⇒ unauthorized; authorizeUser con credentialId (vía HTTP) también', async () => {
      const s = new UserStore(file);
      const t = s.createUser('eva');
      s.setPermission('eva', 'A', 'writer');
      s.save();
      const ac = new AccessController(s, domes());
      const ok = await ac.authorize({ authToken: t, dome: 'A', action: 'read' });
      await expect(ac.authorizeUser({ username: 'eva', credentialId: ok.credentialId, dome: 'A', action: 'read' })).resolves.toMatchObject({ role: 'writer' });
      s.revokeToken('eva', ok.credentialId!);
      await expect(ac.authorize({ authToken: t, dome: 'A', action: 'read' })).rejects.toThrow(/Invalid or expired token/);
      await expect(ac.authorizeUser({ username: 'eva', credentialId: ok.credentialId, dome: 'A', action: 'read' })).rejects.toThrow(/revocada|caducada/);
    });
  });
});

describe('SE-423 AC9: caché de credenciales validadas', () => {
  it('la segunda validación del mismo token no repite bcrypt (< 1 ms) y una revocación la invalida al momento', () => {
    const dir2 = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-identity-cache-'));
    try {
      const s = new UserStore(path.join(dir2, 'u.json'));
      const t = s.createUser('eva');
      const t0 = performance.now();
      expect(s.validateCredential(t)).not.toBeNull();
      const cold = performance.now() - t0;
      const t1 = performance.now();
      for (let i = 0; i < 100; i++) s.validateCredential(t);
      const warm = (performance.now() - t1) / 100;
      expect(warm).toBeLessThan(1);
      expect(cold).toBeGreaterThan(warm * 10);
      s.revokeToken('eva', s.listTokens('eva')[0].id);
      expect(s.validateCredential(t)).toBeNull();
      expect(s.validateCredential('sv_' + 'z'.repeat(43))).toBeNull();
    } finally {
      fs.rmSync(dir2, { recursive: true, force: true });
    }
  });
});
