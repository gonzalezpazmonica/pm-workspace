import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import {
  getAINotice, loadInventory, getClassification, requiresMarking,
  createContentMark, signMark, verifyMark, injectMarkIntoContent,
  extractMark, detectAIContent
} from '../../src/compliance/transparency.js';

describe('Transparency — Art. 50 EU AI Act', () => {
  let tmpDir: string;

  beforeEach(() => { tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-transparency-')); });
  afterEach(() => { fs.rmSync(tmpDir, { recursive: true, force: true }); });

  describe('S1 — Inventory', () => {
    it('loads output inventory from YAML', () => {
      fs.writeFileSync(path.join(tmpDir, 'output-inventory.yaml'), [
        'entries:',
        '  - type: spec',
        '    description: Spec',
        '    audience: humano',
        '    exposure: publico',
        '    art50_1: false',
        '    art50_2: true',
        '    art50_4: false',
        '    exclusion: ""',
        '    notes: ""',
      ].join('\n'));

      const inventory = loadInventory(tmpDir);
      expect(inventory.length).toBeGreaterThanOrEqual(1);
      expect(inventory[0].type).toBe('spec');
    });

    it('classifies output types correctly', () => {
      fs.writeFileSync(path.join(tmpDir, 'output-inventory.yaml'), [
        'entries:',
        '  - type: spec',
        '    description: Spec', '    audience: humano', '    exposure: publico',
        '    art50_1: false', '    art50_2: true', '    art50_4: false',
        '    exclusion: ""', '    notes: ""',
      ].join('\n'));

      const inventory = loadInventory(tmpDir);
      const entry = getClassification('spec', inventory);
      expect(entry).toBeDefined();
      expect(entry!.art50_2).toBe(true);
      expect(requiresMarking('spec', inventory)).toBe(true);
    });
  });

  describe('S2 — Notification', () => {
    it('provides AI interaction notice', () => {
      const notice = getAINotice();
      expect(notice).toContain('Art. 50');
      expect(notice).toContain('AI system');
    });
  });

  describe('S3 — Content marking', () => {
    it('creates and signs a content mark', () => {
      const mark = createContentMark('savia-vaults', '0.3.0');
      expect(mark.ai_generated).toBe(true);
      expect(mark.timestamp).toBeDefined();

      mark.signature = signMark(mark);
      expect(verifyMark(mark)).toBe(true);
    });

    it('detects tampered marks', () => {
      const mark = createContentMark('savia-vaults', '0.3.0');
      mark.signature = signMark(mark);
      mark.timestamp = '2020-01-01'; // tampered
      expect(verifyMark(mark)).toBe(false);
    });

    it('injects mark into content preserving original', () => {
      const mark = createContentMark('savia-vaults', '0.3.0', true, 'Mónica', 'full review');
      const original = '# Hello World\n\nThis is a test document.\n';
      const marked = injectMarkIntoContent(original, mark);

      expect(marked).toContain('ai_generated: true');
      expect(marked).toContain('ai_human_reviewed: true');
      expect(marked).toContain('ai_reviewer: Mónica');
      expect(marked).toContain('# Hello World');
      expect(marked).toContain('This is a test document.');
    });

    it('extracts and verifies mark from content', () => {
      const mark = createContentMark('savia-vaults', '0.3.0');
      const content = injectMarkIntoContent('test', mark);
      const extracted = extractMark(content);

      expect(extracted).toBeDefined();
      expect(extracted!.system).toBe('savia-vaults');
      expect(verifyMark(extracted!)).toBe(true);
    });

    it('returns null for unmarked content', () => {
      expect(extractMark('plain text without mark')).toBeNull();
      expect(extractMark('---\ntitle: test\n---\ncontent')).toBeNull();
    });

    it('detection finds marked AI content with HIGH confidence', () => {
      const mark = createContentMark('savia-vaults', '0.3.0');
      const content = injectMarkIntoContent('test content', mark);
      const report = detectAIContent(content, new Map());

      expect(report.generated_by_ai).toBe(true);
      expect(report.confidence).toBe('HIGH');
    });

    it('detection finds logged content with MEDIUM confidence', () => {
      const content = 'unmarked but logged content';
      const log = new Map<string, string>();
      const crypto = require('node:crypto');
      const hash = crypto.createHash('sha256').update(content).digest('hex');
      log.set(hash, 'savia-vaults');

      const report = detectAIContent(content, log);
      expect(report.generated_by_ai).toBe(true);
      expect(report.confidence).toBe('MEDIUM');
    });

    it('detection returns NONE for unknown content', () => {
      const report = detectAIContent('random text', new Map());
      expect(report.generated_by_ai).toBe(false);
      expect(report.confidence).toBe('NONE');
    });
  });
});
