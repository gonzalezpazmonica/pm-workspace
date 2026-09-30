// SE-414 S1 — guardia de descompresión: lee el directorio central de un ZIP (OOXML)
// sin descomprimir nada y rechaza bombas antes de lanzar el worker de extracción.

export interface ZipLimits {
  maxUnzippedBytes: number;
  /** Razón descomprimido/comprimido máxima para entradas de más de 1 MiB. */
  maxRatio: number;
  maxEntries: number;
}

export interface ZipInspection {
  ok: boolean;
  reason?: string;
  entries: number;
  unzippedBytes: number;
}

const EOCD = 0x06054b50;
const EOCD64_LOCATOR = 0x07064b50;
const EOCD64 = 0x06064b50;
const CDH = 0x02014b50;
const RATIO_MIN_BYTES = 1024 * 1024;
const MAX_U32 = 0xffffffff;

const fail = (reason: string, entries = 0, unzippedBytes = 0): ZipInspection => ({ ok: false, reason, entries, unzippedBytes });

function findEocd(b: Buffer): number {
  const stop = Math.max(0, b.length - 22 - 0xffff);
  for (let i = b.length - 22; i >= stop; i--) if (b.readUInt32LE(i) === EOCD) return i;
  return -1;
}

export function inspectZip(b: Buffer, limits: ZipLimits): ZipInspection {
  if (b.length < 22) return fail('ZIP inválido: demasiado corto');
  const eocd = findEocd(b);
  if (eocd < 0) return fail('ZIP inválido: sin directorio central');
  let entries = b.readUInt16LE(eocd + 10);
  let cdOffset = b.readUInt32LE(eocd + 16);
  if (entries === 0xffff || cdOffset === MAX_U32) {
    const loc = eocd - 20;
    if (loc < 0 || b.readUInt32LE(loc) !== EOCD64_LOCATOR) return fail('ZIP inválido: zip64 sin localizador');
    const rec = Number(b.readBigUInt64LE(loc + 8));
    if (rec + 56 > b.length || b.readUInt32LE(rec) !== EOCD64) return fail('ZIP inválido: registro zip64 fuera de rango');
    entries = Number(b.readBigUInt64LE(rec + 32));
    cdOffset = Number(b.readBigUInt64LE(rec + 48));
  }
  if (entries > limits.maxEntries) return fail(`demasiadas entradas: ${entries} > ${limits.maxEntries}`, entries);
  let p = cdOffset;
  let total = 0;
  for (let i = 0; i < entries; i++) {
    if (p + 46 > b.length || b.readUInt32LE(p) !== CDH) return fail('ZIP inválido: directorio central truncado', entries, total);
    let comp = b.readUInt32LE(p + 20);
    let uncomp = b.readUInt32LE(p + 24);
    const nameLen = b.readUInt16LE(p + 28);
    const extraLen = b.readUInt16LE(p + 30);
    const commentLen = b.readUInt16LE(p + 32);
    if (p + 46 + nameLen + extraLen > b.length) return fail('ZIP inválido: entrada truncada', entries, total);
    const name = b.toString('utf-8', p + 46, p + 46 + nameLen);
    if (comp === MAX_U32 || uncomp === MAX_U32) {
      // Campo extra zip64 (0x0001): tamaños de 8 bytes, solo los que valen 0xFFFFFFFF, en orden.
      let q = p + 46 + nameLen;
      const end = q + extraLen;
      let found = false;
      while (q + 4 <= end) {
        const id = b.readUInt16LE(q);
        const size = b.readUInt16LE(q + 2);
        if (id === 0x0001) {
          let r = q + 4;
          if (uncomp === MAX_U32 && r + 8 <= q + 4 + size) { uncomp = Number(b.readBigUInt64LE(r)); r += 8; }
          if (comp === MAX_U32 && r + 8 <= q + 4 + size) { comp = Number(b.readBigUInt64LE(r)); }
          found = true;
          break;
        }
        q += 4 + size;
      }
      if (!found) return fail(`ZIP inválido: ${name} sin tamaños zip64`, entries, total);
    }
    total += uncomp;
    if (total > limits.maxUnzippedBytes) {
      return fail(`tamaño descomprimido declarado ${total} > límite ${limits.maxUnzippedBytes}`, entries, total);
    }
    if (uncomp > RATIO_MIN_BYTES && uncomp / Math.max(1, comp) > limits.maxRatio) {
      return fail(`razón de compresión ${Math.round(uncomp / Math.max(1, comp))}:1 en ${name} > ${limits.maxRatio}:1`, entries, total);
    }
    p += 46 + nameLen + extraLen + commentLen;
  }
  return { ok: true, entries, unzippedBytes: total };
}
