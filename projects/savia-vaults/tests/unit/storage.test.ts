// Unit tests: SaviaVaults storage engine
// Copyright (c) 2026 Savia. MIT License.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { VaultStorage } from '../../src/storage/index.js';
import type { VaultConfig } from '../../src/types.js';

describe('VaultStorage', () => {
  let config: VaultConfig;
  let storage: VaultStorage;
  let vaultPath: string;

  beforeEach(async () => {
    vaultPath = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-vault-test-'));
    config = {
      name: 'test-vault',
      path: vaultPath,
      allowedExtensions: [],
      deniedPaths: [],
      maxDepth: 10,
      maxFileSize: 1024 * 1024,
    };
    storage = new VaultStorage(config);
    await storage.init();
  });

  afterEach(() => {
    if (fs.existsSync(vaultPath)) {
      fs.rmSync(vaultPath, { recursive: true, force: true });
    }
  });

  describe('init', () => {
    it('creates vault directory and INDEX.md', () => {
      expect(fs.existsSync(vaultPath)).toBe(true);
      expect(fs.existsSync(path.join(vaultPath, 'INDEX.md'))).toBe(true);
      expect(fs.existsSync(path.join(vaultPath, 'MAP.md'))).toBe(true);
    });
  });

  describe('read', () => {
    it('reads a note with frontmatter and tags', async () => {
      const content = [
        '---',
        'title: Test Note',
        'tags: [test, example]',
        '---',
        '',
        '# Hello World',
        'This is a #test note.',
      ].join('\n');

      fs.writeFileSync(path.join(vaultPath, 'test.md'), content);

      const note = await storage.read('test.md');
      expect(note.path).toBe('test.md');
      expect(note.name).toBe('test');
      expect(note.frontmatter).toEqual({ title: 'Test Note', tags: ['test', 'example'] });
      expect(note.tags).toEqual(['example', 'test']);
    });

    it('throws on missing note', async () => {
      await expect(storage.read('missing.md')).rejects.toThrow('Note not found');
    });

    it('handles notes without frontmatter', async () => {
      fs.writeFileSync(path.join(vaultPath, 'plain.md'), '# Just content');
      const note = await storage.read('plain.md');
      expect(note.frontmatter).toEqual({});
      expect(note.tags).toEqual([]);
    });
  });

  describe('write', () => {
    it('creates a new note and returns receipt', async () => {
      const receipt = await storage.write('new.md', '# New Note');
      expect(receipt.vault).toBe('test-vault');
      expect(receipt.path).toBe('new.md');
      expect(receipt.contentHash).toBeDefined();
      expect(receipt.signature).toBeDefined();
      expect(fs.existsSync(path.join(vaultPath, 'new.md'))).toBe(true);
    });

    it('updates an existing note', async () => {
      fs.writeFileSync(path.join(vaultPath, 'existing.md'), '# Old');
      const receipt = await storage.write('existing.md', '# Updated', 'update existing');
      expect(fs.readFileSync(path.join(vaultPath, 'existing.md'), 'utf-8')).toBe('# Updated');
    });
  });

  describe('delete', () => {
    it('soft-deletes a note (moves to .trash)', async () => {
      const notePath = path.join(vaultPath, 'todelete.md');
      fs.writeFileSync(notePath, '# Delete me');

      await storage.delete('todelete.md');
      expect(fs.existsSync(notePath)).toBe(false);

      const trashFiles = fs.readdirSync(path.join(vaultPath, '.trash'));
      expect(trashFiles.length).toBeGreaterThan(0);
    });

    it('hard-deletes a note', async () => {
      const notePath = path.join(vaultPath, 'permanent.md');
      fs.writeFileSync(notePath, '# Gone');

      await storage.delete('permanent.md', false);
      expect(fs.existsSync(notePath)).toBe(false);
    });
  });

  describe('list', () => {
    it('lists all notes in vault', async () => {
      fs.mkdirSync(path.join(vaultPath, 'notes'), { recursive: true });
      fs.writeFileSync(path.join(vaultPath, 'root.md'), '# Root');
      fs.writeFileSync(path.join(vaultPath, 'notes', 'child.md'), '# Child');
      fs.writeFileSync(path.join(vaultPath, 'notes', 'other.txt'), '# Text');

      const files = await storage.list();
      expect(files).toContain('root.md');
      expect(files).toContain('notes/child.md');
      expect(files).toContain('notes/other.txt');
      expect(files.every(file => !file.includes('\\'))).toBe(true);
    });
  });

  describe('stats', () => {
    it('returns vault statistics', async () => {
      fs.writeFileSync(path.join(vaultPath, 'a.md'), 'A');
      fs.writeFileSync(path.join(vaultPath, 'b.md'), 'BB');

      const stats = await storage.stats();
      expect(stats.name).toBe('test-vault');
      expect(stats.noteCount).toBe(2);
    });
  });
});
