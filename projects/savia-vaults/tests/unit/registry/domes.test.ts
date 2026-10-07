import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { DomeRegistry, isGitTracked } from '../../../src/registry/domes.js';

describe('DomeRegistry', () => {
  let tmpDir: string;
  let domesFile: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'vaults-test-'));
    domesFile = path.join(tmpDir, 'domes.json');
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  function writeDomesFile(content: object) {
    fs.writeFileSync(domesFile, JSON.stringify(content, null, 2));
  }

  function createDomeDir(name: string) {
    const dir = path.join(tmpDir, name);
    fs.mkdirSync(dir, { recursive: true });
    return dir;
  }

  it('loads valid domes.json with existing paths', () => {
    const domePath = createDomeDir('example-context');

    writeDomesFile({
      version: 1,
      defaultDome: 'example-context',
      domes: {
        'example-context': {
          name: 'example-context',
          path: domePath,
          description: 'Main dome',
          confidentiality: 'N2',
        },
      },
    });

    const registry = new DomeRegistry(domesFile);
    registry.load();

    const domes = registry.list();
    expect(domes).toHaveLength(1);
    expect(domes[0].name).toBe('example-context');
    expect(domes[0].active).toBe(true);
    expect(domes[0].confidentiality).toBe('N2');
    expect(registry.getDefaultName()).toBe('example-context');
  });

  it('marks dome inactive when path does not exist', () => {
    const nonexistentPath = path.join(tmpDir, 'nonexistent');

    writeDomesFile({
      version: 1,
      defaultDome: 'Ghost',
      domes: {
        Ghost: {
          name: 'Ghost',
          path: nonexistentPath,
          description: 'Dead dome',
          confidentiality: 'N1',
        },
      },
    });

    const registry = new DomeRegistry(domesFile);
    registry.load();

    const domes = registry.list();
    expect(domes).toHaveLength(1);
    expect(domes[0].active).toBe(false);
    expect(domes[0].name).toBe('Ghost');
  });

  it('listActive() returns only active domes', () => {
    const activePath = createDomeDir('Active');
    const inactivePath = path.join(tmpDir, 'Inactive');

    writeDomesFile({
      version: 1,
      defaultDome: 'Active',
      domes: {
        Active: { name: 'Active', path: activePath, description: '', confidentiality: 'N1' },
        Inactive: { name: 'Inactive', path: inactivePath, description: '', confidentiality: 'N1' },
      },
    });

    const registry = new DomeRegistry(domesFile);
    registry.load();

    expect(registry.listActive()).toHaveLength(1);
    expect(registry.listActive()[0].name).toBe('Active');
  });

  it('get() returns dome by name', () => {
    const domePath = createDomeDir('TestDome');
    writeDomesFile({
      version: 1,
      defaultDome: 'TestDome',
      domes: {
        TestDome: { name: 'TestDome', path: domePath, description: 'test', confidentiality: 'N3' },
      },
    });

    const registry = new DomeRegistry(domesFile);
    registry.load();

    expect(registry.get('TestDome')?.confidentiality).toBe('N3');
    expect(registry.get('NoSuchDome')).toBeUndefined();
  });

  it('throws on malformed JSON', () => {
    fs.writeFileSync(domesFile, 'not valid json {{{');

    const registry = new DomeRegistry(domesFile);
    expect(() => registry.load()).toThrow('Invalid JSON');
  });

  it('throws on missing version or domes field', () => {
    writeDomesFile({ defaultDome: 'x' });

    const registry = new DomeRegistry(domesFile);
    expect(() => registry.load()).toThrow('Invalid domes file structure');
  });

  it('add() and save() round-trip', () => {
    const domePath = createDomeDir('Existing');
    writeDomesFile({
      version: 1,
      defaultDome: 'Existing',
      domes: {
        Existing: { name: 'Existing', path: domePath, description: '', confidentiality: 'N1' },
      },
    });

    const registry = new DomeRegistry(domesFile);
    registry.load();

    const newPath = createDomeDir('NewDome');
    registry.add({
      name: 'NewDome',
      path: newPath,
      description: 'Newly added',
      confidentiality: 'N2',
      active: true,
    });
    registry.save();

    // Reload and verify
    const registry2 = new DomeRegistry(domesFile);
    registry2.load();
    const domes = registry2.list();
    expect(domes).toHaveLength(2);
    expect(registry2.get('NewDome')?.description).toBe('Newly added');
  });

  it('setDefault() updates and persists', () => {
    const aPath = createDomeDir('Alpha');
    const bPath = createDomeDir('Beta');
    writeDomesFile({
      version: 1,
      defaultDome: 'Alpha',
      domes: {
        Alpha: { name: 'Alpha', path: aPath, description: '', confidentiality: 'N1' },
        Beta: { name: 'Beta', path: bPath, description: '', confidentiality: 'N1' },
      },
    });

    const registry = new DomeRegistry(domesFile);
    registry.load();

    registry.setDefault('Beta');
    expect(registry.defaultDome).toBe('Beta');

    const registry2 = new DomeRegistry(domesFile);
    registry2.load();
    expect(registry2.defaultDome).toBe('Beta');
  });

  it('remove() deletes dome from registry', () => {
    const aPath = createDomeDir('Alpha');
    const bPath = createDomeDir('Beta');
    writeDomesFile({
      version: 1,
      defaultDome: 'Alpha',
      domes: {
        Alpha: { name: 'Alpha', path: aPath, description: '', confidentiality: 'N1' },
        Beta: { name: 'Beta', path: bPath, description: '', confidentiality: 'N1' },
      },
    });

    const registry = new DomeRegistry(domesFile);
    registry.load();
    registry.remove('Beta');

    expect(registry.list()).toHaveLength(1);
    expect(registry.get('Beta')).toBeUndefined();
  });

  it('throws on invalid confidentiality level', () => {
    const domePath = createDomeDir('BadDome');
    writeDomesFile({
      version: 1,
      defaultDome: 'BadDome',
      domes: {
        BadDome: { name: 'BadDome', path: domePath, description: '', confidentiality: 'N5' },
      },
    });

    const registry = new DomeRegistry(domesFile);
    expect(() => registry.load()).toThrow('Invalid confidentiality level');
  });

  it('throws when file does not exist', () => {
    const registry = new DomeRegistry(path.join(tmpDir, 'nonexistent.json'));
    expect(() => registry.load()).toThrow('Domes file not found');
  });

  it('SE-413: carga, valida y guarda el bloque files', () => {
    const domePath = createDomeDir('F');
    writeDomesFile({
      version: 1, defaultDome: 'F',
      domes: { F: { name: 'F', path: domePath, description: '', confidentiality: 'N2', files: { enabled: true, scan: 'required' } } },
    });
    const registry = new DomeRegistry(domesFile);
    registry.load();
    expect(registry.get('F')?.files).toEqual({ enabled: true, scan: 'required' });
    registry.save();
    expect(JSON.parse(fs.readFileSync(domesFile, 'utf-8')).domes.F.files).toEqual({ enabled: true, scan: 'required' });
  });

  it('SE-413: files.scan desconocido falla al cargar', () => {
    const domePath = createDomeDir('G');
    writeDomesFile({
      version: 1, defaultDome: 'G',
      domes: { G: { name: 'G', path: domePath, description: '', confidentiality: 'N2', files: { enabled: true, scan: 'maybe' } } },
    });
    expect(() => new DomeRegistry(domesFile).load()).toThrow(/files\.scan/);
  });

  it('SE-417: files.encryption se carga y valida (booleano)', () => {
    const domePath = createDomeDir('H');
    writeDomesFile({
      version: 1, defaultDome: 'H',
      domes: { H: { name: 'H', path: domePath, description: '', confidentiality: 'N2', files: { enabled: true, encryption: true } } },
    });
    const r = new DomeRegistry(domesFile);
    r.load();
    expect(r.get('H')?.files).toEqual({ enabled: true, encryption: true });
    writeDomesFile({
      version: 1, defaultDome: 'H',
      domes: { H: { name: 'H', path: domePath, description: '', confidentiality: 'N2', files: { enabled: true, encryption: 'si' } } },
    });
    expect(() => new DomeRegistry(domesFile).load()).toThrow(/files\.encryption/);
  });
});

describe('registro de cúpulas fuera de git', () => {
  const pkgDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');

  it('isGitTracked: true para un fichero versionado, false fuera de un repo', () => {
    expect(isGitTracked(path.join(pkgDir, 'package.json'))).toBe(true);
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'vaults-nogit-'));
    try {
      fs.writeFileSync(path.join(tmp, 'savia-vaults.domes.json'), '{}');
      expect(isGitTracked(path.join(tmp, 'savia-vaults.domes.json'))).toBe(false);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  it('el registro real no está versionado y el ejemplo no lleva rutas absolutas', () => {
    expect(isGitTracked(path.join(pkgDir, 'savia-vaults.domes.json'))).toBe(false);
    const r = spawnSync('git', ['check-ignore', '-q', 'savia-vaults.domes.json'], { cwd: pkgDir });
    expect(r.status).toBe(0);
    const example = JSON.parse(fs.readFileSync(path.join(pkgDir, 'savia-vaults.domes.example.json'), 'utf-8'));
    for (const dome of Object.values(example.domes) as Array<{ path: string }>) {
      expect(path.isAbsolute(dome.path)).toBe(false);
      expect(dome.path).not.toMatch(/^~|\/home\/|\/Users\//);
    }
  });

  it('el ejemplo carga como registro válido', () => {
    const reg = new DomeRegistry(path.join(pkgDir, 'savia-vaults.domes.example.json'));
    expect(() => reg.load()).not.toThrow();
    expect(reg.list().length).toBeGreaterThan(0);
    expect(reg.defaultDome).toBe('example-context');
  });
});

describe('SE-436 D30-2: registro local fusionado con el base', () => {
  let tmpDir: string;
  let base: string;
  let local: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'vaults-local-'));
    base = path.join(tmpDir, 'savia-vaults.domes.json');
    local = path.join(tmpDir, 'savia-vaults.domes.local.json');
  });
  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  const dir = (n: string) => {
    const d = path.join(tmpDir, n);
    fs.mkdirSync(d, { recursive: true });
    return d;
  };
  const file = (p: string, defaultDome: string, domes: Record<string, object>) =>
    fs.writeFileSync(p, JSON.stringify({ version: 1, defaultDome, domes }, null, 2));
  const entry = (name: string, p: string, level = 'N2') => ({ name, path: p, description: '', confidentiality: level });

  it('el fichero local se llama como el base con .local antes de .json', () => {
    expect(path.basename(new DomeRegistry(base).getLocalFilePath())).toBe('savia-vaults.domes.local.json');
  });

  it('fusiona base y local; en un nombre repetido gana el local', () => {
    file(base, 'a', { a: entry('a', dir('a')), b: entry('b', dir('b'), 'N1') });
    file(local, '', { b: entry('b', dir('b2'), 'N2'), c: entry('c', dir('c')) });
    const r = new DomeRegistry(base);
    r.load();
    expect(r.list().map((d) => d.name).sort()).toEqual(['a', 'b', 'c']);
    expect(r.get('b')?.confidentiality).toBe('N2');
    expect(r.get('b')?.path.endsWith('b2')).toBe(true);
    expect(r.defaultDome).toBe('a');
  });

  it('el defaultDome del local manda si lo trae', () => {
    file(base, 'a', { a: entry('a', dir('a')) });
    file(local, 'c', { c: entry('c', dir('c')) });
    const r = new DomeRegistry(base);
    r.load();
    expect(r.defaultDome).toBe('c');
  });

  it('funciona con solo el local, sin fichero base', () => {
    file(local, '', { c: entry('c', dir('c'), 'N1') });
    const r = new DomeRegistry(base);
    r.load();
    expect(r.list().map((d) => d.name)).toEqual(['c']);
  });

  it('sin base ni local sigue fallando', () => {
    expect(() => new DomeRegistry(base).load()).toThrow(/not found/);
  });

  it('un local mal formado falla y no se ignora en silencio', () => {
    file(base, 'a', { a: entry('a', dir('a')) });
    fs.writeFileSync(local, '{no json');
    expect(() => new DomeRegistry(base).load()).toThrow(/Invalid JSON/);
  });

  it('save() devuelve cada cúpula a su fichero: lo local no entra en el base', () => {
    file(base, 'a', { a: entry('a', dir('a')) });
    file(local, '', { c: entry('c', dir('c')) });
    const r = new DomeRegistry(base);
    r.load();
    r.add({ name: 'd', path: dir('d'), description: '', confidentiality: 'N1', active: true });
    r.save();
    const b = JSON.parse(fs.readFileSync(base, 'utf-8'));
    const l = JSON.parse(fs.readFileSync(local, 'utf-8'));
    expect(Object.keys(b.domes).sort()).toEqual(['a', 'd']);
    expect(Object.keys(l.domes)).toEqual(['c']);
  });

  it('las rutas relativas del local se resuelven contra su propio directorio', () => {
    file(base, 'a', { a: entry('a', dir('a')) });
    dir('rel');
    file(local, '', { r: entry('r', 'rel') });
    const r = new DomeRegistry(base);
    r.load();
    expect(r.get('r')?.path).toBe(path.join(tmpDir, 'rel'));
    expect(r.get('r')?.active).toBe(true);
  });
});
