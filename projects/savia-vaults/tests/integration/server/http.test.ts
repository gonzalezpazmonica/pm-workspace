// SE-422 — API HTTP de ficheros contra un servidor real en un puerto efímero: errores tus (AC2),
// autorización y autorizaciones acotadas (AC3), descargas con rangos/ETag (AC4), cifradas (AC5),
// arranque (AC6) y MCP upload/link (AC7).
import { describe, it, expect, beforeAll, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash, randomBytes } from 'node:crypto';
import { execFile, execFileSync } from 'node:child_process';
import { promisify } from 'node:util';
import { DomeRegistry } from '../../../src/registry/domes.js';
import { UserStore } from '../../../src/auth/store.js';
import { AccessController } from '../../../src/auth/controller.js';
import { FilesHttpServer } from '../../../src/server/http.js';
import { FilesService, callFilesTool } from '../../../src/files/service.js';
import { Journal } from '../../../src/files/journal.js';
import { sodiumReady } from '../../../src/files/crypto.js';

const b64 = (s: string) => Buffer.from(s).toString('base64');
const sha = (b: Buffer) => createHash('sha256').update(b).digest();

describe('SE-422 API HTTP de ficheros', () => {
  let root: string;
  let env: NodeJS.ProcessEnv;
  let server: FilesHttpServer;
  let url: string;
  let tokens: Record<string, string>;
  let reg: DomeRegistry;
  let access: AccessController;

  const req = (p: string, init: RequestInit & { token?: string } = {}) => fetch(`${url}${p}`, {
    ...init, headers: { ...(init.token ? { Authorization: `Bearer ${init.token}` } : {}), ...(init.headers as Record<string, string> ?? {}) },
  });
  const tusHeaders = (extra: Record<string, string> = {}) => ({ 'Tus-Resumable': '1.0.0', ...extra });
  const create = async (dome: string, token: string, length: number, name = 'a.bin', extra: Record<string, string> = {}) =>
    req(`/v1/files/${dome}/uploads`, { method: 'POST', token, headers: tusHeaders({ 'Upload-Length': String(length), 'Upload-Metadata': `filename ${b64(name)}`, ...extra }) });
  const patch = (loc: string, token: string, offset: number, body: Buffer, extra: Record<string, string> = {}) =>
    req(loc, { method: 'PATCH', token, body, headers: tusHeaders({ 'Upload-Offset': String(offset), 'Content-Type': 'application/offset+octet-stream', ...extra }) });
  const upload = async (dome: string, token: string, data: Buffer, name = 'a.bin') => {
    const c = await create(dome, token, data.length, name);
    expect(c.status, await c.clone().text()).toBe(201);
    const loc = c.headers.get('location')!;
    const p = await patch(loc, token, 0, data);
    expect(p.status, await p.clone().text()).toBe(204);
    return { loc, documentId: p.headers.get('savia-document-id')!, operationId: p.headers.get('savia-operation-id')! };
  };

  beforeAll(async () => { await sodiumReady(); });
  beforeEach(async () => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-http-'));
    env = { SAVIA_FILES_HOME: path.join(root, 'files'), SAVIA_FILES_KEYS_HOME: path.join(root, 'keys'), HOME: root, PATH: process.env.PATH, SAVIA_FILES_MAX_BYTES: String(5 * 1024 * 1024) };
    for (const d of ['P', 'S']) fs.mkdirSync(path.join(root, d));
    fs.writeFileSync(path.join(root, 'domes.json'), JSON.stringify({ version: 1, defaultDome: 'P', domes: {
      P: { name: 'P', path: path.join(root, 'P'), description: '', confidentiality: 'N2', files: { enabled: true, scan: 'off' } },
      S: { name: 'S', path: path.join(root, 'S'), description: '', confidentiality: 'N3', files: { enabled: true, scan: 'off' } },
    } }));
    reg = new DomeRegistry(path.join(root, 'domes.json'));
    reg.load();
    const users = new UserStore(path.join(root, 'users.json'));
    tokens = { eva: users.createUser('eva'), ana: users.createUser('ana'), luis: users.createUser('luis') };
    users.setPermission('eva', 'P', 'writer');
    users.setPermission('eva', 'S', 'writer');
    users.setPermission('ana', 'P', 'reader');
    users.setPermission('luis', 'P', 'writer');
    users.save();
    access = new AccessController(users, reg);
    server = new FilesHttpServer({ domes: reg, users, access, env, host: '127.0.0.1', port: 0 });
    url = (await server.start()).url;
    env.SAVIA_FILES_HTTP_URL = url;
  });
  afterEach(async () => { await server.stop(); Journal.closeAll(); fs.rmSync(root, { recursive: true, force: true }); });

  it('AC1 (núcleo): OPTIONS anuncia exactamente lo implementado; subida en dos trozos con HEAD entre medias', async () => {
    const o = await req('/v1/files/P/uploads', { method: 'OPTIONS' });
    expect(o.status).toBe(204);
    expect(o.headers.get('tus-extension')).toBe('creation,creation-with-upload,termination,expiration,checksum');
    expect(o.headers.get('tus-checksum-algorithm')).toBe('sha256');
    const data = randomBytes(300_000);
    const c = await create('P', tokens.eva, data.length, 'datos.bin');
    const loc = c.headers.get('location')!;
    expect(c.headers.get('upload-expires')).toBeTruthy();
    expect((await patch(loc, tokens.eva, 0, data.subarray(0, 100_000), { 'Upload-Checksum': `sha256 ${sha(data.subarray(0, 100_000)).toString('base64')}` })).headers.get('upload-offset')).toBe('100000');
    const h = await req(loc, { method: 'HEAD', token: tokens.eva, headers: tusHeaders() });
    expect([h.status, h.headers.get('upload-offset'), h.headers.get('upload-length'), h.headers.get('cache-control')]).toEqual([200, '100000', '300000', 'no-store']);
    const done = await patch(loc, tokens.eva, 100_000, data.subarray(100_000));
    expect(done.headers.get('savia-status')).toBe('ARCHIVE_ONLY');
    const id = done.headers.get('savia-document-id')!;
    const dl = await req(`/v1/files/P/documents/${id}/content`, { token: tokens.eva });
    expect(Buffer.from(await dl.arrayBuffer()).equals(data)).toBe(true);
    const st = await (await req(loc, { token: tokens.eva })).json();
    expect(st).toMatchObject({ status: 'done', documentId: id });
    // creation-with-upload
    const small = Buffer.from('# Nota\n\ncontenido\n');
    const cw = await req('/v1/files/P/uploads', { method: 'POST', token: tokens.eva, body: small, headers: tusHeaders({ 'Upload-Length': String(small.length), 'Upload-Metadata': `filename ${b64('nota.md')}`, 'Content-Type': 'application/offset+octet-stream' }) });
    expect([cw.status, cw.headers.get('upload-offset'), cw.headers.get('savia-status')]).toEqual([201, String(small.length), 'READY']);
  });

  it('AC2: 412 sin versión, 409 offset, 460 checksum, 413 tamaño, 415 tipo, 423 PATCH concurrente, 404/410 caducada', async () => {
    const c = await create('P', tokens.eva, 1000);
    const loc = c.headers.get('location')!;
    expect((await req(loc, { method: 'HEAD', token: tokens.eva })).status).toBe(412);
    expect((await patch(loc, tokens.eva, 5, Buffer.alloc(10))).status).toBe(409);
    const bad = await patch(loc, tokens.eva, 0, Buffer.alloc(10), { 'Upload-Checksum': `sha256 ${Buffer.alloc(32).toString('base64')}` });
    expect(bad.status).toBe(460);
    expect((await req(loc, { method: 'HEAD', token: tokens.eva, headers: tusHeaders() })).headers.get('upload-offset')).toBe('0');
    expect((await create('P', tokens.eva, 6 * 1024 * 1024)).status).toBe(413);
    expect((await req(loc, { method: 'PATCH', token: tokens.eva, body: Buffer.alloc(1), headers: tusHeaders({ 'Upload-Offset': '0', 'Content-Type': 'text/plain' }) })).status).toBe(415);
    // PATCH concurrente: el primero se queda esperando cuerpo
    let release!: () => void;
    const slow = new ReadableStream({ start(ctrl) { ctrl.enqueue(new Uint8Array(10)); release = () => ctrl.close(); } });
    const first = fetch(`${url}${loc}`, { method: 'PATCH', body: slow, duplex: 'half', headers: { Authorization: `Bearer ${tokens.eva}`, ...tusHeaders({ 'Upload-Offset': '0', 'Content-Type': 'application/offset+octet-stream' }) } } as RequestInit);
    await new Promise((r) => setTimeout(r, 100));
    expect((await patch(loc, tokens.eva, 0, Buffer.alloc(10))).status).toBe(423);
    release();
    expect((await first).status).toBe(204);
    // Caducada
    await server.stop();
    server = new FilesHttpServer({ domes: reg, users: new UserStore(path.join(root, 'users.json')), access, env, host: '127.0.0.1', port: 0, uploadExpiryMs: 1 });
    url = (await server.start()).url;
    const old = (await create('P', tokens.eva, 10)).headers.get('location')!;
    await new Promise((r) => setTimeout(r, 10));
    expect([404, 410]).toContain((await req(old, { method: 'HEAD', token: tokens.eva, headers: tusHeaders() })).status);
    const svc = new FilesService({ domes: () => reg.listActive().map((d) => ({ name: d.name, confidentiality: d.confidentiality, files: d.files })), env, scanMode: 'off' });
    expect((await svc.gc({ dome: 'P' })).uploads).toBeGreaterThanOrEqual(1);
  });

  it('AC3: 401 sin token; reader no sube; autorizaciones acotadas de un solo uso, por cúpula, sin descargar; revocar usuario', async () => {
    expect((await create('P', '', 10)).status).toBe(401);
    expect((await create('P', 'sv_inventado', 10)).status).toBe(401);
    expect((await create('P', tokens.ana, 10)).status).toBe(403);
    const mcp = new FilesService({ domes: () => reg.listActive().map((d) => ({ name: d.name, confidentiality: d.confidentiality, files: d.files })), env, scanMode: 'off',
      authorize: (dome, action, tool) => access.authorizeUser({ username: 'eva', dome, action, tool }) });
    const grant = await callFilesTool(mcp, { action: 'upload', dome: 'P', name: 'delegado.txt', maxBytes: 1000 }) as { token: string; uploadUrl: string };
    expect(grant.uploadUrl).toBe(`${url}/v1/files/P/uploads`);
    expect((await create('S', grant.token, 5)).status).toBe(403); // otra cúpula
    expect((await create('P', grant.token, 5000)).status).toBe(413); // por encima de su maxBytes
    const up = await upload('P', grant.token, Buffer.from('hola desde fuera'));
    const doc = await (await req(`/v1/files/P/documents/${up.documentId}`, { token: tokens.eva })).json();
    expect(doc.name).toBe('delegado.txt'); // el nombre lo fija la autorización
    expect((await create('P', grant.token, 5)).status).toBe(401); // un solo uso
    expect((await req(`/v1/files/P/documents/${up.documentId}/content`, { token: grant.token })).status).toBe(403); // no sirve para descargar
    expect((await req('/v1/files/P/documents', { token: grant.token })).status).toBe(403);
    // Revocar al usuario invalida sus autorizaciones
    const g2 = await callFilesTool(mcp, { action: 'upload', dome: 'P' }) as { token: string };
    const users = new UserStore(path.join(root, 'users.json'));
    users.load();
    users.deleteUser('eva');
    users.save();
    expect((await create('P', g2.token, 5)).status).toBe(401);
    expect((await create('P', tokens.eva, 5)).status).toBe(401);
  });

  it('AC4/AC5: rangos, 416, ETag/304 y Content-Disposition seguro; en N3 sin bytes en claro durante la subida', async () => {
    for (const dome of ['P', 'S']) {
      const data = randomBytes(2 * 1024 * 1024 + 99);
      const c = await create(dome, tokens.eva, data.length, 'raro"; filename=otro.exe ñ.bin');
      const loc = c.headers.get('location')!;
      await patch(loc, tokens.eva, 0, data.subarray(0, 1024 * 1024 + 7));
      if (dome === 'S') {
        const walk = (d: string): string[] => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)]));
        const probe = data.subarray(4096, 4160);
        expect(walk(path.join(root, 'files', 'S')).filter((f) => fs.readFileSync(f).includes(probe))).toEqual([]);
      }
      const done = await patch(loc, tokens.eva, 1024 * 1024 + 7, data.subarray(1024 * 1024 + 7));
      const id = done.headers.get('savia-document-id')!;
      const content = `/v1/files/${dome}/documents/${id}/content`;
      for (const [range, a, b] of [['bytes=0-99', 0, 99], ['bytes=1048570-1048600', 1048570, 1048600], ['bytes=-500', data.length - 500, data.length - 1], [`bytes=${data.length - 10}-`, data.length - 10, data.length - 1]] as const) {
        const r = await req(content, { token: tokens.eva, headers: { Range: range } });
        expect(r.status, `${dome} ${range}`).toBe(206);
        expect(r.headers.get('content-range')).toBe(`bytes ${a}-${b}/${data.length}`);
        expect(Buffer.from(await r.arrayBuffer()).equals(data.subarray(a, b + 1))).toBe(true);
      }
      const bad = await req(content, { token: tokens.eva, headers: { Range: `bytes=${data.length}-` } });
      expect([bad.status, bad.headers.get('content-range')]).toEqual([416, `bytes */${data.length}`]);
      const full = await req(content, { token: tokens.eva });
      const etag = full.headers.get('etag')!;
      expect(full.headers.get('x-content-type-options')).toBe('nosniff');
      expect(full.headers.get('content-security-policy')).toBe('sandbox');
      const cd = full.headers.get('content-disposition')!;
      expect(cd).toMatch(/^attachment; filename="[^"]*"; filename\*=UTF-8''\S+$/);
      expect(cd.split('"')).toHaveLength(3); // la comilla del nombre no cierra el valor ni abre otro parámetro
      await full.arrayBuffer();
      expect((await req(content, { token: tokens.eva, headers: { 'If-None-Match': etag } })).status).toBe(304);
      const ifr = await req(content, { token: tokens.eva, headers: { Range: 'bytes=0-9', 'If-Range': '"otra"' } });
      expect(ifr.status).toBe(200);
      await ifr.arrayBuffer();
    }
  });

  it('AC3/SE-419: lectura por HTTP con permisos por documento; enlace de descarga MCP', async () => {
    const up = await upload('P', tokens.eva, Buffer.from('solo para eva'), 'privado.txt');
    const mcpEva = new FilesService({ domes: () => reg.listActive().map((d) => ({ name: d.name, confidentiality: d.confidentiality, files: d.files })), env, scanMode: 'off',
      authorize: (dome, action, tool) => access.authorizeUser({ username: 'eva', dome, action, tool }) });
    await mcpEva.policy({ dome: 'P', id: up.documentId, readers: ['eva'] });
    expect((await req(`/v1/files/P/documents/${up.documentId}/content`, { token: tokens.ana })).status).toBe(404);
    expect((await (await req('/v1/files/P/documents', { token: tokens.ana })).json()).documents).toEqual([]);
    expect((await (await req('/v1/files/P/documents', { token: tokens.eva })).json()).documents).toHaveLength(1);
    const link = await callFilesTool(mcpEva, { action: 'link', dome: 'P', id: up.documentId }) as { url: string };
    const dl = await fetch(link.url);
    expect([dl.status, await dl.text()]).toEqual([200, 'solo para eva']);
    const other = await req(`/v1/files/P/documents/${up.documentId === 'x' ? 'y' : 'f_0000000000000000'}/content?token=${encodeURIComponent(new URL(link.url).searchParams.get('token')!)}`);
    expect(other.status).toBe(403); // el enlace es de un documento concreto
    const op = await (await req(`/v1/files/P/operations/${up.operationId}`, { token: tokens.eva })).json();
    expect(op.receipt).toMatchObject({ status: 'committed', kind: 'put' });
  });

  it('AC6: no arranca sin usuarios ni fuera de loopback sin TLS; con TLS sirve https', async () => {
    const empty = new UserStore(path.join(root, 'nadie.json'));
    expect(() => FilesHttpServer.assertStartable({ users: empty, host: '127.0.0.1' })).toThrow(/usuarios/);
    const users = new UserStore(path.join(root, 'users.json'));
    users.load();
    expect(() => FilesHttpServer.assertStartable({ users, host: '0.0.0.0' })).toThrow(/TLS|--behind-proxy/);
    expect(() => FilesHttpServer.assertStartable({ users, host: '0.0.0.0', behindProxy: true })).not.toThrow();
    const cert = path.join(root, 'c.pem');
    const key = path.join(root, 'k.pem');
    execFileSync('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', key, '-out', cert, '-days', '1', '-subj', '/CN=localhost'], { stdio: 'ignore' });
    const tls = new FilesHttpServer({ domes: reg, users, access, env, host: '127.0.0.1', port: 0, tls: { cert: fs.readFileSync(cert), key: fs.readFileSync(key) } });
    const { url: turl } = await tls.start();
    try {
      expect(turl).toMatch(/^https:/);
      // curl asíncrono: uno síncrono bloquearía el event loop del servidor, que vive en este proceso
      const { stdout } = await promisify(execFile)('curl', ['-sk', '-o', '/dev/null', '-w', '%{http_code}', '-X', 'OPTIONS', `${turl}/v1/files/P/uploads`], { encoding: 'utf-8' });
      expect(stdout).toBe('204');
    } finally {
      await tls.stop();
    }
  }, 60_000);
});
