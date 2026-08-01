import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { DomeRegistry } from '../../../src/registry/domes.js';

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
    const domePath = createDomeDir('SaviaLabs');

    writeDomesFile({
      version: 1,
      defaultDome: 'SaviaLabs',
      domes: {
        SaviaLabs: {
          name: 'SaviaLabs',
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
    expect(domes[0].name).toBe('SaviaLabs');
    expect(domes[0].active).toBe(true);
    expect(domes[0].confidentiality).toBe('N2');
    expect(registry.getDefaultName()).toBe('SaviaLabs');
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
});
