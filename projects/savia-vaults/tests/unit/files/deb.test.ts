// SE-416 — lectura de .deb (ar) y extracción de tar.gz sin root, con filtro y sin escapes de ruta
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { execFileSync } from 'node:child_process';
import { readAr, extractTarGz } from '../../../src/files/deb.js';
import { buildAr, buildTarGz } from './fake-artifacts.js';

describe('readAr', () => {
  it('lee los miembros de un .deb', () => {
    const deb = buildAr({ 'debian-binary': Buffer.from('2.0\n'), 'control.tar.gz': Buffer.from('c'), 'data.tar.gz': Buffer.from('datos') });
    const m = readAr(deb);
    expect(m.map((x) => x.name)).toEqual(['debian-binary', 'control.tar.gz', 'data.tar.gz']);
    expect(m[2].data.toString()).toBe('datos');
  });

  it('rechaza lo que no es ar', () => {
    expect(() => readAr(Buffer.from('no soy un deb'))).toThrow(/ar/);
  });
});

describe('extractTarGz', () => {
  let dir: string;
  beforeEach(() => { dir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-deb-')); });
  afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

  it('extrae ficheros, modos y symlinks relativos, y aplica el filtro', () => {
    const tgz = buildTarGz(dir, {
      'usr/local/bin/clamscan': { content: '#!/bin/sh\necho hola\n', mode: 0o755 },
      'usr/local/lib/libclamav.so.12.1.0': { content: 'lib' },
      'usr/local/lib/libclamav.so.12': { symlink: 'libclamav.so.12.1.0' },
      'usr/local/lib/libclamav_rust.a': { content: 'grande' },
      'usr/local/include/clamav.h': { content: 'h' },
    });
    const out = path.join(dir, 'out');
    const n = extractTarGz(tgz, out, (p) => /^usr\/local\/(bin\/clamscan|lib\/lib[^/]*\.so[^/]*)$/.test(p) ? p.replace(/^usr\/local\//, '') : undefined);
    expect(n).toBe(3);
    expect(fs.statSync(path.join(out, 'bin/clamscan')).mode & 0o111).not.toBe(0);
    expect(fs.readlinkSync(path.join(out, 'lib/libclamav.so.12'))).toBe('libclamav.so.12.1.0');
    expect(fs.existsSync(path.join(out, 'lib/libclamav_rust.a'))).toBe(false);
    expect(fs.existsSync(path.join(out, 'include'))).toBe(false);
    expect(execFileSync(path.join(out, 'bin/clamscan')).toString()).toBe('hola\n');
  });

  it('rechaza rutas que escapan del destino y symlinks hacia fuera', () => {
    const evil = buildTarGz(dir, { 'ok.txt': { content: 'x' } }, ['../fuera.txt']);
    expect(() => extractTarGz(evil, path.join(dir, 'o1'), (p) => p)).toThrow(/ruta no válida/);
    const link = buildTarGz(dir, { 'lib/escape': { symlink: '../../../etc/passwd' } });
    expect(() => extractTarGz(link, path.join(dir, 'o2'), (p) => p)).toThrow(/symlink/);
    expect(fs.existsSync(path.join(dir, 'fuera.txt'))).toBe(false);
  });

  it('nombres largos (GNU/PAX) se leen enteros', () => {
    const long = `usr/local/lib/${'x'.repeat(120)}.so`;
    const tgz = buildTarGz(dir, { [long]: { content: 'largo' } });
    const out = path.join(dir, 'out');
    extractTarGz(tgz, out, (p) => p);
    expect(fs.readFileSync(path.join(out, long), 'utf-8')).toBe('largo');
  });
});
