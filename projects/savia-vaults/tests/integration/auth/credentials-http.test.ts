// SE-423 PR 1 — credenciales en la API HTTP real: alcance por cúpula y rol, y revocación y
// caducidad aplicadas en la siguiente petición sin reiniciar el servidor (también tras la caché).
import { describe, it, expect, beforeAll, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { DomeRegistry } from '../../../src/registry/domes.js';
import { UserStore } from '../../../src/auth/store.js';
import { AccessController } from '../../../src/auth/controller.js';
import { FilesHttpServer } from '../../../src/server/http.js';
import { Journal } from '../../../src/files/journal.js';
import { sodiumReady } from '../../../src/files/crypto.js';

describe('SE-423 credenciales en la API HTTP', () => {
  let root: string;
  let server: FilesHttpServer;
  let url: string;
  let usersFile: string;
  let full: string;
  let scoped: string;

  const get = (p: string, token: string) => fetch(`${url}${p}`, { headers: { Authorization: `Bearer ${token}` } });
  const edit = (fn: (s: UserStore) => void) => {
    const s = new UserStore(usersFile);
    s.load();
    fn(s);
    s.save();
  };

  beforeAll(async () => { await sodiumReady(); });
  beforeEach(async () => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-cred-http-'));
    for (const d of ['A', 'B']) fs.mkdirSync(path.join(root, d));
    fs.writeFileSync(path.join(root, 'domes.json'), JSON.stringify({ version: 1, defaultDome: 'A', domes: {
      A: { name: 'A', path: path.join(root, 'A'), description: '', confidentiality: 'N2', files: { enabled: true, scan: 'off' } },
      B: { name: 'B', path: path.join(root, 'B'), description: '', confidentiality: 'N2', files: { enabled: true, scan: 'off' } },
    } }));
    const reg = new DomeRegistry(path.join(root, 'domes.json'));
    reg.load();
    usersFile = path.join(root, 'users.json');
    const users = new UserStore(usersFile);
    full = users.createUser('eva');
    users.setPermission('eva', 'A', 'admin');
    users.setPermission('eva', 'B', 'admin');
    scoped = users.createToken('eva', { name: 'solo-A-lectura', expiresDays: 7, domes: ['A'], maxRole: 'reader' });
    users.save();
    const env = { SAVIA_FILES_HOME: path.join(root, 'files'), SAVIA_FILES_KEYS_HOME: path.join(root, 'keys'), HOME: root, PATH: process.env.PATH };
    server = new FilesHttpServer({ domes: reg, users, access: new AccessController(users, reg), env, host: '127.0.0.1', port: 0 });
    url = (await server.start()).url;
  });
  afterEach(async () => { await server.stop(); Journal.closeAll(); fs.rmSync(root, { recursive: true, force: true }); });

  it('AC4: la credencial restringida lee A, no escribe en A y no ve B; la completa ve ambas', async () => {
    expect((await get('/v1/files/A/documents', scoped)).status).toBe(200);
    expect((await get('/v1/files/B/documents', scoped)).status).toBe(403);
    const create = await fetch(`${url}/v1/files/A/uploads`, { method: 'POST', headers: {
      Authorization: `Bearer ${scoped}`, 'Tus-Resumable': '1.0.0', 'Upload-Length': '3', 'Upload-Metadata': `filename ${Buffer.from('a.txt').toString('base64')}`,
    } });
    expect(create.status).toBe(403);
    expect((await get('/v1/files/B/documents', full)).status).toBe(200);
  });

  it('AC1: revocar o caducar una credencial vale en la siguiente petición, aunque estuviera en caché', async () => {
    expect((await get('/v1/files/A/documents', scoped)).status).toBe(200); // queda en la caché de tokens
    const id = new UserStore(usersFile);
    id.load();
    const scopedId = id.listTokens('eva').find((c) => c.name === 'solo-A-lectura')!.id;
    edit((s) => s.revokeToken('eva', scopedId));
    expect((await get('/v1/files/A/documents', scoped)).status).toBe(401);
    expect((await get('/v1/files/A/documents', full)).status).toBe(200);
    // Caducidad: la credencial principal pasa a caducada en disco
    edit((s) => { s.getUser('eva')!.credentials.find((c) => c.name === 'principal')!.expiresAt = new Date(Date.now() - 1000).toISOString(); });
    expect((await get('/v1/files/A/documents', full)).status).toBe(401);
  });
});
