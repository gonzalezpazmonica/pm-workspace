import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { UserQuotaStore, QuotaExceededError } from '../../../src/auth/quota-store.js';

describe('UserQuotaStore', () => {
  let tmpDir: string;
  let quotaFile: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'quota-test-'));
    quotaFile = path.join(tmpDir, 'quotas.json');
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('allows operations within limits', () => {
    const store = new UserQuotaStore(quotaFile);
    const status = store.check('alice');
    expect(status.allowed).toBe(true);
    expect(status.warning).toBeUndefined();
  });

  it('blocks when exceeding rpm limit', () => {
    const store = new UserQuotaStore(quotaFile);
    store.setConfig('alice', { requestsPerMinute: 5, requestsPerHour: 1000, requestsPerDay: 5000 });

    for (let i = 0; i < 5; i++) {
      expect(store.check('alice').allowed).toBe(true);
      store.record('alice');
    }

    expect(store.check('alice').allowed).toBe(false);
  });

  it('resets counter when window changes', () => {
    const store = new UserQuotaStore(quotaFile);
    store.setConfig('alice', { requestsPerMinute: 3, requestsPerHour: 1000, requestsPerDay: 5000 });

    for (let i = 0; i < 3; i++) {
      store.record('alice');
    }
    expect(store.check('alice').allowed).toBe(false);

    const counters = (store as any).quotas.get('alice').counters;
    counters.minute.window -= 1;

    expect(store.check('alice').allowed).toBe(true);
  });

  it('includes warning at 80% threshold', () => {
    const store = new UserQuotaStore(quotaFile);
    store.setConfig('alice', { requestsPerMinute: 10, requestsPerHour: 1000, requestsPerDay: 5000 });

    for (let i = 0; i < 7; i++) {
      store.record('alice');
    }

    const status = store.check('alice');
    expect(status.allowed).toBe(true);

    store.record('alice');
    const status80 = store.check('alice');
    expect(status80.allowed).toBe(true);
    expect(status80.warning).toBeDefined();
    expect(status80.warning).toContain('80%');
  });

  it('persists state across instances', () => {
    const store1 = new UserQuotaStore(quotaFile);
    store1.setConfig('alice', { requestsPerMinute: 30, requestsPerHour: 500, requestsPerDay: 2000 });
    store1.record('alice');
    store1.record('alice');
    store1.persist();

    const store2 = new UserQuotaStore(quotaFile);
    store2.load();
    const config = store2.getConfig('alice');
    expect(config.requestsPerMinute).toBe(30);
    expect(config.requestsPerHour).toBe(500);
    expect(config.requestsPerDay).toBe(2000);
  });

  it('respects custom config', () => {
    const store = new UserQuotaStore(quotaFile);
    store.setConfig('bob', { requestsPerMinute: 2, requestsPerHour: 10, requestsPerDay: 50 });

    const config = store.getConfig('bob');
    expect(config.requestsPerMinute).toBe(2);
    expect(config.requestsPerHour).toBe(10);
    expect(config.requestsPerDay).toBe(50);
  });

  it('handles unknown user with defaults', () => {
    const store = new UserQuotaStore(quotaFile);
    const config = store.getConfig('ghost');
    expect(config.requestsPerMinute).toBe(60);
    expect(config.requestsPerHour).toBe(1000);
    expect(config.requestsPerDay).toBe(5000);
  });

  it('value 0 means unlimited', () => {
    const store = new UserQuotaStore(quotaFile);
    store.setConfig('alice', { requestsPerMinute: 0, requestsPerHour: 1000, requestsPerDay: 5000 });

    for (let i = 0; i < 200; i++) {
      store.record('alice');
      expect(store.check('alice').allowed).toBe(true);
    }
  });

  it('resetCounters zeros all windows', () => {
    const store = new UserQuotaStore(quotaFile);
    store.setConfig('alice', { requestsPerMinute: 5, requestsPerHour: 50, requestsPerDay: 500 });

    for (let i = 0; i < 5; i++) {
      store.record('alice');
    }
    expect(store.check('alice').allowed).toBe(false);

    store.resetCounters('alice');
    expect(store.check('alice').allowed).toBe(true);
  });

  it('QuotaExceededError has correct properties', () => {
    const store = new UserQuotaStore(quotaFile);
    store.setConfig('alice', { requestsPerMinute: 1, requestsPerHour: 1000, requestsPerDay: 5000 });

    store.record('alice');

    try {
      const status = store.check('alice');
      if (!status.allowed) {
        const err = new QuotaExceededError('alice', 'minute', 1, 1);
        expect(err.username).toBe('alice');
        expect(err.window).toBe('minute');
        expect(err.limit).toBe(1);
        expect(err.current).toBe(1);
        expect(err.message).toContain('alice');
      }
    } catch (e) {
      if (e instanceof QuotaExceededError) {
        expect(e.username).toBe('alice');
      }
    }
  });

  it('partial config merges with defaults', () => {
    const store = new UserQuotaStore(quotaFile);
    store.setConfig('alice', { requestsPerMinute: 15 });

    const config = store.getConfig('alice');
    expect(config.requestsPerMinute).toBe(15);
    expect(config.requestsPerHour).toBe(1000);
    expect(config.requestsPerDay).toBe(5000);
  });
});
