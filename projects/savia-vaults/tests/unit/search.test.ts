// Unit tests: SaviaVaults search engine
// Copyright (c) 2026 Savia. MIT License.

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { SearchEngine } from '../../src/search/index.js';
import type { VaultConfig } from '../../src/types.js';

describe('SearchEngine', () => {
  let config: VaultConfig;
  let engine: SearchEngine;
  let vaultPath: string;

  beforeEach(async () => {
    vaultPath = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-vault-search-'));
    config = {
      name: 'test-vault',
      path: vaultPath,
      allowedExtensions: [],
      deniedPaths: [],
      maxDepth: 10,
      maxFileSize: 1024 * 1024,
    };

    // Create test notes
    fs.mkdirSync(path.join(vaultPath, 'notes'), { recursive: true });
    fs.writeFileSync(path.join(vaultPath, 'notes', 'architecture.md'), [
      '---',
      'title: System Architecture',
      'tags: [architecture, design, technical]',
      '---',
      '',
      '# System Architecture',
      'The system uses a microservices architecture with event-driven communication.',
      'Key components include the API gateway and message broker.',
    ].join('\n'));

    fs.writeFileSync(path.join(vaultPath, 'notes', 'meeting.md'), [
      '---',
      'title: Sprint Planning',
      'tags: [meeting, sprint, agile]',
      '---',
      '',
      '# Sprint Planning Notes',
      'Discussed the new authentication module and timeline.',
      'Decided to use JWT tokens for API authentication.',
    ].join('\n'));

    fs.writeFileSync(path.join(vaultPath, 'notes', 'onboarding.md'), [
      '---',
      'title: Developer Onboarding',
      'tags: [onboarding, dev, process]',
      '---',
      '',
      '# Developer Onboarding Guide',
      'Follow these steps to set up your development environment.',
      'Required tools: Node.js 22+, Docker, VS Code.',
      '#dev #onboarding',
    ].join('\n'));

    engine = new SearchEngine(config);
    await engine.buildIndex();
  });

  afterEach(() => {
    if (fs.existsSync(vaultPath)) {
      fs.rmSync(vaultPath, { recursive: true, force: true });
    }
  });

  describe('buildIndex', () => {
    it('indexes all vault notes', () => {
      const tags = engine.getTags();
      expect(tags.size).toBeGreaterThan(0);
      expect(tags.has('architecture')).toBe(true);
      expect(tags.has('meeting')).toBe(true);
      expect(tags.has('onboarding')).toBe(true);
    });
  });

  describe('search', () => {
    it('finds notes by content keywords', () => {
      const results = engine.search({ query: 'architecture microservices' });
      expect(results.length).toBeGreaterThan(0);
      expect(results[0].path).toContain('architecture');
    });

    it('finds notes by tags', () => {
      const results = engine.search({ query: 'agile sprint' });
      expect(results.length).toBeGreaterThan(0);
      expect(results[0].path).toContain('meeting');
    });

    it('respects maxResults', () => {
      const results = engine.search({ query: 'note', maxResults: 1 });
      expect(results.length).toBe(1);
    });

    it('respects pathPrefix filter', () => {
      fs.mkdirSync(path.join(vaultPath, 'sub'), { recursive: true });
      fs.writeFileSync(path.join(vaultPath, 'sub', 'secret.md'), '# Secret #architecture');
      engine.buildIndex(); // rebuild

      const results = engine.search({ query: 'architecture', pathPrefix: 'notes' });
      expect(results.every((r) => r.path.startsWith('notes'))).toBe(true);
    });

    it('returns empty for non-matching query', () => {
      const results = engine.search({ query: 'xyznonexistent12345' });
      expect(results.length).toBe(0);
    });
  });

  describe('getTags', () => {
    it('returns tag counts sorted by frequency', () => {
      const tags = engine.getTags();
      const entries = [...tags.entries()];
      expect(entries[0][1]).toBeGreaterThanOrEqual(entries[entries.length - 1][1]);
    });
  });
});
