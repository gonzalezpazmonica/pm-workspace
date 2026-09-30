// SE-413 F2 / SE-416 — escaneo antivirus opcional con ClamAV. Prefiere el ClamAV gestionado
// por el instalador (sin root, firmas propias); analiza varios ficheros en una sola llamada
// porque cada una carga millones de firmas (~10 s y ~1 GB).
import * as fs from 'node:fs';
import { execFile } from 'node:child_process';
import { FilesError } from './types.js';
import { Tools, STALE_AFTER_H } from './setup.js';

export type ScanMode = 'auto' | 'required' | 'off';

export interface ScanResult {
  verdict: 'clean' | 'infected' | 'skipped' | 'error';
  signature?: string;
  detail?: string;
}

export interface ScanOptions {
  mode: ScanMode;
  /** clamscan explícito (tests o instalación propia); si se da, no se busca otro. */
  clamscan?: string;
  timeoutMs?: number;
  /** Herramientas gestionadas; por defecto las de `~/.savia-vaults/tools`. */
  tools?: Tools;
}

interface Scanner { cmd: string; args: string[]; env?: NodeJS.ProcessEnv; ageHours?: number; tools?: Tools }

function resolveScanner(explicit?: string, tools?: Tools): Scanner | undefined {
  if (explicit) return fs.existsSync(explicit) ? { cmd: explicit, args: [] } : undefined;
  const t = tools ?? new Tools();
  const managed = t.clamav();
  if (managed) return { cmd: managed.clamscan, args: managed.args, env: managed.env, ageHours: managed.signaturesAgeHours, tools: t };
  const cmd = [process.env.SAVIA_FILES_CLAMSCAN, '/usr/bin/clamscan', '/usr/local/bin/clamscan', '/opt/homebrew/bin/clamscan']
    .find((c): c is string => !!c && fs.existsSync(c));
  return cmd ? { cmd, args: [] } : undefined;
}

/** true si hay un clamscan utilizable (explícito, gestionado, SAVIA_FILES_CLAMSCAN o del sistema). */
export function scannerAvailable(explicit?: string, tools?: Tools): boolean {
  return resolveScanner(explicit, tools) !== undefined;
}

/**
 * auto: escanea si hay escáner; required: sin escáner, con error o con firmas de más de
 * 7 días ⇒ SCAN_REQUIRED; off: no escanea. Salida de clamscan: 0 limpio, 1 infectado,
 * otro error. Un resultado por fichero, en orden.
 */
export async function scanFiles(files: string[], opts: ScanOptions): Promise<ScanResult[]> {
  if (!files.length) return [];
  if (opts.mode === 'off') return files.map(() => ({ verdict: 'skipped', detail: 'scan off' }));
  const scanner = resolveScanner(opts.clamscan, opts.tools);
  if (!scanner) {
    if (opts.mode === 'required') throw new FilesError('SCAN_REQUIRED', 'la cúpula exige escaneo y no hay antivirus instalado');
    return files.map(() => ({ verdict: 'skipped', detail: 'sin escáner' }));
  }
  let note: string | undefined;
  if (scanner.ageHours !== undefined) {
    scanner.tools?.maybeRefreshSignatures(); // en segundo plano; no se espera
    if (scanner.ageHours > STALE_AFTER_H) {
      const days = Number.isFinite(scanner.ageHours) ? Math.floor(scanner.ageHours / 24) : undefined;
      note = `firmas de hace ${days ?? 'muchos'} días`;
      if (opts.mode === 'required') {
        throw new FilesError('SCAN_REQUIRED', `el antivirus tiene ${note}: no protege frente a amenazas recientes; actualízalas con files setup`);
      }
    }
  }
  const timeout = opts.timeoutMs ?? 120_000 + 10_000 * files.length;
  return new Promise((resolve, reject) => {
    execFile(scanner.cmd, [...scanner.args, '--no-summary', ...files],
      { timeout, maxBuffer: 4 * 1024 * 1024, encoding: 'utf-8', ...(scanner.env ? { env: scanner.env } : {}) },
      (err, stdout) => {
        const code = err ? (typeof err.code === 'number' ? err.code : -1) : 0;
        if (code !== 0 && code !== 1 && opts.mode === 'required') {
          return reject(new FilesError('SCAN_REQUIRED', `clamscan terminó con código ${code}`));
        }
        const byFile = new Map<string, string>();
        for (const line of String(stdout ?? '').split('\n')) {
          const i = line.lastIndexOf(': ');
          if (i > 0) byFile.set(line.slice(0, i), line.slice(i + 2).trim());
        }
        resolve(files.map((f): ScanResult => {
          const v = byFile.get(f);
          const extra = note ? { detail: note } : {};
          if (v === 'OK') return { verdict: 'clean', ...extra };
          const found = v ? /^(\S+) FOUND$/.exec(v) : null;
          if (found) return { verdict: 'infected', signature: found[1] };
          // Un único fichero sin línea reconocible: decide el código de salida.
          if (files.length === 1 && code === 0) return { verdict: 'clean', ...extra };
          if (files.length === 1 && code === 1) return { verdict: 'infected', signature: /(\S+) FOUND/.exec(String(stdout))?.[1] ?? 'unknown' };
          return { verdict: 'error', detail: `clamscan terminó con código ${code}${v ? `: ${v}` : ''}` };
        }));
      });
  });
}

export async function scanFile(file: string, opts: ScanOptions): Promise<ScanResult> {
  return (await scanFiles([file], opts))[0];
}
