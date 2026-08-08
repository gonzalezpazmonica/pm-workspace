// DomeRegistry path resolution (SE-310 S0-H): relative to the domes file dir
// Copyright (c) 2026 Savia. MIT License.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { DomeRegistry } from '../src/registry/domes.js';

describe('DomeRegistry — resolution relativa al fichero de domes', () => {
  let tmp: string;
  let domesDir: string;

  beforeEach(() => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-domes-'));
    domesDir = path.join(tmp, 'config');
    fs.mkdirSync(domesDir, { recursive: true });
  });

  afterEach(() => {
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  it('resuelve las rutas RELATIVAS al dir del fichero domes.json, no al cwd', () => {
    // contenido real de la cupula en otro lugar, fuera del cwd del proceso
    const vaultReal = path.join(tmp, 'knowledge', 'SaviaLabs');
    fs.mkdirSync(vaultReal, { recursive: true });
    fs.writeFileSync(path.join(vaultReal, 'INDEX.md'), '# SaviaLabs\n');

    // domes.json referenciando la cupula con ruta relativa a EL mismo
    const domesFile = path.join(domesDir, 'savia-vaults.domes.json');
    fs.writeFileSync(domesFile, JSON.stringify({
      version: 1,
      defaultDome: 'SaviaLabs',
      domes: {
        SaviaLabs: { name: 'SaviaLabs', path: '../knowledge/SaviaLabs', confidentiality: 'N2' },
      },
    }));

    // simulamos que el proceso corre desde OTRO cwd (ej. projects/savia-vaults)
    const registry = new DomeRegistry(domesFile);
    registry.load();
    const dome = registry.get('SaviaLabs');
    expect(dome?.active).toBe(true);
    expect(dome?.path).toBe(vaultReal);
  });

  it('marca inactiva una cupula cuya ruta real no existe', () => {
    const domesFile = path.join(domesDir, 'domes.json');
    fs.writeFileSync(domesFile, JSON.stringify({
      version: 1,
      domes: {
        Fantasma: { name: 'Fantasma', path: './no-existe', confidentiality: 'N3' },
      },
    }));
    const registry = new DomeRegistry(domesFile);
    registry.load();
    expect(registry.get('Fantasma')?.active).toBe(false);
  });
});
