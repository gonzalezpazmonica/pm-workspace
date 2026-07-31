// Unit tests: Audit Logger
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { FederationAuditLogger } from '../../../src/federation/audit-logger.js';

describe('FederationAuditLogger', () => {
  let tmpDir: string;
  let logger: FederationAuditLogger;

  beforeEach(() => { tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-audit-test-')); logger = new FederationAuditLogger(tmpDir, 1024); });
  afterEach(() => { fs.rmSync(tmpDir, { recursive: true, force: true }); });

  it('logs a query entry', () => {
    logger.logQuery('dome-1', 'test query', 'ok', 3, 45);
    const files = fs.readdirSync(tmpDir);
    expect(files.length).toBe(1);
    expect(files[0]).toMatch(/federation-audit-.*\.jsonl/);

    const content = fs.readFileSync(path.join(tmpDir, files[0]), 'utf-8').trim();
    const entry = JSON.parse(content);
    expect(entry.dome).toBe('dome-1');
    expect(entry.query).toBe('test query');
    expect(entry.status).toBe('ok');
    expect(entry.results).toBe(3);
    expect(entry.latency_ms).toBe(45);
  });

  it('logs multiple entries', () => {
    logger.logQuery('a', 'q1', 'ok', 1, 10);
    logger.logQuery('b', 'q2', 'timeout', 0, 5000);
    logger.logQuery('a', 'q3', 'error', 0, 100);
    const files = fs.readdirSync(tmpDir);
    const content = fs.readFileSync(path.join(tmpDir, files[0]), 'utf-8').trim();
    expect(content.split('\n').length).toBe(3);
  });

  it('rotates file when exceeding max size', () => {
    for (let i = 0; i < 20; i++) logger.logQuery('d', 'query ' + 'x'.repeat(60), 'ok', 1, 10);
    const files = fs.readdirSync(tmpDir).filter(f => f.endsWith('.jsonl'));
    expect(files.length).toBeGreaterThanOrEqual(2);
  });

  it('logs token rotation event', () => {
    logger.logRotation('specs');
    const files = fs.readdirSync(tmpDir);
    const content = fs.readFileSync(path.join(tmpDir, files[0]), 'utf-8').trim();
    const entry = JSON.parse(content);
    expect(entry.event).toBe('token_rotation');
    expect(entry.dome).toBe('specs');
  });
});
