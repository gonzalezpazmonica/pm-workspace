// Helpers de tests SE-416: .deb (ar), tar.gz con el tar del sistema, y artefactos falsos
// de uv y ClamAV servidos por un servidor HTTP local (sin red).
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as http from 'node:http';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import type { AddressInfo } from 'node:net';

export function buildAr(members: Record<string, Buffer>): Buffer {
  const parts: Buffer[] = [Buffer.from('!<arch>\n')];
  for (const [name, data] of Object.entries(members)) {
    const h = Buffer.alloc(60, ' ');
    h.write(name.padEnd(16), 0);
    h.write('0'.padEnd(12), 16);
    h.write('0'.padEnd(6), 28);
    h.write('0'.padEnd(6), 34);
    h.write('100644'.padEnd(8), 40);
    h.write(String(data.length).padEnd(10), 48);
    h.write('`\n', 58);
    parts.push(h, data);
    if (data.length % 2) parts.push(Buffer.from('\n'));
  }
  return Buffer.concat(parts);
}

type Entry = { content?: string; mode?: number; symlink?: string };

/** tar.gz real (GNU tar del sistema). `raw` añade entradas con nombres literales (p. ej. `../x`). */
export function buildTarGz(work: string, entries: Record<string, Entry>, raw: string[] = []): Buffer {
  const root = fs.mkdtempSync(path.join(work, 'tar-'));
  for (const [p, e] of Object.entries(entries)) {
    const f = path.join(root, p);
    fs.mkdirSync(path.dirname(f), { recursive: true });
    if (e.symlink) fs.symlinkSync(e.symlink, f);
    else fs.writeFileSync(f, e.content ?? '', { mode: e.mode ?? 0o644 });
  }
  const out = path.join(work, `${path.basename(root)}.tar.gz`);
  const args = ['-czf', out, '-C', root, ...Object.keys(entries)];
  if (raw.length) {
    for (const r of raw) fs.writeFileSync(path.join(root, path.basename(r)), 'fuera');
    args.push(...raw.map((r) => `--transform=s|^${path.basename(r)}$|${r}|`), ...raw.map((r) => path.basename(r)));
    args.splice(args.indexOf('-C'), 0, '-P');
  }
  execFileSync('tar', args);
  return fs.readFileSync(out);
}

export const sha256 = (b: Buffer) => createHash('sha256').update(b).digest('hex');

/** Paquete .deb falso de ClamAV: clamscan detecta "EICAR" y freshclam escribe firmas. */
export function fakeClamavDeb(work: string): Buffer {
  const clamscan = `#!/bin/sh
# comprueba que el instalador pasa entorno y base de firmas
[ -n "$CVD_CERTS_DIR" ] || { echo "sin CVD_CERTS_DIR"; exit 2; }
case "$LD_LIBRARY_PATH" in *clamav*) ;; *) echo "sin LD_LIBRARY_PATH"; exit 2;; esac
db=""; code=0
for a in "$@"; do case "$a" in --database=*) db="\${a#--database=}";; esac; done
[ -f "$db/daily.cvd" ] || { echo "sin firmas"; exit 2; }
for a in "$@"; do
  case "$a" in --*) continue;; esac
  if grep -q EICAR "$a" 2>/dev/null; then echo "$a: Eicar-Test-Signature FOUND"; code=1; else echo "$a: OK"; fi
done
exit $code
`;
  const freshclam = `#!/bin/sh
conf=""; for a in "$@"; do case "$a" in --config-file=*) conf="\${a#--config-file=}";; esac; done
db=$(sed -n 's/^DatabaseDirectory //p' "$conf")
[ -n "$FAKE_FRESHCLAM_FAIL" ] && exit 1
echo firmas > "$db/daily.cvd"
echo "$(date +%s)" >> "$db/.updates"
exit 0
`;
  const tgz = buildTarGz(work, {
    'usr/local/bin/clamscan': { content: clamscan, mode: 0o755 },
    'usr/local/bin/freshclam': { content: freshclam, mode: 0o755 },
    'usr/local/bin/sigtool': { content: 'no', mode: 0o755 },
    'usr/local/lib/libclamav.so.12.1.0': { content: 'lib' },
    'usr/local/lib/libclamav.so.12': { symlink: 'libclamav.so.12.1.0' },
    'usr/local/lib/libclamav_rust.a': { content: 'estática' },
    'usr/local/etc/certs/clamav.crt': { content: 'cert' },
    'usr/local/include/clamav.h': { content: 'h' },
  });
  return buildAr({ 'debian-binary': Buffer.from('2.0\n'), 'control.tar.gz': buildTarGz(work, { control: { content: 'x' } }), 'data.tar.gz': tgz });
}

/** uv falso: `venv <dir>` crea un python que acepta `-c`; `pip sync` deja una marca. */
export function fakeUvTarGz(work: string): Buffer {
  const uv = `#!/bin/sh
cmd="$1"; shift
if [ "$cmd" = "venv" ]; then
  dir="$1"; mkdir -p "$dir/bin"
  printf '#!/bin/sh\\n[ -f "$(dirname "$0")/../.synced" ] || exit 1\\nexit 0\\n' > "$dir/bin/python"; chmod +x "$dir/bin/python"
  exit 0
fi
if [ "$cmd" = "pip" ] && [ "$1" = "sync" ]; then
  [ -n "$FAKE_UV_FAIL" ] && exit 1
  py=""; while [ $# -gt 0 ]; do [ "$1" = "--python" ] && py="$2"; shift; done
  touch "$(dirname "$(dirname "$py")")/.synced"; exit 0
fi
if [ "$cmd" = "cache" ]; then exit 0; fi
echo "uv falso: $cmd"; exit 2
`;
  return buildTarGz(work, { 'uv-x86_64-unknown-linux-gnu/uv': { content: uv, mode: 0o755 } });
}

export interface FakeServer { url: string; hits: Map<string, number>; close: () => Promise<void>; breakPath?: string }

/** Servidor local; `/rota/...` corta la conexión a mitad del cuerpo. */
export async function serve(files: Record<string, Buffer>): Promise<FakeServer> {
  const hits = new Map<string, number>();
  const server = http.createServer((req, res) => {
    const p = req.url ?? '';
    hits.set(p, (hits.get(p) ?? 0) + 1);
    const key = p.replace(/^\/rota/, '');
    const body = files[key];
    if (!body) { res.statusCode = 404; res.end(); return; }
    res.setHeader('content-length', String(body.length));
    if (p.startsWith('/rota')) { res.write(body.subarray(0, Math.floor(body.length / 2))); res.destroy(); return; }
    res.end(body);
  });
  await new Promise<void>((r) => server.listen(0, '127.0.0.1', r));
  const { port } = server.address() as AddressInfo;
  return { url: `http://127.0.0.1:${port}`, hits, close: () => new Promise<void>((r) => server.close(() => r())) };
}
