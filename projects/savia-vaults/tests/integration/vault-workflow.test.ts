// Integration tests: SaviaVaults end-to-end vault workflow
// Copyright (c) 2026 Savia. MIT License.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { VaultStorage } from '../../src/storage/index.js';
import { SearchEngine } from '../../src/search/index.js';
import { VaultSecurity } from '../../src/security/index.js';
import type { VaultConfig } from '../../src/types.js';

describe('SaviaVaults Integration', () => {
  let config: VaultConfig;
  let storage: VaultStorage;
  let search: SearchEngine;
  let vaultPath: string;

  beforeEach(async () => {
    vaultPath = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-vault-integration-'));
    config = {
      name: 'integration-vault',
      path: vaultPath,
      allowedExtensions: [],
      deniedPaths: [],
      maxDepth: 10,
      maxFileSize: 1024 * 1024,
    };
    storage = new VaultStorage(config);
    search = new SearchEngine(config);
    await storage.init();
  });

  afterEach(() => {
    if (fs.existsSync(vaultPath)) {
      fs.rmSync(vaultPath, { recursive: true, force: true });
    }
  });

  describe('CRUD workflow', () => {
    it('write → read → search → delete cycle', async () => {
      // Write
      const receipt = await storage.write('notes/architecture.md', [
        '---',
        'title: System Architecture',
        'tags: [architecture, design]',
        '---',
        '',
        '# System Architecture',
        'The system uses a microservices architecture.',
        'Key components: API gateway, message broker, database.',
      ].join('\n'));

      expect(receipt.contentHash).toBeDefined();
      expect(receipt.signature).toBeDefined();

      // Read
      const note = await storage.read('notes/architecture.md');
      expect(note.path).toBe('notes/architecture.md');
      expect(note.frontmatter.tags).toEqual(['architecture', 'design']);

      // Search
      await search.buildIndex();
      const results = search.search({ query: 'microservices architecture' });
      expect(results.length).toBeGreaterThan(0);
      expect(results[0].path).toContain('architecture');

      // Diff
      const diff = await storage.diff('notes/architecture.md');
      expect(diff).toBeDefined();

      // Log
      const log = await storage.log('notes/architecture.md');
      expect(log.length).toBeGreaterThan(0);

      // Soft delete
      await storage.delete('notes/architecture.md');
      expect(fs.existsSync(path.join(vaultPath, 'notes', 'architecture.md'))).toBe(false);

      const trashDir = path.join(vaultPath, '.trash');
      const trashFiles = fs.readdirSync(trashDir);
      expect(trashFiles.length).toBe(1);
      expect(trashFiles[0]).toContain('architecture');

      // Verify soft-deleted file content
      const trashContent = fs.readFileSync(path.join(trashDir, trashFiles[0]), 'utf-8');
      expect(trashContent).toContain('microservices');
    });
  });

  describe('multi-note workflow', () => {
    it('handles multiple notes with cross-references', async () => {
      await storage.write('overview.md', '# Knowledge Vault\n\nSee [[System Architecture]] and [[Sprint Planning]].');
      await storage.write('architecture.md', '# System Architecture\n\nEvent-driven microservices.');
      await storage.write('meetings/sprint.md', '# Sprint Planning\n\nDiscussed #architecture and #agile.');

      const files = await storage.list();
      expect(files.length).toBe(3);

      const stats = await storage.stats();
      expect(stats.noteCount).toBe(3);

      await search.buildIndex();
      const results = search.search({ query: 'architecture' });
      expect(results.length).toBeGreaterThanOrEqual(1);
    });
  });
});
