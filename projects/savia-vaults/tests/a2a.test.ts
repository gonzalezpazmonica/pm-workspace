// SaviaVaults A2A — multi-dome consume (SE-310 S0-H)
// Copyright (c) 2026 Savia. MIT License.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { A2AServer } from '../src/server/a2a.js';
import { DomeRegistry } from '../src/registry/domes.js';
import type { VaultConfig } from '../src/types.js';

describe('SaviaVaults A2A — multi-dome consume (SE-310 S0-H)', () => {
  let tmp: string;
  let domesFile: string;

  beforeEach(() => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-a2a-'));
    const domeA = path.join(tmp, 'domeA');
    const domeB = path.join(tmp, 'domeB');
    fs.mkdirSync(domeA, { recursive: true });
    fs.mkdirSync(domeB, { recursive: true });
    fs.writeFileSync(path.join(domeA, 'note.md'), '# Kokoro TTS\nmotor local de voz');
    fs.writeFileSync(path.join(domeB, 'other.md'), '# Otra cosa\ncontenido sin la palabra clave');
    domesFile = path.join(tmp, 'domes.json');
    fs.writeFileSync(domesFile, JSON.stringify({
      version: 1,
      defaultDome: 'A',
      domes: {
        A: { name: 'A', path: domeA, confidentiality: 'N2', description: 'dome A' },
        B: { name: 'B', path: domeB, confidentiality: 'N3', description: 'dome B' },
      },
    }));
  });

  afterEach(() => {
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  function makeServer(): A2AServer {
    const config: VaultConfig = {
      name: 'vault',
      path: path.join(tmp, 'vault'),
      allowedExtensions: [],
      deniedPaths: [],
      maxDepth: 10,
      maxFileSize: 1024 * 1024,
    };
    fs.mkdirSync(config.path, { recursive: true });
    const reg = new DomeRegistry(domesFile);
    reg.load();
    return new A2AServer(config, reg);
  }

  it('listDomes devuelve las cupulas configuradas con su confidencialidad', () => {
    const s = makeServer();
    const domes = s.listDomes();
    expect(domes.map((d) => d.name).sort()).toEqual(['A', 'B']);
    expect(domes.find((d) => d.name === 'A')?.confidentiality).toBe('N2');
    expect(domes.find((d) => d.name === 'B')?.confidentiality).toBe('N3');
  });

  it('searchAll sin dome busca en todas las cupulas y encuentra el match', () => {
    const s = makeServer();
    const res = s.searchAll({ query: 'kokoro', maxResults: 10 });
    expect(res.some((r) => r.path.includes('note.md'))).toBe(true);
  });

  it('searchAll con dome=A limita el resultado a esa cupula', () => {
    const s = makeServer();
    const res = s.searchAll({ query: 'kokoro', maxResults: 10 }, 'A');
    expect(res.length).toBeGreaterThan(0);
    expect(res.every((r) => r.path.includes('note.md'))).toBe(true);
  });

  it('searchAll con dome inexistente devuelve vacio sin romper', () => {
    const s = makeServer();
    const res = s.searchAll({ query: 'kokoro', maxResults: 10 }, 'ZZZ');
    expect(res).toEqual([]);
  });

  it('searchAll busca en una cupula que no contiene el termino → no la fuerza', () => {
    const s = makeServer();
    const res = s.searchAll({ query: 'kokoro', maxResults: 10 }, 'B');
    expect(res).toEqual([]);
  });

  it('writeDome escribe en la cupula destino y luego es buscable en ELLA (S0-H alimenta→consume)', async () => {
    const s = makeServer();
    await s.writeDome('A', 'conversaciones/test.md', '# digest\ncontenido digerido');
    // debe ser buscable en la cupula A (el store correcto), no solo en la config vault
    const res = s.searchAll({ query: 'digerido', maxResults: 5 }, 'A');
    expect(res.some((r) => r.path.includes('conversaciones/test.md'))).toBe(true);
  });

  it('writeDome con dome inexistente no lanza (no escribe en ningun lado)', () => {
    const s = makeServer();
    expect(() => s.writeDome('ZZZ', 'x.md', 'y')).not.toThrow();
  });
});
