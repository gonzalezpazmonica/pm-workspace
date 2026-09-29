// SE-410 P3/P7 — CLI `rag sync --all --check`: disparador programado (cron) sin script aparte
import { afterEach, describe, expect, it } from 'vitest';
import { spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { pathToFileURL } from 'node:url';

const folders: string[] = [];
afterEach(() => { for (const f of folders.splice(0)) fs.rmSync(f, { recursive: true, force: true }); });

function setup() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-cli-rag-'));
  folders.push(root);
  const domes: Record<string, unknown> = {};
  for (const name of ['a', 'b']) {
    const folder = path.join(root, name);
    fs.mkdirSync(folder);
    fs.writeFileSync(path.join(folder, `${name}.md`), `# ${name}\n\n${'contenido de prueba para el índice. '.repeat(10)}`);
    domes[name] = { name, path: folder, description: '', confidentiality: 'N2', rag: { enabled: true } };
  }
  const registry = path.join(root, 'domes.json');
  fs.writeFileSync(registry, JSON.stringify({ version: 1, defaultDome: 'a', domes }));
  const home = path.join(root, 'rag-home');
  const run = (...args: string[]) => spawnSync(process.execPath, [
    '--import', pathToFileURL(path.resolve('node_modules/tsx/dist/loader.mjs')).href,
    path.resolve('src/cli/index.ts'), 'rag', ...args, '--domes-file', registry,
  ], { env: { PATH: process.env.PATH || '', SAVIA_RAG_HOME: home, SAVIA_RAG_TEST_PROVIDER: 'hash' }, encoding: 'utf-8', timeout: 30000 });
  return { root, home, run };
}

describe('SE-410 CLI rag sync --all --check', () => {
  it('sincroniza todas las cúpulas y sale 0 con el SLO en verde', () => {
    const { run } = setup();
    const r = run('sync', '--all', '--check');
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('[a]');
    expect(r.stdout).toContain('[b]');
  }, 30000);

  it('status --check sale 2 si una cúpula habilitada no tiene generación', () => {
    const { run } = setup();
    expect(run('status', '--check').status).toBe(2);
    run('sync', '--all');
    expect(run('status', '--check').status).toBe(0);
  }, 30000);

  it('un lock ajeno no es fallo: se omite esa cúpula y sigue con el resto', () => {
    const { run, home } = setup();
    fs.mkdirSync(path.join(home, 'a'), { recursive: true });
    fs.writeFileSync(path.join(home, 'a', 'sync.lock'), JSON.stringify({ pid: process.pid, ts: Date.now() }));
    const r = run('sync', '--all');
    expect(r.status).toBe(0);
    expect(r.stdout).toContain('[a] sync en curso en otro proceso');
    expect(r.stdout).toContain('[b] gen=');
  }, 30000);

  it('con --check tras un sync parcial el SLO falla (exit 2)', () => {
    const { run, home } = setup();
    fs.mkdirSync(path.join(home, 'a'), { recursive: true });
    fs.writeFileSync(path.join(home, 'a', 'sync.lock'), JSON.stringify({ pid: process.pid, ts: Date.now() }));
    expect(run('sync', '--all', '--check').status).toBe(2);
  }, 30000);

  it('sin --dome ni --all falla con INVALID_INPUT', () => {
    const { run } = setup();
    const r = run('sync');
    expect(r.status).toBe(1);
    expect(r.stderr).toContain('INVALID_INPUT');
  }, 30000);
});
