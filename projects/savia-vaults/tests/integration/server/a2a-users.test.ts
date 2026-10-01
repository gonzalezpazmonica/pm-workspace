// SE-423 PR 2 — A2A por usuario: con fichero de usuarios, cada petición lleva un token personal
// y pasa por el mismo AccessController que MCP y HTTP (permiso de cúpula, alcance de la credencial,
// revocación en caliente). SAVIA_VAULTS_TOKEN (secreto compartido) queda solo en loopback (D2).
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { A2AServer } from '../../../src/server/a2a.js';
import { DomeRegistry } from '../../../src/registry/domes.js';
import { UserStore } from '../../../src/auth/store.js';
import { AccessController } from '../../../src/auth/controller.js';
import type { VaultConfig } from '../../../src/types.js';

const NON_LOOPBACK = '192.0.2.1'; // TEST-NET-1: nunca asignada; si la guarda dejara pasar, listen fallaría

describe('SE-423 A2A con usuarios', () => {
  let tmp: string;
  let reg: DomeRegistry;
  let users: UserStore;
  let usersFile: string;
  let servers: A2AServer[];
  let reader: string;
  let writer: string;

  const make = (shared?: string) => {
    const config: VaultConfig = { name: 'vault', path: path.join(tmp, 'vault'), allowedExtensions: [], deniedPaths: [], maxDepth: 10, maxFileSize: 1024 * 1024 };
    const s = new A2AServer(config, reg, { access: new AccessController(users, reg) });
    servers.push(s);
    return { s, shared };
  };
  const get = (url: string, token?: string) => fetch(url, token ? { headers: { Authorization: `Bearer ${token}` } } : {});

  beforeEach(() => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-a2a-users-'));
    servers = [];
    for (const d of ['A', 'B']) {
      fs.mkdirSync(path.join(tmp, d));
      fs.writeFileSync(path.join(tmp, d, 'nota.md'), `# ${d}\npalabra-comun contenido-${d}\n`);
    }
    fs.writeFileSync(path.join(tmp, 'domes.json'), JSON.stringify({ version: 1, defaultDome: 'A', domes: {
      A: { name: 'A', path: path.join(tmp, 'A'), description: '', confidentiality: 'N2' },
      B: { name: 'B', path: path.join(tmp, 'B'), description: '', confidentiality: 'N2' },
    } }));
    reg = new DomeRegistry(path.join(tmp, 'domes.json'));
    reg.load();
    usersFile = path.join(tmp, 'users.json');
    users = new UserStore(usersFile);
    reader = users.createUser('luis');
    users.setPermission('luis', 'A', 'reader');
    writer = users.createUser('eva');
    users.setPermission('eva', 'A', 'writer');
    users.setPermission('eva', 'B', 'writer');
    users.save();
  });
  afterEach(async () => {
    for (const s of servers) await s.stop();
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  it('AC5: sin token ⇒ 401; un lector de A no ve B en /domes, búsqueda ni lectura, y no escribe', async () => {
    const { url } = await make().s.start(0, '127.0.0.1');
    expect((await get(`${url}/domes`)).status).toBe(401);
    const domes = await (await get(`${url}/domes`, reader)).json();
    expect(domes.domes.map((d: { name: string }) => d.name)).toEqual(['A']);
    expect(JSON.stringify(domes)).not.toContain(tmp);
    const all = await (await get(`${url}/search?q=palabra-comun`, reader)).json();
    expect(all.results.map((r: { dome: string }) => r.dome)).toEqual(['A']);
    expect((await get(`${url}/search?q=contenido-B&dome=B`, reader)).status).toBe(403);
    expect((await get(`${url}/context/note/nota.md?dome=B`, reader)).status).toBe(403);
    expect((await get(`${url}/context/note/nota.md?dome=A`, reader)).status).toBe(200);
    expect((await get(`${url}/context/note/nota.md`, reader)).status).toBe(400); // sin cúpula explícita
    const share = (token: string, dome: string) => fetch(`${url}/share`, { method: 'POST', headers: { Authorization: `Bearer ${token}` }, body: JSON.stringify({ dome, path: 'x.md', content: 'x' }) });
    expect((await share(reader, 'A')).status).toBe(403);
    expect((await share(writer, 'A')).status).toBe(200);
  });

  it('AC1/AC4: credencial revocada ⇒ 401 en la siguiente petición; el alcance de la credencial restringe', async () => {
    const { url } = await make().s.start(0, '127.0.0.1');
    expect((await get(`${url}/domes`, writer)).status).toBe(200);
    const scoped = users.createToken('eva', { name: 'solo-A', expiresDays: 3, domes: ['A'] });
    users.save();
    const d = await (await get(`${url}/domes`, scoped)).json();
    expect(d.domes.map((x: { name: string }) => x.name)).toEqual(['A']);
    const disk = new UserStore(usersFile);
    disk.load();
    disk.revokeToken('eva', disk.listTokens('eva').find((c) => c.name === 'principal')!.id);
    disk.save();
    expect((await get(`${url}/domes`, writer)).status).toBe(401);
    expect((await get(`${url}/domes`, scoped)).status).toBe(200);
    // Arrancó con usuarios: sin el fichero no pasa a modo público.
    fs.renameSync(usersFile, `${usersFile}.fuera`);
    expect((await get(`${url}/domes`)).status).toBe(401);
    expect((await get(`${url}/search?q=palabra-comun&dome=A`)).status).toBe(401);
  });

  it('D2: SAVIA_VAULTS_TOKEN solo en loopback; fuera de loopback A2A exige usuarios', async () => {
    const shared = 's'.repeat(40);
    const local = await make().s.start(0, '127.0.0.1', shared);
    expect((await get(`${local.url}/domes`, shared)).status).toBe(200); // compatibilidad, con aviso
    // Con usuarios, fuera de loopback la guarda deja pasar (el error es del sistema, no de la guarda)
    await expect(make().s.start(0, NON_LOOPBACK)).rejects.toThrow(/EADDRNOTAVAIL|address/i);
    // Sin usuarios, ni el secreto compartido ni nada permite salir de loopback
    fs.rmSync(usersFile);
    await expect(make().s.start(0, NON_LOOPBACK, shared)).rejects.toThrow(/usuarios|SAVIA_VAULTS_TOKEN/);
    await expect(make().s.start(0, NON_LOOPBACK)).rejects.toThrow(/usuarios|SAVIA_VAULTS_TOKEN/);
  });
});
