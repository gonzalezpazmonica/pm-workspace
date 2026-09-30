// SE-413 F2 — escaneo antivirus opcional con clamscan (ClamAV)
import * as fs from 'node:fs';
import { execFile } from 'node:child_process';
import { FilesError } from './types.js';

export type ScanMode = 'auto' | 'required' | 'off';

export interface ScanResult {
  verdict: 'clean' | 'infected' | 'skipped' | 'error';
  signature?: string;
  detail?: string;
}

export interface ScanOptions {
  mode: ScanMode;
  clamscan?: string;
  timeoutMs?: number;
}

function findScanner(explicit?: string): string | undefined {
  const candidates = explicit ? [explicit]
    : [process.env.SAVIA_FILES_CLAMSCAN, '/usr/bin/clamscan', '/usr/local/bin/clamscan', '/opt/homebrew/bin/clamscan'];
  return candidates.find((c): c is string => !!c && fs.existsSync(c));
}

/**
 * auto: escanea si hay escáner; required: sin escáner o con error ⇒ SCAN_REQUIRED;
 * off: no escanea. Código de salida de clamscan: 0 limpio, 1 infectado, otro error.
 */
export function scanFile(file: string, opts: ScanOptions): Promise<ScanResult> {
  if (opts.mode === 'off') return Promise.resolve({ verdict: 'skipped', detail: 'scan off' });
  const scanner = findScanner(opts.clamscan);
  if (!scanner) {
    if (opts.mode === 'required') {
      return Promise.reject(new FilesError('SCAN_REQUIRED', 'la cúpula exige escaneo y no hay clamscan instalado'));
    }
    return Promise.resolve({ verdict: 'skipped', detail: 'sin escáner' });
  }
  return new Promise((resolve, reject) => {
    execFile(scanner, ['--no-summary', file], { timeout: opts.timeoutMs ?? 120_000, maxBuffer: 1024 * 1024 },
      (err, stdout) => {
        const code = err ? (typeof err.code === 'number' ? err.code : -1) : 0;
        if (code === 0) return resolve({ verdict: 'clean' });
        if (code === 1) {
          const m = /:\s*(\S+)\s+FOUND/.exec(stdout);
          return resolve({ verdict: 'infected', signature: m?.[1] ?? 'unknown' });
        }
        const detail = `clamscan terminó con código ${code}`;
        if (opts.mode === 'required') return reject(new FilesError('SCAN_REQUIRED', detail));
        resolve({ verdict: 'error', detail });
      });
  });
}
