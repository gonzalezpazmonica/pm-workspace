// SE-418 — ledger git privado por cúpula: repo local sin remoto ni hooks, manifiestos canónicos,
// intents y tombstones, un commit por operación, y lectura de intents para reconstruir el journal.
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { execFileSync } from 'node:child_process';
import { Ledger, type LedgerManifest } from '../../../src/files/ledger.js';
import { canonicalJson } from '../../../src/files/crypto.js';

const manifest = (id: string, metaHash = 'a'.repeat(64)): LedgerManifest => ({
  schemaVersion: 1, documentId: id, currentRevision: 'r_0000000000000001', metaHash,
  revisions: [{ revisionId: 'r_0000000000000001', blob: 'b'.repeat(64), size: 3, type: 'txt', extraction: { status: 'READY' } }],
});
const F1 = 'f_0000000000000001';
const git = (dir: string, ...args: string[]) => execFileSync('git', ['-C', dir, ...args], { encoding: 'utf-8' }).trim();

describe('Ledger', () => {
  let dome: string;
  let l: Ledger;
  beforeEach(() => {
    dome = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-ledger-'));
    l = new Ledger(dome);
  });
  afterEach(() => fs.rmSync(dome, { recursive: true, force: true }));

  it('init: repo 0700 sin remoto, hooks desactivados e identidad propia; idempotente', () => {
    expect(l.exists()).toBe(false);
    l.init();
    l.init();
    expect(l.exists()).toBe(true);
    expect(fs.statSync(l.dir).mode & 0o777).toBe(0o700);
    expect(git(l.dir, 'remote')).toBe('');
    expect(git(l.dir, 'config', 'core.hooksPath')).toBe('/dev/null');
    expect(git(l.dir, 'config', 'user.name')).toBe('Savia Files');
  });

  it('un commit por operación con manifiestos + intent; manifiesto en JSON canónico', () => {
    l.init();
    l.writeManifest(manifest(F1));
    l.writeIntent({ operationId: 'o_1', kind: 'put', at: '2026-09-30T00:00:00.000Z', documents: [F1] });
    const sha = l.commit('put o_1');
    expect(sha).toMatch(/^[0-9a-f]{40}$/);
    expect(l.hasCommit(sha)).toBe(true);
    expect(git(l.dir, 'show', '--name-only', '--format=', sha).split('\n').sort()).toEqual(['intents/o_1.json', `manifests/${F1}.json`]);
    const raw = fs.readFileSync(path.join(l.dir, 'manifests', `${F1}.json`), 'utf-8');
    expect(raw).toBe(`${canonicalJson(JSON.parse(raw))}\n`);
    expect(l.readManifest(F1)).toEqual(manifest(F1));
    expect(l.intentCommitted('o_1')).toBe(true);
    expect(l.intentCommitted('o_2')).toBe(false);
  });

  it('borrar: manifiesto fuera y tombstone; la historia conserva el anterior', () => {
    l.init();
    l.writeManifest(manifest(F1));
    l.writeIntent({ operationId: 'o_1', kind: 'put', at: 'x', documents: [F1] });
    l.commit('put');
    l.removeManifest(F1);
    l.writeTombstone({ documentId: F1, deletedAt: 'y', operationId: 'o_2' });
    l.writeIntent({ operationId: 'o_2', kind: 'delete', at: 'y', documents: [F1] });
    l.commit('delete');
    expect(l.readManifest(F1)).toBeUndefined();
    expect(l.manifestIds()).toEqual([]);
    expect(fs.existsSync(path.join(l.dir, 'tombstones', `${F1}.json`))).toBe(true);
  });

  it('intents(): operaciones confirmadas con su commit, para reconstruir el journal', () => {
    l.init();
    for (const [i, op] of ['o_1', 'o_2'].entries()) {
      l.writeManifest(manifest(F1, String(i).repeat(64)));
      l.writeIntent({ operationId: op, kind: 'put', at: `2026-09-30T00:00:0${i}.000Z`, documents: [F1], idempotencyKeyHash: `k${i}` });
      l.commit(op);
    }
    const all = l.intents();
    expect(all.map((i) => i.operationId)).toEqual(['o_1', 'o_2']);
    expect(all[1]).toMatchObject({ kind: 'put', documents: [F1], idemKeyHash: 'k1' });
    expect(l.hasCommit(all[0].commitSha)).toBe(true);
  });

  it('un remoto añadido bloquea (UNSAFE_HOME); un lock de git hace fallar el commit', () => {
    l.init();
    git(l.dir, 'remote', 'add', 'origin', 'https://example.invalid/x.git');
    expect(() => l.assertPrivate()).toThrow(/UNSAFE_HOME/);
    git(l.dir, 'remote', 'remove', 'origin');
    l.assertPrivate();
    fs.writeFileSync(path.join(l.dir, '.git', 'index.lock'), '');
    l.writeIntent({ operationId: 'o_1', kind: 'put', at: 'x', documents: [] });
    expect(() => l.commit('put')).toThrow(/COMMIT_PENDING/);
  });

  it('ignora la configuración global y los GIT_* del entorno (no escribe en otro repo)', () => {
    const other = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-ledger-other-'));
    const saved = process.env.GIT_DIR;
    try {
      git(other, 'init', '-q');
      process.env.GIT_DIR = path.join(other, '.git');
      l.init();
      l.writeIntent({ operationId: 'o_1', kind: 'put', at: 'x', documents: [] });
      l.commit('put');
      const env = { ...process.env };
      delete env.GIT_DIR;
      expect(() => execFileSync('git', ['-C', other, 'rev-parse', 'HEAD'], { stdio: 'pipe', env })).toThrow();
    } finally {
      if (saved === undefined) delete process.env.GIT_DIR; else process.env.GIT_DIR = saved;
      fs.rmSync(other, { recursive: true, force: true });
    }
  });

  it('fsck, status limpio y manifestHash estable', () => {
    l.init();
    l.writeManifest(manifest(F1));
    l.writeIntent({ operationId: 'o_1', kind: 'put', at: 'x', documents: [F1] });
    l.commit('put');
    expect(l.fsck()).toBe(true);
    expect(l.dirty()).toEqual([]);
    const h = l.manifestHash([F1]);
    expect(h).toMatch(/^[0-9a-f]{64}$/);
    expect(l.manifestHash([F1])).toBe(h);
    fs.appendFileSync(path.join(l.dir, 'manifests', `${F1}.json`), ' ');
    expect(l.dirty()).toEqual([`manifests/${F1}.json`]);
    expect(l.manifestHash([F1])).not.toBe(h);
  });
});
