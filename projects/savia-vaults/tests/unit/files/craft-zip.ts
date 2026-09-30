// Helper de tests SE-414: ZIP sintético con tamaños declarados a medida (sin descomprimir nada).

/** ZIP mínimo: cabeceras locales + directorio central con los tamaños declarados que se quieran. */
export function craftZip(entries: { name: string; comp: number; uncomp: number; zip64?: boolean }[]): Buffer {
  const locals: Buffer[] = [];
  const cds: Buffer[] = [];
  let offset = 0;
  for (const e of entries) {
    const name = Buffer.from(e.name);
    const lh = Buffer.alloc(30);
    lh.writeUInt32LE(0x04034b50, 0);
    lh.writeUInt16LE(name.length, 26);
    locals.push(lh, name);
    const extra = e.zip64 ? Buffer.alloc(20) : Buffer.alloc(0);
    if (e.zip64) {
      extra.writeUInt16LE(0x0001, 0);
      extra.writeUInt16LE(16, 2);
      extra.writeBigUInt64LE(BigInt(e.uncomp), 4);
      extra.writeBigUInt64LE(BigInt(e.comp), 12);
    }
    const cd = Buffer.alloc(46);
    cd.writeUInt32LE(0x02014b50, 0);
    cd.writeUInt32LE(e.zip64 ? 0xffffffff : e.comp, 20);
    cd.writeUInt32LE(e.zip64 ? 0xffffffff : e.uncomp, 24);
    cd.writeUInt16LE(name.length, 28);
    cd.writeUInt16LE(extra.length, 30);
    cd.writeUInt32LE(offset, 42);
    cds.push(cd, name, extra);
    offset += 30 + name.length;
  }
  const cdBuf = Buffer.concat(cds);
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(entries.length, 8);
  eocd.writeUInt16LE(entries.length, 10);
  eocd.writeUInt32LE(cdBuf.length, 12);
  eocd.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, cdBuf, eocd]);
}
