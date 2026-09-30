// SE-422 AC1 — conformidad con el cliente oficial tus-js-client: 50 MiB en trozos de 5 MiB a una
// cúpula cifrada, corte a mitad, reinicio del servidor y reanudación por la URL de la subida.
import { describe, it, expect, beforeAll } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash, randomBytes } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import * as tus from 'tus-js-client';
import { DomeRegistry } from '../../src/registry/domes.js';
import { UserStore } from '../../src/auth/store.js';
import { AccessController } from '../../src/auth/controller.js';
import { FilesHttpServer } from '../../src/server/http.js';
import { Journal } from '../../src/files/journal.js';
import { sodiumReady } from '../../src/files/crypto.js';

const sha = (b: Buffer) => createHash('sha256').update(b).digest('hex');

beforeAll(async () => { await sodiumReady(); });

describe('SE-422 tus-js-client', () => {
  it('AC1: subida reanudable de 50 MiB con reinicio del servidor a mitad', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-tus-e2e-'));
    const env: NodeJS.ProcessEnv = { SAVIA_FILES_HOME: path.join(root, 'files'), SAVIA_FILES_KEYS_HOME: path.join(root, 'keys'), HOME: root, PATH: process.env.PATH, SAVIA_FILES_MAX_BYTES: String(64 * 1024 * 1024) };
    fs.mkdirSync(path.join(root, 'S'));
    fs.writeFileSync(path.join(root, 'domes.json'), JSON.stringify({ version: 1, defaultDome: 'S', domes: {
      S: { name: 'S', path: path.join(root, 'S'), description: '', confidentiality: 'N3', files: { enabled: true, scan: 'off' } },
    } }));
    const reg = new DomeRegistry(path.join(root, 'domes.json'));
    reg.load();
    const users = new UserStore(path.join(root, 'users.json'));
    const token = users.createUser('eva');
    users.setPermission('eva', 'S', 'writer');
    users.save();
    const access = new AccessController(users, reg);
    const make = (port: number) => new FilesHttpServer({ domes: reg, users, access, env, host: '127.0.0.1', port });
    let server = make(0);
    const { url } = await server.start();
    const port = Number(new URL(url).port);
    const data = randomBytes(50 * 1024 * 1024);
    const options = (extra: Partial<tus.UploadOptions>): tus.UploadOptions => ({
      endpoint: `${url}/v1/files/S/uploads`, chunkSize: 5 * 1024 * 1024, retryDelays: [],
      headers: { Authorization: `Bearer ${token}` }, metadata: { filename: 'grabacion.bin' }, ...extra,
    });
    try {
      // 1ª sesión: dos trozos y corte
      let uploadUrl = '';
      await new Promise<void>((resolve, reject) => {
        let chunks = 0;
        const up = new tus.Upload(data, options({
          onError: reject,
          onChunkComplete: () => { chunks++; if (chunks === 2) { uploadUrl = up.url!; void up.abort().then(resolve); } },
        }));
        up.start();
      });
      expect(uploadUrl).toMatch(/\/v1\/files\/S\/uploads\/u_[0-9a-f]{24}$/);
      // Reinicio del servidor en el mismo puerto: el estado de la subida está en el journal, no en memoria
      await server.stop();
      Journal.closeAll();
      server = make(port);
      await server.start();
      // 2ª sesión: tus-js-client pregunta el offset (HEAD) y sigue desde ahí
      let offsetAtResume = -1;
      const headers: Record<string, string> = {};
      await new Promise<void>((resolve, reject) => {
        const up = new tus.Upload(data, options({
          uploadUrl,
          // Como un cliente real: el primer intento puede reutilizar un socket del servidor anterior
          retryDelays: [0, 200, 500],
          onError: reject,
          onProgress: (sent) => { if (offsetAtResume < 0) offsetAtResume = sent; },
          onAfterResponse: (_req, res) => { for (const h of ['Savia-Document-Id', 'Savia-Operation-Id', 'Savia-Status']) { const v = res.getHeader(h); if (v) headers[h] = v; } },
          onSuccess: () => resolve(),
        }));
        up.start();
      });
      expect(offsetAtResume).toBeGreaterThanOrEqual(10 * 1024 * 1024);
      expect(headers['Savia-Document-Id']).toMatch(/^f_[0-9a-f]{16}$/);
      // Bytes idénticos, receipt y commit en el ledger
      const dl = await fetch(`${url}/v1/files/S/documents/${headers['Savia-Document-Id']}/content`, { headers: { Authorization: `Bearer ${token}` } });
      expect(sha(Buffer.from(await dl.arrayBuffer()))).toBe(sha(data));
      const op = await (await fetch(`${url}/v1/files/S/operations/${headers['Savia-Operation-Id']}`, { headers: { Authorization: `Bearer ${token}` } })).json();
      expect(op.receipt).toMatchObject({ status: 'committed', kind: 'put' });
      expect(execFileSync('git', ['-C', path.join(root, 'files', 'S', 'ledger'), 'cat-file', '-t', op.receipt.commitSha], { encoding: 'utf-8' }).trim()).toBe('commit');
      // Nada de la subida queda en disco
      expect(fs.readdirSync(path.join(root, 'files', 'S', 'uploads'))).toEqual([]);
    } finally {
      await server.stop();
      Journal.closeAll();
      fs.rmSync(root, { recursive: true, force: true });
    }
  }, 120_000);
});
