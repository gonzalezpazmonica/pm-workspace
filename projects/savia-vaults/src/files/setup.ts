// SE-416 — instalador de las dependencias de Savia Files sin consola ni administrador.
// Todo vive en ~/.savia-vaults/tools: ClamAV oficial desempaquetado (sin dpkg ni root) con
// firmas propias, y el extractor Python (uv + venv + lock con hashes). Versiones, URLs y
// SHA-256 fijados en el código; instalación atómica e idempotente; mensajes en lenguaje llano.
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { createHash } from 'node:crypto';
import { execFile, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { ensureSafeHome, writeAtomic } from '../rag/store.js';
import { RagError } from '../rag/types.js';
import { readAr, extractTarGz } from './deb.js';
import { FilesError } from './types.js';

export type Component = 'extractor' | 'antivirus';
export interface Artifact { version: string; url: string; sha256: string }
export interface ToolsPins { clamav: Artifact; uv: Artifact; python: string; torchIndex: string }

/** Versiones fijadas por plataforma. Solo Linux x86_64 está probado (SE-416). */
export const PINS: Record<string, ToolsPins> = {
  'linux-x64': {
    clamav: {
      version: '1.5.4',
      url: 'https://github.com/Cisco-Talos/clamav/releases/download/clamav-1.5.4/clamav-1.5.4.linux.x86_64.deb',
      sha256: '28d6efc5b4423e7830c3559339552eb53870a9eac51ac4efb37d60530d329886',
    },
    uv: {
      version: '0.12.21',
      url: 'https://github.com/astral-sh/uv/releases/download/0.12.21/uv-x86_64-unknown-linux-gnu.tar.gz',
      sha256: '23f02075b652bb1df64178cfae41b5caf160822e720e2663568f3f5d63bc52c0',
    },
    python: '3.12',
    torchIndex: 'https://download.pytorch.org/whl/cpu',
  },
};

const HOUR = 3_600_000;
const REFRESH_AFTER_H = 24;
const REFRESH_THROTTLE_H = 4;
export const STALE_AFTER_H = 7 * 24;
const SIZE_HINT = { extractor: '1,5 GB', antivirus: '150 MB' } as const;
const PLATFORM_NAMES: Record<string, string> = { darwin: 'macOS', win32: 'Windows', linux: 'Linux' };

export function toolsHome(env: NodeJS.ProcessEnv = process.env): string {
  return env.SAVIA_TOOLS_HOME || path.join(env.HOME || os.homedir(), '.savia-vaults', 'tools');
}

export function defaultLockFile(): string {
  return fileURLToPath(new URL('../../workers/files/requirements.lock', import.meta.url));
}

interface State {
  extractor?: { lockSha256: string; uv: string; python: string; installedAt: string };
  antivirus?: { version: string; installedAt: string; lastRefreshAttempt?: string };
}

export interface ComponentStatus {
  state: 'installed' | 'stale' | 'missing' | 'unsupported' | 'manual';
  version?: string;
  diskBytes?: number;
  signaturesAgeHours?: number;
  /** Frase para la persona: qué pasa y qué supone, sin rutas ni jerga. */
  message: string;
}

export interface JobStatus { running: boolean; components: Component[]; phase?: string; startedAt: string; results?: SetupResult[] }

export interface ToolsStatus {
  supported: boolean;
  extractor: ComponentStatus;
  antivirus: ComponentStatus;
  job?: JobStatus;
}

export interface SetupResult { component: Component; ok: boolean; downloadedBytes: number; error?: string; message: string }

export interface ManagedClamav { clamscan: string; freshclam: string; env: NodeJS.ProcessEnv; args: string[]; database: string; signaturesAgeHours: number }

export interface ToolsOptions {
  home?: string;
  env?: NodeJS.ProcessEnv;
  /** `undefined`: las de la plataforma actual; `null`: plataforma no soportada. */
  pins?: ToolsPins | null;
  lockFile?: string;
}

const sha256File = (file: string) => createHash('sha256').update(fs.readFileSync(file)).digest('hex');

function run(cmd: string, args: string[], env: NodeJS.ProcessEnv, timeoutMs = 3_600_000): Promise<string> {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, { env, timeout: timeoutMs, maxBuffer: 16 * 1024 * 1024, encoding: 'utf-8' }, (err, stdout, stderr) => {
      if (err) reject(new Error(`${path.basename(cmd)} ${args[0] ?? ''}: ${(stderr || stdout || err.message).trim().slice(-400)}`));
      else resolve(stdout);
    });
  });
}

function dirBytes(p: string): number {
  let st: fs.Stats;
  try { st = fs.lstatSync(p); } catch { return 0; }
  if (!st.isDirectory()) return st.size;
  return fs.readdirSync(p).reduce((n, f) => n + dirBytes(path.join(p, f)), 0);
}

/** Un proceso solo tiene una instalación en curso a la vez, aunque haya varias instancias. */
const jobs = new Map<string, { status: JobStatus; promise: Promise<SetupResult[]> }>();

export class Tools {
  readonly home: string;
  private readonly env: NodeJS.ProcessEnv;
  private readonly pins: ToolsPins | null;
  private readonly lockFile: string;

  constructor(o: ToolsOptions = {}) {
    this.env = o.env ?? process.env;
    this.home = path.resolve(o.home ?? toolsHome(this.env));
    this.pins = o.pins === undefined ? PINS[`${process.platform}-${process.arch}`] ?? null : o.pins;
    this.lockFile = o.lockFile ?? defaultLockFile();
  }

  // ── Estado ─────────────────────────────────────────────────────────────

  private get statePath(): string { return path.join(this.home, 'state.json'); }
  private get dbDir(): string { return path.join(this.home, 'clamav', 'db'); }
  private get venvPython(): string { return path.join(this.home, 'files-venv', 'bin', 'python'); }

  private readState(): State {
    try { return JSON.parse(fs.readFileSync(this.statePath, 'utf-8')) as State; } catch { return {}; }
  }

  private writeState(update: (s: State) => void): void {
    const s = this.readState();
    update(s);
    writeAtomic(this.statePath, JSON.stringify(s, null, 1));
  }

  /** Python del extractor gestionado, si está instalado y verificado. */
  pythonPath(): string | undefined {
    return this.readState().extractor && fs.existsSync(this.venvPython) ? this.venvPython : undefined;
  }

  /** ClamAV gestionado: binarios, entorno y base de firmas propios; `undefined` si no está. */
  clamav(): ManagedClamav | undefined {
    const av = this.readState().antivirus;
    if (!av) return undefined;
    const dir = path.join(this.home, 'clamav', av.version);
    const clamscan = path.join(dir, 'bin', 'clamscan');
    if (!fs.existsSync(clamscan)) return undefined;
    return {
      clamscan, freshclam: path.join(dir, 'bin', 'freshclam'), database: this.dbDir,
      env: { PATH: this.env.PATH, HOME: this.env.HOME, LD_LIBRARY_PATH: path.join(dir, 'lib'), CVD_CERTS_DIR: path.join(dir, 'certs') },
      args: [`--database=${this.dbDir}`],
      signaturesAgeHours: this.signaturesAgeHours(),
    };
  }

  private signaturesAgeHours(): number {
    try { return (Date.now() - fs.statSync(path.join(this.dbDir, '.last-update')).mtimeMs) / HOUR; } catch { return Infinity; }
  }

  status(): ToolsStatus {
    const job = jobs.get(this.home)?.status;
    if (!this.pins) {
      const where = PLATFORM_NAMES[process.platform] ?? process.platform;
      const unsupported = (what: string): ComponentStatus => ({
        state: 'unsupported', message: `En este sistema (${where}, ${process.arch}) todavía no puedo instalarlo automáticamente: ${what}.`,
      });
      return {
        supported: false,
        extractor: this.manualExtractor() ?? unsupported('los PDF, Word, PowerPoint y Excel se guardan pero no se leen'),
        antivirus: unsupported('los ficheros no se analizan con antivirus'),
        ...(job ? { job } : {}),
      };
    }
    return { supported: true, extractor: this.extractorStatus(), antivirus: this.antivirusStatus(), ...(job ? { job } : {}) };
  }

  private manualExtractor(): ComponentStatus | undefined {
    const legacy = this.env.SAVIA_FILES_PYTHON || path.join(this.env.HOME || os.homedir(), '.savia-vaults', 'files-venv', 'bin', 'python');
    return fs.existsSync(legacy)
      ? { state: 'manual', message: 'Lector de documentos instalado a mano: se leen PDF, Word, PowerPoint y Excel.' }
      : undefined;
  }

  private extractorStatus(): ComponentStatus {
    const st = this.readState().extractor;
    if (st && fs.existsSync(this.venvPython)) {
      return {
        state: 'installed', version: `python ${st.python}, uv ${st.uv}`, diskBytes: dirBytes(path.join(this.home, 'files-venv')),
        message: 'Lector de documentos instalado: se leen PDF, Word, PowerPoint y Excel.',
      };
    }
    return this.manualExtractor() ?? {
      state: 'missing',
      message: `Los PDF, Word, PowerPoint y Excel se guardan pero no se leen: falta el lector de documentos (unos ${SIZE_HINT.extractor} de descarga). Puedo instalarlo.`,
    };
  }

  private antivirusStatus(): ComponentStatus {
    const c = this.clamav();
    if (!c) {
      return { state: 'missing', message: `Los ficheros no se analizan con antivirus. Puedo instalar ClamAV (unos ${SIZE_HINT.antivirus}).` };
    }
    const age = c.signaturesAgeHours;
    const version = this.readState().antivirus!.version;
    const diskBytes = dirBytes(path.join(this.home, 'clamav'));
    if (age > STALE_AFTER_H) {
      const days = Number.isFinite(age) ? Math.floor(age / 24) : undefined;
      return {
        state: 'stale', version, diskBytes, signaturesAgeHours: age,
        message: `Antivirus instalado, pero sus firmas son de hace ${days ?? 'muchos'} días: no protege frente a amenazas recientes. Puedo actualizarlas.`,
      };
    }
    const when = age < 1 ? 'de hace menos de una hora' : age < 48 ? `de hace ${Math.round(age)} horas` : `de hace ${Math.floor(age / 24)} días`;
    return { state: 'installed', version, diskBytes, signaturesAgeHours: age, message: `Antivirus activo; firmas ${when}.` };
  }

  // ── Instalación ────────────────────────────────────────────────────────

  /** Instala en primer plano (CLI). Devuelve un resultado por componente; no lanza por fallos de un componente. */
  async setup(components: Component[], onPhase?: (phase: string) => void): Promise<SetupResult[]> {
    if (!this.pins) throw new FilesError('UNSUPPORTED', `instalación automática no disponible en ${process.platform}-${process.arch}`);
    try {
      ensureSafeHome(this.home);
    } catch (e) {
      if (e instanceof RagError && e.code === 'UNSAFE_HOME') throw new FilesError('UNSAFE_HOME', `el directorio de herramientas (${this.home}) está dentro de un repo git`);
      throw e;
    }
    const out: SetupResult[] = [];
    for (const c of [...new Set(components)].sort()) {
      const tmp = fs.mkdtempSync(path.join(this.home, '.tmp-'));
      try {
        const bytes = c === 'antivirus' ? await this.installAntivirus(tmp, onPhase) : await this.installExtractor(tmp, onPhase);
        out.push({ component: c, ok: true, downloadedBytes: bytes, message: c === 'antivirus' ? this.antivirusStatus().message : this.extractorStatus().message });
      } catch (e) {
        const msg = (e as Error).message;
        out.push({ component: c, ok: false, downloadedBytes: 0, error: msg, message: this.failureMessage(c, msg) });
      } finally {
        fs.rmSync(tmp, { recursive: true, force: true });
      }
    }
    return out;
  }

  /** Instala en segundo plano (MCP): vuelve al instante; `status().job` informa del progreso. */
  startSetup(components: Component[]): { started: boolean; job: JobStatus } {
    const current = jobs.get(this.home);
    if (current?.status.running) return { started: false, job: current.status };
    const status: JobStatus = { running: true, components, startedAt: new Date().toISOString(), phase: 'empezando' };
    const promise = this.setup(components, (p) => { status.phase = p; })
      .catch((e: Error) => components.map((component) => ({ component, ok: false, downloadedBytes: 0, error: e.message, message: this.failureMessage(component, e.message) })))
      .then((results) => { status.running = false; status.results = results; status.phase = 'terminado'; return results; });
    jobs.set(this.home, { status, promise });
    return { started: true, job: status };
  }

  async waitForJob(): Promise<SetupResult[] | undefined> {
    return jobs.get(this.home)?.promise;
  }

  private failureMessage(c: Component, error: string): string {
    const what = c === 'antivirus' ? 'el antivirus' : 'el lector de documentos';
    if (/INTEGRITY/.test(error)) return `No he instalado ${what}: la descarga no coincide con la versión verificada. No he cambiado nada; puede ser un problema de red.`;
    if (/firmas/.test(error)) return `No he instalado ${what}: no he podido descargar las firmas de virus. Reinténtalo más tarde.`;
    return `No he instalado ${what}: ${error.slice(0, 160)}. No he cambiado nada de lo que ya funcionaba.`;
  }

  /** Descarga a `dest` comprobando el SHA-256 fijado; si no coincide, borra y lanza INTEGRITY. */
  private async download(a: Artifact, dest: string): Promise<number> {
    const res = await fetch(a.url, { redirect: 'follow' });
    if (!res.ok || !res.body) throw new Error(`descarga fallida (${res.status}) de ${new URL(a.url).host}`);
    const hash = createHash('sha256');
    const fd = fs.openSync(dest, 'w', 0o600);
    let n = 0;
    try {
      for await (const chunk of res.body as unknown as AsyncIterable<Uint8Array>) {
        hash.update(chunk);
        fs.writeSync(fd, chunk);
        n += chunk.length;
      }
    } finally {
      fs.closeSync(fd);
    }
    if (hash.digest('hex') !== a.sha256) {
      fs.rmSync(dest, { force: true });
      throw new FilesError('INTEGRITY', `SHA-256 de ${path.basename(new URL(a.url).pathname)} no coincide con el fijado`);
    }
    return n;
  }

  private async installAntivirus(tmp: string, onPhase?: (p: string) => void): Promise<number> {
    const pin = this.pins!.clamav;
    const final = path.join(this.home, 'clamav', pin.version);
    const st = this.readState().antivirus;
    if (st?.version === pin.version && fs.existsSync(path.join(final, 'bin', 'clamscan')) && this.signaturesAgeHours() < STALE_AFTER_H) return 0;
    onPhase?.('antivirus: descargando');
    const deb = path.join(tmp, 'clamav.deb');
    let bytes = 0;
    if (!(st?.version === pin.version && fs.existsSync(path.join(final, 'bin', 'clamscan')))) {
      bytes = await this.download(pin, deb);
      onPhase?.('antivirus: desempaquetando');
      const data = readAr(fs.readFileSync(deb)).find((m) => m.name === 'data.tar.gz');
      if (!data) throw new Error('paquete de ClamAV sin data.tar.gz');
      const staged = path.join(tmp, 'clamav');
      extractTarGz(data.data, staged, (p) => {
        let m = /^usr\/local\/bin\/(clamscan|freshclam)$/.exec(p);
        if (m) return `bin/${m[1]}`;
        m = /^usr\/local\/lib\/(lib[^/]+\.so[^/]*)$/.exec(p);
        if (m) return `lib/${m[1]}`;
        m = /^usr\/local\/etc\/certs\/([^/]+)$/.exec(p);
        if (m) return `certs/${m[1]}`;
        return undefined;
      });
      for (const f of ['bin/clamscan', 'bin/freshclam', 'certs']) {
        if (!fs.existsSync(path.join(staged, f))) throw new Error(`paquete de ClamAV incompleto: falta ${f}`);
      }
      onPhase?.('antivirus: descargando firmas');
      await this.freshclam(staged);
      fs.mkdirSync(path.dirname(final), { recursive: true, mode: 0o700 });
      fs.rmSync(final, { recursive: true, force: true });
      fs.renameSync(staged, final);
      // Versiones anteriores: fuera, una vez activa la nueva.
      for (const v of fs.readdirSync(path.dirname(final))) {
        if (v !== pin.version && v !== 'db') fs.rmSync(path.join(path.dirname(final), v), { recursive: true, force: true });
      }
    } else {
      onPhase?.('antivirus: actualizando firmas');
      await this.freshclam(final);
    }
    this.writeState((s) => { s.antivirus = { version: pin.version, installedAt: s.antivirus?.version === pin.version ? s.antivirus.installedAt : new Date().toISOString() }; });
    return bytes;
  }

  private freshclamConf(): string {
    fs.mkdirSync(this.dbDir, { recursive: true, mode: 0o700 });
    const conf = path.join(this.dbDir, 'freshclam.conf');
    writeAtomic(conf, `DatabaseDirectory ${this.dbDir}\nDatabaseMirror database.clamav.net\n`);
    return conf;
  }

  /** Firmas a la base propia; la marca `.last-update` registra la última comprobación correcta. */
  private async freshclam(clamDir: string): Promise<void> {
    const conf = this.freshclamConf();
    const env = { PATH: this.env.PATH, HOME: this.env.HOME, LD_LIBRARY_PATH: path.join(clamDir, 'lib'), CVD_CERTS_DIR: path.join(clamDir, 'certs'), ...this.passThrough() };
    try {
      await run(path.join(clamDir, 'bin', 'freshclam'), [`--config-file=${conf}`, '--stdout'], env, 900_000);
    } catch (e) {
      throw new Error(`no se pudieron descargar las firmas: ${(e as Error).message.slice(-200)}`);
    }
    fs.writeFileSync(path.join(this.dbDir, '.last-update'), new Date().toISOString(), { mode: 0o600 });
  }

  /** Variables de prueba o de proxy que deben llegar a los procesos hijos. */
  private passThrough(): NodeJS.ProcessEnv {
    const out: NodeJS.ProcessEnv = {};
    for (const [k, v] of Object.entries(this.env)) {
      if (/^(FAKE_|HTTPS?_PROXY$|NO_PROXY$|https?_proxy$|no_proxy$|SSL_CERT_FILE$)/.test(k)) out[k] = v;
    }
    return out;
  }

  /**
   * SE-416 AC5: si la última comprobación correcta de firmas tiene más de 24 h, lanza
   * `freshclam` en segundo plano (como mucho una vez cada 4 h). No espera.
   */
  maybeRefreshSignatures(): 'started' | 'skipped' {
    const c = this.clamav();
    if (!c || c.signaturesAgeHours < REFRESH_AFTER_H) return 'skipped';
    const last = Date.parse(this.readState().antivirus?.lastRefreshAttempt ?? '') || 0;
    if (Date.now() - last < REFRESH_THROTTLE_H * HOUR) return 'skipped';
    this.writeState((s) => { if (s.antivirus) s.antivirus.lastRefreshAttempt = new Date().toISOString(); });
    const conf = this.freshclamConf();
    const marker = path.join(this.dbDir, '.last-update');
    const child = spawn('/bin/sh', ['-c', '"$0" "$1" --stdout >/dev/null 2>&1 && date > "$2"', c.freshclam, `--config-file=${conf}`, marker], {
      env: { ...c.env, ...this.passThrough() }, detached: true, stdio: 'ignore',
    });
    child.unref();
    return 'started';
  }

  private async installExtractor(tmp: string, onPhase?: (p: string) => void): Promise<number> {
    const pins = this.pins!;
    const lockSha256 = sha256File(this.lockFile);
    const st = this.readState().extractor;
    const final = path.join(this.home, 'files-venv');
    if (st?.lockSha256 === lockSha256 && st.uv === pins.uv.version && fs.existsSync(this.venvPython)) return 0;
    onPhase?.('lector de documentos: descargando uv');
    const tgz = path.join(tmp, 'uv.tar.gz');
    const bytes = await this.download(pins.uv, tgz);
    const uvDir = path.join(tmp, 'uv');
    extractTarGz(fs.readFileSync(tgz), uvDir, (p) => (/(^|\/)uv$/.test(p) ? 'uv' : undefined));
    const uv = path.join(uvDir, 'uv');
    if (!fs.existsSync(uv)) throw new Error('paquete de uv sin el binario');
    const cache = path.join(this.home, '.uv-cache');
    const env: NodeJS.ProcessEnv = {
      PATH: this.env.PATH, HOME: this.env.HOME,
      UV_CACHE_DIR: cache, UV_PYTHON_INSTALL_DIR: path.join(this.home, 'python'), UV_PYTHON_PREFERENCE: 'only-managed',
      UV_NO_CONFIG: '1', ...this.passThrough(),
    };
    const staged = path.join(tmp, 'files-venv');
    try {
      onPhase?.('lector de documentos: preparando Python');
      await run(uv, ['venv', staged, '--python', pins.python], env);
      onPhase?.('lector de documentos: instalando paquetes (puede tardar varios minutos)');
      await run(uv, ['pip', 'sync', this.lockFile, '--python', path.join(staged, 'bin', 'python'), '--require-hashes',
        '--extra-index-url', pins.torchIndex, '--index-strategy', 'unsafe-best-match'], env);
      const verify = (py: string) => run(py, ['-c', 'import docling, openpyxl, pptx'], env, 300_000);
      await verify(path.join(staged, 'bin', 'python'));
      onPhase?.('lector de documentos: activando');
      const old = `${final}.old`;
      fs.rmSync(old, { recursive: true, force: true });
      if (fs.existsSync(final)) fs.renameSync(final, old);
      fs.renameSync(staged, final);
      try {
        await verify(this.venvPython);
      } catch (e) {
        fs.rmSync(final, { recursive: true, force: true });
        if (fs.existsSync(old)) fs.renameSync(old, final);
        throw e;
      }
      fs.rmSync(old, { recursive: true, force: true });
      fs.mkdirSync(path.join(this.home, 'uv'), { recursive: true, mode: 0o700 });
      fs.copyFileSync(uv, path.join(this.home, 'uv', 'uv'));
      fs.chmodSync(path.join(this.home, 'uv', 'uv'), 0o700);
      this.writeState((s) => { s.extractor = { lockSha256, uv: pins.uv.version, python: pins.python, installedAt: new Date().toISOString() }; });
    } finally {
      fs.rmSync(cache, { recursive: true, force: true });
    }
    return bytes;
  }

  /** Borra un componente gestionado. */
  uninstall(component: Component): void {
    if (component === 'antivirus') {
      fs.rmSync(path.join(this.home, 'clamav'), { recursive: true, force: true });
      this.writeState((s) => { delete s.antivirus; });
    } else {
      for (const d of ['files-venv', 'python', 'uv']) fs.rmSync(path.join(this.home, d), { recursive: true, force: true });
      this.writeState((s) => { delete s.extractor; });
    }
  }
}
