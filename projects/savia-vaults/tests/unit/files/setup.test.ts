// SE-416 — instalador de dependencias de Savia Files sin root: extractor (uv + venv) y
// antivirus (ClamAV oficial desempaquetado). Artefactos falsos servidos en local, sin red.
import { describe, it, expect, beforeAll, afterAll, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { Tools, type ToolsPins } from '../../../src/files/setup.js';
import { fakeClamavDeb, fakeUvTarGz, serve, sha256, type FakeServer } from './fake-artifacts.js';

let work: string;
let server: FakeServer;
let deb: Buffer;
let uv: Buffer;

beforeAll(async () => {
  work = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-setup-art-'));
  deb = fakeClamavDeb(work);
  uv = fakeUvTarGz(work);
  server = await serve({ '/clamav.deb': deb, '/uv.tar.gz': uv, '/otra.deb': deb });
});
afterAll(async () => { await server.close(); fs.rmSync(work, { recursive: true, force: true }); });

const pins = (over: Partial<ToolsPins> = {}): ToolsPins => ({
  clamav: { version: '9.9.9', url: `${server.url}/clamav.deb`, sha256: sha256(deb) },
  uv: { version: '0.0.1', url: `${server.url}/uv.tar.gz`, sha256: sha256(uv) },
  python: '3.12',
  torchIndex: 'https://download.pytorch.org/whl/cpu',
  ...over,
});

describe('Tools', () => {
  let base: string;
  let home: string;
  let userHome: string;
  let lock: string;
  const make = (p: ToolsPins | null = pins(), env: NodeJS.ProcessEnv = {}) =>
    new Tools({ home, pins: p, lockFile: lock, env: { PATH: process.env.PATH, HOME: userHome, ...env } });

  beforeEach(() => {
    base = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-setup-'));
    home = path.join(base, 'tools');
    userHome = path.join(base, 'home');
    fs.mkdirSync(userHome);
    lock = path.join(base, 'requirements.lock');
    fs.writeFileSync(lock, 'docling==2.131.0 \\\n    --hash=sha256:00\n');
    server.hits.clear();
  });
  afterEach(() => fs.rmSync(base, { recursive: true, force: true }));

  /** Envejece la última comprobación correcta de firmas (marca `.last-update`). */
  const ageSignatures = (hours: number) => {
    const old = new Date(Date.now() - hours * 3600_000);
    fs.utimesSync(path.join(home, 'clamav', 'db', '.last-update'), old, old);
  };

  it('plataforma no soportada: status lo dice en lenguaje llano y setup no hace nada', async () => {
    const t = make(null);
    const s = t.status();
    expect(s.supported).toBe(false);
    expect(s.antivirus.state).toBe('unsupported');
    expect(s.antivirus.message).toMatch(/todavía no puedo instalarlo/);
    await expect(t.setup(['antivirus'])).rejects.toThrow(/UNSUPPORTED/);
    expect(fs.existsSync(home)).toBe(false);
  });

  it('AC1 antivirus: instala sin root, poda, descarga firmas y queda listo', async () => {
    const t = make();
    expect(t.status().antivirus).toMatchObject({ state: 'missing', message: expect.stringMatching(/no se analizan con antivirus/) });
    const [r] = await t.setup(['antivirus']);
    expect(r).toMatchObject({ component: 'antivirus', ok: true });
    const dir = path.join(home, 'clamav', '9.9.9');
    expect(fs.readdirSync(path.join(dir, 'bin')).sort()).toEqual(['clamscan', 'freshclam']);
    expect(fs.readlinkSync(path.join(dir, 'lib', 'libclamav.so.12'))).toBe('libclamav.so.12.1.0');
    expect(fs.existsSync(path.join(dir, 'lib', 'libclamav_rust.a'))).toBe(false);
    expect(fs.existsSync(path.join(dir, 'certs', 'clamav.crt'))).toBe(true);
    expect(fs.existsSync(path.join(home, 'clamav', 'db', 'daily.cvd'))).toBe(true);
    const c = t.clamav()!;
    expect(c.clamscan).toBe(path.join(dir, 'bin', 'clamscan'));
    expect(c.env.LD_LIBRARY_PATH).toBe(path.join(dir, 'lib'));
    expect(c.env.CVD_CERTS_DIR).toBe(path.join(dir, 'certs'));
    expect(c.args).toEqual([`--database=${path.join(home, 'clamav', 'db')}`]);
    const s = t.status().antivirus;
    expect(s).toMatchObject({ state: 'installed', version: '9.9.9' });
    expect(s.signaturesAgeHours).toBeLessThan(1);
    expect(s.message).toMatch(/Antivirus activo/);
    expect(s.diskBytes).toBeGreaterThan(0);
  });

  it('AC4: la segunda ejecución no descarga nada', async () => {
    const t = make();
    await t.setup(['antivirus']);
    const before = server.hits.get('/clamav.deb');
    const [r] = await t.setup(['antivirus']);
    expect(r).toMatchObject({ ok: true, downloadedBytes: 0 });
    expect(server.hits.get('/clamav.deb')).toBe(before);
  });

  it('AC2: un SHA-256 distinto aborta sin dejar nada y conserva la instalación anterior', async () => {
    await make().setup(['antivirus']);
    const bad = make(pins({ clamav: { version: '9.9.10', url: `${server.url}/otra.deb`, sha256: 'f'.repeat(64) } }));
    const [r] = await bad.setup(['antivirus']);
    expect(r.ok).toBe(false);
    expect(r.error).toMatch(/INTEGRITY/);
    expect(fs.existsSync(path.join(home, 'clamav', '9.9.10'))).toBe(false);
    expect(fs.readdirSync(home).filter((f) => f.startsWith('.tmp'))).toEqual([]);
    expect(bad.status().antivirus).toMatchObject({ state: 'installed', version: '9.9.9' });
    expect(fs.existsSync(bad.clamav()!.clamscan)).toBe(true);
  });

  it('AC3: una descarga cortada no deja el componente a medias', async () => {
    const t = make(pins({ clamav: { version: '9.9.9', url: `${server.url}/rota/clamav.deb`, sha256: sha256(deb) } }));
    const [r] = await t.setup(['antivirus']);
    expect(r.ok).toBe(false);
    expect(t.status().antivirus.state).toBe('missing');
    expect(fs.existsSync(path.join(home, 'clamav', '9.9.9'))).toBe(false);
    expect(fs.readdirSync(home).filter((f) => f.startsWith('.tmp'))).toEqual([]);
  });

  it('si las firmas no se pueden descargar, el antivirus no se da por instalado', async () => {
    const t = make(pins(), { FAKE_FRESHCLAM_FAIL: '1' });
    const [r] = await t.setup(['antivirus']);
    expect(r.ok).toBe(false);
    expect(r.error).toMatch(/firmas/);
    expect(t.status().antivirus.state).toBe('missing');
  });

  it('AC1 extractor: uv + venv + lock con hashes, verificado antes de activarlo', async () => {
    const t = make();
    expect(t.status().extractor.message).toMatch(/no se leen/);
    const [r] = await t.setup(['extractor']);
    expect(r).toMatchObject({ component: 'extractor', ok: true });
    expect(t.pythonPath()).toBe(path.join(home, 'files-venv', 'bin', 'python'));
    expect(t.status().extractor).toMatchObject({ state: 'installed', message: expect.stringMatching(/se leen PDF/) });
    expect(fs.existsSync(path.join(home, '.uv-cache'))).toBe(false);
  });

  it('extractor: si falla la instalación de paquetes, no queda venv ni se activa', async () => {
    const t = make(pins(), { FAKE_UV_FAIL: '1' });
    const [r] = await t.setup(['extractor']);
    expect(r.ok).toBe(false);
    expect(t.pythonPath()).toBeUndefined();
    expect(fs.existsSync(path.join(home, 'files-venv'))).toBe(false);
  });

  it('AC5: firmas de más de 24 h se actualizan en segundo plano, como mucho una vez cada 4 h', async () => {
    const t = make();
    await t.setup(['antivirus']);
    ageSignatures(30);
    expect(t.status().antivirus.signaturesAgeHours).toBeGreaterThanOrEqual(29);
    expect(t.maybeRefreshSignatures()).toBe('started');
    expect(t.maybeRefreshSignatures()).toBe('skipped');
    const updates = path.join(home, 'clamav', 'db', '.updates');
    for (let i = 0; i < 50 && fs.readFileSync(updates, 'utf-8').trim().split('\n').length < 2; i++) await new Promise((r) => setTimeout(r, 100));
    expect(fs.readFileSync(updates, 'utf-8').trim().split('\n')).toHaveLength(2);
  });

  it('AC6: con firmas de más de 7 días, el mensaje avisa de que no protege', async () => {
    const t = make();
    await t.setup(['antivirus']);
    ageSignatures(9 * 24);
    expect(t.status().antivirus).toMatchObject({ state: 'stale', message: expect.stringMatching(/hace 9 días/) });
  });

  it('en segundo plano: startSetup vuelve al instante y status informa del progreso', async () => {
    const t = make();
    const first = t.startSetup(['antivirus']);
    expect(first.started).toBe(true);
    expect(t.startSetup(['antivirus']).started).toBe(false); // ya en curso
    expect(t.status().job?.running).toBe(true);
    await t.waitForJob();
    expect(t.status().job).toMatchObject({ running: false, results: [{ component: 'antivirus', ok: true }] });
  });

  it('AC8: solo escribe en su directorio, y no dentro de git', async () => {
    await make().setup(['antivirus', 'extractor']);
    expect(fs.readdirSync(userHome)).toEqual([]);
    expect(fs.readdirSync(base).sort()).toEqual(['home', 'requirements.lock', 'tools']);
    const repo = path.join(base, 'repo');
    fs.mkdirSync(path.join(repo, '.git'), { recursive: true });
    fs.writeFileSync(path.join(repo, '.git', 'HEAD'), 'ref: refs/heads/main\n');
    const inGit = new Tools({ home: path.join(repo, 'tools'), pins: pins(), lockFile: lock, env: { PATH: process.env.PATH, HOME: userHome } });
    await expect(inGit.setup(['antivirus'])).rejects.toThrow(/UNSAFE_HOME/);
  });
});
