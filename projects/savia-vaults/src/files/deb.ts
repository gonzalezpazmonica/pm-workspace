// SE-416 — lectura de paquetes .deb (formato ar) y extracción de tar.gz en TypeScript,
// sin root ni dpkg: solo lo que pide el filtro y sin escapar del directorio de destino.
import * as fs from 'node:fs';
import * as path from 'node:path';
import { gunzipSync } from 'node:zlib';

export interface ArMember { name: string; data: Buffer }

export function readAr(b: Buffer): ArMember[] {
  if (b.subarray(0, 8).toString('latin1') !== '!<arch>\n') throw new Error('no es un archivo ar (.deb)');
  const out: ArMember[] = [];
  let p = 8;
  while (p + 60 <= b.length) {
    const name = b.toString('latin1', p, p + 16).trim().replace(/\/$/, '');
    const size = Number(b.toString('latin1', p + 48, p + 58).trim());
    if (!Number.isFinite(size) || p + 60 + size > b.length) throw new Error('archivo ar truncado');
    out.push({ name, data: b.subarray(p + 60, p + 60 + size) });
    p += 60 + size + (size % 2);
  }
  return out;
}

/** Ruta relativa segura: sin `..`, sin absolutas; normalizada con `/`. */
function safeRelative(name: string): string {
  const clean = name.replace(/^\.\//, '').replace(/\/+$/, '');
  const norm = path.posix.normalize(clean);
  if (!clean || path.posix.isAbsolute(clean) || norm === '..' || norm.startsWith('../') || norm.split('/').includes('..')) {
    throw new Error(`ruta no válida en el paquete: ${name}`);
  }
  return norm;
}

const octal = (b: Buffer, start: number, len: number) => parseInt(b.toString('latin1', start, start + len).replace(/\0.*$/, '').trim() || '0', 8);
const cstr = (b: Buffer, start: number, len: number) => b.toString('utf-8', start, start + len).replace(/\0.*$/s, '');

/**
 * Extrae un tar.gz. `select(ruta)` devuelve la ruta de destino (relativa a `dest`) o
 * `undefined` para omitir la entrada. Ficheros y symlinks relativos que no salen del
 * destino; directorios implícitos. Devuelve cuántas entradas se extrajeron.
 */
export function extractTarGz(tgz: Buffer, dest: string, select: (p: string) => string | undefined): number {
  const tar = gunzipSync(tgz);
  fs.mkdirSync(dest, { recursive: true, mode: 0o700 });
  const root = path.resolve(dest);
  let p = 0;
  let longName: string | undefined;
  let longLink: string | undefined;
  let count = 0;
  while (p + 512 <= tar.length) {
    const h = tar.subarray(p, p + 512);
    if (h.every((x) => x === 0)) break;
    const size = octal(h, 124, 12);
    const type = String.fromCharCode(h[156] || 0x30);
    const data = tar.subarray(p + 512, p + 512 + size);
    p += 512 + Math.ceil(size / 512) * 512;
    if (type === 'L') { longName = cstr(data, 0, data.length); continue; }
    if (type === 'K') { longLink = cstr(data, 0, data.length); continue; }
    if (type === 'x' || type === 'g') {
      // PAX: "<len> clave=valor\n"
      for (const rec of data.toString('utf-8').split('\n')) {
        const m = /^\d+ (path|linkpath)=(.*)$/.exec(rec);
        if (m && type === 'x') { if (m[1] === 'path') longName = m[2]; else longLink = m[2]; }
      }
      continue;
    }
    const prefix = cstr(h, 345, 155);
    const name = longName ?? (prefix ? `${prefix}/${cstr(h, 0, 100)}` : cstr(h, 0, 100));
    const link = longLink ?? cstr(h, 157, 100);
    longName = longLink = undefined;
    const rel = safeRelative(name);
    if (type === '5') continue; // directorios: se crean cuando hace falta
    const target = select(rel);
    if (target === undefined) continue;
    const out = path.resolve(root, safeRelative(target));
    if (!out.startsWith(root + path.sep)) throw new Error(`ruta no válida en el paquete: ${name}`);
    fs.mkdirSync(path.dirname(out), { recursive: true, mode: 0o700 });
    if (type === '2') {
      const resolved = path.resolve(path.dirname(out), link);
      if (path.isAbsolute(link) || !resolved.startsWith(root + path.sep)) throw new Error(`symlink fuera del destino: ${name} -> ${link}`);
      fs.rmSync(out, { force: true });
      fs.symlinkSync(link, out);
    } else if (type === '0' || type === '\0' || type === '7') {
      fs.writeFileSync(out, data, { mode: (octal(h, 100, 8) & 0o755) | 0o600 });
    } else {
      continue; // enlaces duros, dispositivos, FIFOs: no se necesitan
    }
    count++;
  }
  return count;
}
