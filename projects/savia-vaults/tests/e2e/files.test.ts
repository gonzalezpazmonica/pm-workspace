// SE-413 — e2e de la CLI `savia-vaults files add|list|show|text|get|rm|reprocess|gc` (src/cli/files.ts)
import { afterEach, describe, expect, it } from 'vitest';
import { spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { pathToFileURL } from 'node:url';

const folders: string[] = [];
afterEach(() => { for (const f of folders.splice(0)) fs.rmSync(f, { recursive: true, force: true }); });

function setup(files: Record<string, unknown> = { enabled: true, scan: 'off' }) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-cli-files-'));
  folders.push(root);
  const folder = path.join(root, 'd');
  fs.mkdirSync(folder);
  const registry = path.join(root, 'domes.json');
  fs.writeFileSync(registry, JSON.stringify({
    version: 1, defaultDome: 'd',
    domes: { d: { name: 'd', path: folder, description: '', confidentiality: 'N2', rag: { enabled: true }, files } },
  }));
  const run = (...args: string[]) => spawnSync(process.execPath, [
    '--import', pathToFileURL(path.resolve('node_modules/tsx/dist/loader.mjs')).href,
    path.resolve('src/cli/index.ts'), 'files', ...args, '--domes-file', registry,
  ], {
    env: {
      PATH: process.env.PATH || '', HOME: root, SAVIA_FILES_HOME: path.join(root, 'files-home'), SAVIA_FILES_KEYS_HOME: path.join(root, 'keys'),
      SAVIA_RAG_HOME: path.join(root, 'rag'), SAVIA_RAG_TEST_PROVIDER: 'hash',
    },
    encoding: 'utf-8', timeout: 30000,
  });
  return { root, run };
}

describe('SE-413 CLI files', () => {
  it('add → list → show → text → get → rm', () => {
    const { root, run } = setup();
    const src = path.join(root, 'notas.md');
    fs.writeFileSync(src, '# Acta\n\nSe aprueba migrar los backups al NAS.\n');
    const add = run('add', src, '--dome', 'd', '--tags', 'acta,backup', '--json');
    expect(add.status, add.stderr).toBe(0);
    const [doc] = JSON.parse(add.stdout);
    expect(doc).toMatchObject({ name: 'notas.md', status: 'READY' });

    const list = run('list', '--dome', 'd');
    expect(list.stdout).toContain(doc.documentId);
    expect(list.stdout).toContain('READY');

    const show = JSON.parse(run('show', doc.documentId, '--dome', 'd').stdout);
    expect(show.tags).toEqual(['acta', 'backup']);

    const text = run('text', doc.documentId, '--dome', 'd');
    expect(text.stdout).toContain('[línea 3] Se aprueba');
    expect(text.stdout).toContain('migrar los backups');

    const out = path.join(root, 'copia.md');
    expect(run('get', doc.documentId, '--dome', 'd', '-o', out).status).toBe(0);
    expect(fs.readFileSync(out, 'utf-8')).toBe(fs.readFileSync(src, 'utf-8'));
    const again = run('get', doc.documentId, '--dome', 'd', '-o', out);
    expect(again.status).toBe(1);
    expect(again.stderr).toContain('ya existe');

    // SE-418: verify y log del ledger desde la CLI
    const verify = run('verify', '--dome', 'd', '--deep');
    expect(verify.status, verify.stderr).toBe(0);
    expect(verify.stdout).toMatch(/^OK: 1 documentos/);
    expect(run('log', '--dome', 'd').stdout).toMatch(/o_[0-9a-f]{16}\s+put\s+committed/);

    expect(run('rm', doc.documentId, '--dome', 'd').status).toBe(0);
    const gone = run('show', doc.documentId, '--dome', 'd');
    expect(gone.status).toBe(1);
    expect(gone.stderr).toContain('NOT_FOUND');
  }, 60000);

  it('las rutas del fichero de origen no llegan al nombre guardado', () => {
    const { root, run } = setup();
    fs.mkdirSync(path.join(root, 'sub'));
    const src = path.join(root, 'sub', 'a.txt');
    fs.writeFileSync(src, 'x');
    const [doc] = JSON.parse(run('add', src, '--dome', 'd', '--json').stdout);
    expect(doc.name).toBe('a.txt');
  }, 30000);

  it('cúpula sin files habilitado sale con error DISABLED', () => {
    const { root, run } = setup({ enabled: false });
    const src = path.join(root, 'a.txt');
    fs.writeFileSync(src, 'x');
    const r = run('add', src, '--dome', 'd');
    expect(r.status).toBe(1);
    expect(r.stderr).toContain('DISABLED');
  }, 30000);

  it('SE-416: files status explica en lenguaje llano qué falta, sin registro de cúpulas', () => {
    const { root, run } = setup();
    const r = spawnSync(process.execPath, [
      '--import', pathToFileURL(path.resolve('node_modules/tsx/dist/loader.mjs')).href,
      path.resolve('src/cli/index.ts'), 'files', 'status',
    ], { env: { PATH: process.env.PATH || '', HOME: root, SAVIA_TOOLS_HOME: path.join(root, 'tools') }, encoding: 'utf-8', timeout: 30000 });
    void run;
    expect(r.status, r.stderr).toBe(0);
    expect(r.stdout).toMatch(/Lector de documentos|lector de documentos/);
    expect(r.stdout).toMatch(/antivirus/i);
    expect(r.stdout).toMatch(/files setup/);
  }, 30000);

  it('SE-417: cúpula N3 cifrada, fichero de recuperación y restauración de claves desde la CLI', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-cli-enc-'));
    folders.push(root);
    fs.mkdirSync(path.join(root, 'd'));
    const registry = path.join(root, 'domes.json');
    fs.writeFileSync(registry, JSON.stringify({ version: 1, defaultDome: 'd', domes: { d: { name: 'd', path: path.join(root, 'd'), description: '', confidentiality: 'N3', files: { enabled: true, scan: 'off' } } } }));
    const env = (keys: string) => ({ PATH: process.env.PATH || '', HOME: root, SAVIA_FILES_HOME: path.join(root, 'files'), SAVIA_FILES_KEYS_HOME: keys, SAVIA_RAG_HOME: path.join(root, 'rag'), SAVIA_RAG_TEST_PROVIDER: 'hash' });
    const cli = (keys: string, ...args: string[]) => spawnSync(process.execPath, [
      '--import', pathToFileURL(path.resolve('node_modules/tsx/dist/loader.mjs')).href, path.resolve('src/cli/index.ts'), 'files', ...args,
    ], { env: env(keys), encoding: 'utf-8', timeout: 60000 });
    const keys = path.join(root, 'keys');
    const src = path.join(root, 'secreto.txt');
    fs.writeFileSync(src, 'albatros-7731');
    const add = cli(keys, 'add', src, '--dome', 'd', '--domes-file', registry, '--json');
    expect(add.status, add.stderr).toBe(0);
    const [doc] = JSON.parse(add.stdout);
    expect(fs.existsSync(path.join(root, 'files', 'd', 'encryption.json'))).toBe(true);

    const rec = path.join(root, 'recuperacion');
    const exp = cli(keys, 'keys', 'export', '--dir', rec);
    expect(exp.status, exp.stderr).toBe(0);
    const phrase = fs.readFileSync(path.join(rec, 'frase-de-recuperacion.txt'), 'utf-8').trim();
    expect(exp.stdout).not.toContain(phrase);
    const backup = path.join(root, 'claves.sealed');
    expect(cli(keys, 'keys', 'backup', '--out', backup).status).toBe(0);

    // Disco perdido: claves nuevas vacías, se restauran con fichero + frase + copia sellada
    const restored = path.join(root, 'keys-restauradas');
    const phraseFile = path.join(rec, 'frase-de-recuperacion.txt');
    const imp = cli(restored, 'keys', 'import', path.join(rec, 'savia-claves.recovery'), '--phrase-file', phraseFile, '--backup', backup);
    expect(imp.status, imp.stderr).toBe(0);
    const out = path.join(root, 'copia.txt');
    const get = cli(restored, 'get', doc.documentId, '--dome', 'd', '--domes-file', registry, '-o', out);
    expect(get.status, get.stderr).toBe(0);
    expect(fs.readFileSync(out, 'utf-8')).toBe('albatros-7731');
  }, 120000);
});

