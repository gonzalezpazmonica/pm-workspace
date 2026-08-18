import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { AuditLogger } from '../../../src/auth/audit-logger.js';

describe('AuditLogger', () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'audit-test-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  function readLogFiles(dir: string): string[] {
    const files = fs.readdirSync(dir)
      .filter(f => f.startsWith('savia-vaults.audit-') && f.endsWith('.jsonl'))
      .sort();
    const lines: string[] = [];
    for (const f of files) {
      const content = fs.readFileSync(path.join(dir, f), 'utf-8');
      lines.push(...content.split('\n').filter(l => l.trim()));
    }
    return lines;
  }

  it('creates log file on first record', () => {
    const logger = new AuditLogger(tmpDir);
    logger.record({ username: 'alice', dome: 'example-context', action: 'read', result: 'allowed' });

    const files = fs.readdirSync(tmpDir);
    expect(files.length).toBeGreaterThanOrEqual(1);
    expect(files[0]).toMatch(/^savia-vaults\.audit-\d{4}-\d{2}-\d{2}\.jsonl$/);
  });

  it('appends JSONL entries with timestamp', () => {
    const logger = new AuditLogger(tmpDir);
    logger.record({ username: 'alice', dome: 'example-context', action: 'read', result: 'allowed' });
    logger.record({ username: 'bob', dome: 'Labs', action: 'write', result: 'denied', reason: 'forbidden' });

    const lines = readLogFiles(tmpDir);
    expect(lines).toHaveLength(2);

    const e1 = JSON.parse(lines[0]);
    expect(e1.username).toBe('alice');
    expect(e1.dome).toBe('example-context');
    expect(e1.action).toBe('read');
    expect(e1.result).toBe('allowed');
    expect(e1.ts).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);

    const e2 = JSON.parse(lines[1]);
    expect(e2.username).toBe('bob');
    expect(e2.result).toBe('denied');
    expect(e2.reason).toBe('forbidden');
  });

  it('queries entries filtered by username', () => {
    const logger = new AuditLogger(tmpDir);
    logger.record({ username: 'alice', dome: 'example-context', action: 'read', result: 'allowed' });
    logger.record({ username: 'bob', dome: 'example-context', action: 'read', result: 'allowed' });
    logger.record({ username: 'alice', dome: 'Labs', action: 'write', result: 'denied', reason: 'forbidden' });

    const aliceEntries = logger.query({ username: 'alice' });
    expect(aliceEntries).toHaveLength(2);
    expect(aliceEntries.every(e => e.username === 'alice')).toBe(true);
  });

  it('queries entries filtered by dome', () => {
    const logger = new AuditLogger(tmpDir);
    logger.record({ username: 'alice', dome: 'example-context', action: 'read', result: 'allowed' });
    logger.record({ username: 'alice', dome: 'Labs', action: 'read', result: 'allowed' });

    expect(logger.query({ dome: 'example-context' })).toHaveLength(1);
    expect(logger.query({ dome: 'Labs' })).toHaveLength(1);
  });

  it('queries entries filtered by action and result', () => {
    const logger = new AuditLogger(tmpDir);
    logger.record({ username: 'alice', dome: 'X', action: 'read', result: 'allowed' });
    logger.record({ username: 'alice', dome: 'X', action: 'write', result: 'denied', reason: 'bad' });

    expect(logger.query({ action: 'read' })).toHaveLength(1);
    expect(logger.query({ result: 'denied' })).toHaveLength(1);
    expect(logger.query({ action: 'read', result: 'allowed' })).toHaveLength(1);
  });

  it('has last N limit', () => {
    const logger = new AuditLogger(tmpDir);
    for (let i = 0; i < 10; i++) {
      logger.record({ username: 'test', dome: 'D', action: 'read', result: 'allowed' });
    }

    expect(logger.query({ last: 3 })).toHaveLength(3);
    expect(logger.query({ last: 100 })).toHaveLength(10);
  });

  it('aggregates stats correctly', () => {
    const logger = new AuditLogger(tmpDir);
    logger.record({ username: 'a', dome: 'D1', action: 'read', result: 'allowed' });
    logger.record({ username: 'a', dome: 'D1', action: 'write', result: 'allowed' });
    logger.record({ username: 'b', dome: 'D2', action: 'read', result: 'denied', reason: 'nope' });

    const stats = logger.stats({});
    expect(stats.total).toBe(3);
    expect(stats.allowed).toBe(2);
    expect(stats.denied).toBe(1);
    expect(stats.byUser['a']).toBe(2);
    expect(stats.byUser['b']).toBe(1);
    expect(stats.byDome['D1']).toBe(2);
    expect(stats.byDome['D2']).toBe(1);
    expect(stats.byAction['read']).toBe(2);
    expect(stats.byAction['write']).toBe(1);
  });

  it('handles write failure gracefully', () => {
    const readOnlyDir = path.join(tmpDir, 'readonly');
    fs.mkdirSync(readOnlyDir, { recursive: true });
    fs.chmodSync(readOnlyDir, 0o444);

    const logger = new AuditLogger(readOnlyDir);
    expect(() => {
      logger.record({ username: 'test', dome: 'D', action: 'read', result: 'allowed' });
    }).not.toThrow();
  });

  it('skips malformed JSON lines in query', () => {
    const logger = new AuditLogger(tmpDir);
    logger.record({ username: 'ok', dome: 'D', action: 'read', result: 'allowed' });

    const today = new Date().toISOString().slice(0, 10);
    const logFile = path.join(tmpDir, `savia-vaults.audit-${today}.jsonl`);
    fs.appendFileSync(logFile, 'this is not json\n');

    const results = logger.query({});
    expect(results.length).toBeGreaterThanOrEqual(1);
    expect(results.every(e => e.username)).toBe(true);
  });

  it('close() stops logging', () => {
    const logger = new AuditLogger(tmpDir);
    logger.record({ username: 'x', dome: 'D', action: 'read', result: 'allowed' });
    logger.close();
    expect(() => logger.close()).not.toThrow();
  });

  it('records anonymous username for public access', () => {
    const logger = new AuditLogger(tmpDir);
    logger.record({ username: 'anonymous', dome: 'PublicDome', action: 'read', result: 'allowed' });

    const entries = logger.query({ username: 'anonymous' });
    expect(entries).toHaveLength(1);
    expect(entries[0].dome).toBe('PublicDome');
  });
});
