// SE-424 H1 — lo que el antivirus no puede leer entero no se da por limpio. ClamAV no analiza más de
// 2 GiB − 1 por fichero y responde «OK» (código 0): con `scan: required` se rechaza antes de guardar
// o de aceptar bytes por tus; con el ClamAV gestionado real, una firma propia confirma el tope.
import { describe, it, expect, beforeAll, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { Readable } from 'node:stream';
import { DomeRegistry } from '../../../src/registry/domes.js';
import { UserStore } from '../../../src/auth/store.js';
import { AccessController } from '../../../src/auth/controller.js';
import { FilesHttpServer } from '../../../src/server/http.js';
import { FilesService, type FilesDomeRef } from '../../../src/files/service.js';
import { Journal } from '../../../src/files/journal.js';
import { sodiumReady } from '../../../src/files/crypto.js';
import { Tools } from '../../../src/files/setup.js';
import { scanStream } from '../../../src/files/scan.js';

const GiB = 1024 ** 3;
const b64 = (s: string) => Buffer.from(s).toString('base64');

describe('SE-424 H1: tope de análisis del antivirus', () => {
  let root: string;
  let fake: string;
  const savedClam = process.env.SAVIA_FILES_CLAMSCAN;

  beforeAll(async () => { await sodiumReady(); });
  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-scanlim-'));
    fake = path.join(root, 'clamscan');
    // Falso clamscan: «OK» para cada ruta; por stdin (`-`) consume la entrada.
    fs.writeFileSync(fake, '#!/bin/sh\nfor a; do case "$a" in -) cat > /dev/null; echo "stdin: OK";; -*) ;; *) echo "$a: OK";; esac; done\nexit 0\n', { mode: 0o700 });
  });
  afterEach(() => {
    if (savedClam === undefined) delete process.env.SAVIA_FILES_CLAMSCAN; else process.env.SAVIA_FILES_CLAMSCAN = savedClam;
    Journal.closeAll();
    fs.rmSync(root, { recursive: true, force: true });
  });

  it('AC1: alta de 3 GiB con scan required ⇒ SCAN_REQUIRED (too-large-to-scan) sin leer el stream ni guardar nada', async () => {
    const env = { SAVIA_FILES_HOME: path.join(root, 'files'), SAVIA_FILES_KEYS_HOME: path.join(root, 'keys'), HOME: root, SAVIA_FILES_MAX_BYTES: String(4 * GiB) };
    const svc = new FilesService({
      domes: () => [{ name: 'D', confidentiality: 'N2', files: { enabled: true, scan: 'required' } }] as FilesDomeRef[],
      env, clamscan: fake,
    });
    let opened = false;
    await expect(svc.putMany({ dome: 'D', files: [{ name: 'grande.bin', size: 3 * GiB, stream: () => { opened = true; return Readable.from([]); } }] }))
      .rejects.toThrow(/too-large-to-scan/);
    expect(opened).toBe(false);
    expect(await svc.list({ dome: 'D' })).toMatchObject({ documents: [] });
    // Por debajo del tope, el alta sigue igual.
    const [ok] = await svc.putMany({ dome: 'D', files: [{ name: 'pequeno.txt', size: 5, stream: () => Readable.from([Buffer.from('hola\n')]) }] });
    expect(ok.status).toBe('READY');
  });

  it('AC1: tus rechaza con 422 al crear una subida que no se podrá analizar, y sin antivirus en una cúpula required', async () => {
    fs.mkdirSync(path.join(root, 'R'));
    fs.writeFileSync(path.join(root, 'domes.json'), JSON.stringify({ version: 1, defaultDome: 'R', domes: {
      R: { name: 'R', path: path.join(root, 'R'), description: '', confidentiality: 'N2', files: { enabled: true, scan: 'required' } },
    } }));
    const reg = new DomeRegistry(path.join(root, 'domes.json'));
    reg.load();
    const users = new UserStore(path.join(root, 'users.json'));
    const token = users.createUser('eva');
    users.setPermission('eva', 'R', 'writer');
    users.save();
    const env = { SAVIA_FILES_HOME: path.join(root, 'files'), SAVIA_FILES_KEYS_HOME: path.join(root, 'keys'), HOME: root, PATH: process.env.PATH, SAVIA_FILES_MAX_BYTES: String(4 * GiB) };
    const server = new FilesHttpServer({ domes: reg, users, access: new AccessController(users, reg), env, host: '127.0.0.1', port: 0 });
    const { url } = await server.start();
    const create = (length: number) => fetch(`${url}/v1/files/R/uploads`, { method: 'POST', headers: {
      Authorization: `Bearer ${token}`, 'Tus-Resumable': '1.0.0', 'Upload-Length': String(length), 'Upload-Metadata': `filename ${b64('a.bin')}`,
    } });
    try {
      process.env.SAVIA_FILES_CLAMSCAN = fake;
      const big = await create(3 * GiB);
      expect(big.status).toBe(422);
      expect((await big.json()).error.message).toMatch(/too-large-to-scan/);
      expect((await create(1024)).status).toBe(201);
      if (!fs.existsSync('/usr/bin/clamscan') && !fs.existsSync('/usr/local/bin/clamscan')) {
        delete process.env.SAVIA_FILES_CLAMSCAN;
        const none = await create(1024);
        expect(none.status).toBe(422);
        expect((await none.json()).error.code).toBe('SCAN_REQUIRED');
      }
    } finally {
      await server.stop();
    }
  });

  it('AC1: ClamAV gestionado real con firma propia: detecta por debajo del tope y no da por limpio lo que no lee', async () => {
    const managed = new Tools().clamav();
    if (!managed) return; // sin ClamAV gestionado en esta máquina
    const marker = 'SAVIA-SE424-MARCADOR-DE-PRUEBA-0123456789';
    const sig = path.join(root, 'sig');
    fs.mkdirSync(sig);
    fs.writeFileSync(path.join(sig, 'test.ndb'), `Savia.SE424.Test:0:*:${Buffer.from(marker).toString('hex')}\n`);
    // Envoltorio: el clamscan gestionado con su entorno, pero solo con la firma de prueba (carga en ms).
    const wrapper = path.join(root, 'clamscan-real');
    const envLine = Object.entries(managed.env).filter(([, v]) => v).map(([k, v]) => `${k}='${v}'`).join(' ');
    fs.writeFileSync(wrapper, `#!/bin/sh\nexec env ${envLine} '${managed.clamscan}' --database='${sig}' "$@"\n`, { mode: 0o700 });

    const small = await scanStream(() => Readable.from([Buffer.from(marker), Buffer.alloc(1024 * 1024)]), 1024 * 1024 + marker.length, { mode: 'auto', clamscan: wrapper });
    expect(small).toMatchObject({ verdict: 'infected', signature: 'Savia.SE424.Test.UNOFFICIAL' });

    // Tamaño declarado bajo pero stream de 2,1 GiB (defensa en profundidad): ClamAV no lo lee entero.
    function* big(): Generator<Buffer> {
      yield Buffer.from(marker);
      const zero = Buffer.alloc(64 * 1024 * 1024);
      for (let i = 0; i < 34; i++) yield zero; // 2,125 GiB
    }
    const over = await scanStream(() => Readable.from(big()), 1024, { mode: 'auto', clamscan: wrapper, timeoutMs: 300_000 });
    expect(over).toEqual({ verdict: 'error', detail: 'too-large-to-scan' });
  }, 360_000);
});
