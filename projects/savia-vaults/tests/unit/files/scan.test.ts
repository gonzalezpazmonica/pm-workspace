// SE-413 F2 — escaneo antivirus opcional (clamscan)
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { scanFile } from '../../../src/files/scan.js';

describe('scanFile', () => {
  let dir: string;
  beforeEach(() => { dir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-scan-')); });
  afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

  const fakeScanner = (exit: number, out = '') => {
    const f = path.join(dir, 'clamscan');
    fs.writeFileSync(f, `#!/bin/sh\necho "$2: ${out}"\nexit ${exit}\n`, { mode: 0o700 });
    return f;
  };

  it('off no escanea; auto sin escáner no escanea; required sin escáner falla', async () => {
    const f = path.join(dir, 'a.txt');
    fs.writeFileSync(f, 'x');
    expect((await scanFile(f, { mode: 'off' })).verdict).toBe('skipped');
    expect((await scanFile(f, { mode: 'auto', clamscan: path.join(dir, 'no-existe') })).verdict).toBe('skipped');
    await expect(scanFile(f, { mode: 'required', clamscan: path.join(dir, 'no-existe') })).rejects.toThrow(/SCAN_REQUIRED/);
  });

  it('exit 0 limpio, exit 1 infectado con firma, otro exit error', async () => {
    const f = path.join(dir, 'a.txt');
    fs.writeFileSync(f, 'x');
    expect((await scanFile(f, { mode: 'auto', clamscan: fakeScanner(0, 'OK') })).verdict).toBe('clean');
    const inf = await scanFile(f, { mode: 'auto', clamscan: fakeScanner(1, 'Eicar-Signature FOUND') });
    expect(inf).toMatchObject({ verdict: 'infected', signature: 'Eicar-Signature' });
    await expect(scanFile(f, { mode: 'required', clamscan: fakeScanner(2, 'ERROR') })).rejects.toThrow(/SCAN_REQUIRED/);
    expect((await scanFile(f, { mode: 'auto', clamscan: fakeScanner(2, 'ERROR') })).verdict).toBe('error');
  });
});
