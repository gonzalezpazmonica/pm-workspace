// Unit tests: Federation Registry
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { FederationRegistry } from '../../../src/federation/registry.js';
import type { FederatedDome } from '../../../src/federation/types.js';

describe('FederationRegistry', () => {
  let tmpDir: string;
  let registry: FederationRegistry;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-federation-test-'));
    registry = new FederationRegistry(tmpDir);
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  const makeDome = (id: string, url: string, overrides: Partial<FederatedDome> = {}): FederatedDome => ({
    id,
    name: `Dome ${id}`,
    url,
    timeout: 5000,
    enabled: true,
    weight: 1.0,
    tags: [],
    status: 'unknown',
    ...overrides,
  });

  it('starts with empty registry', () => {
    expect(registry.count).toBe(0);
    expect(registry.list()).toEqual([]);
  });

  it('adds a dome', () => {
    const dome = makeDome('specs', 'http://localhost:8924');
    registry.add(dome);
    expect(registry.count).toBe(1);
    expect(registry.get('specs')).toMatchObject({ id: 'specs', url: 'http://localhost:8924' });
  });

  it('rejects dome without id or url', () => {
    expect(() => registry.add({ id: '', url: 'http://x' } as FederatedDome)).toThrow();
    expect(() => registry.add({ id: 'x', url: '' } as FederatedDome)).toThrow();
  });

  it('removes a dome', () => {
    registry.add(makeDome('a', 'http://a'));
    registry.add(makeDome('b', 'http://b'));
    expect(registry.remove('a')).toBe(true);
    expect(registry.count).toBe(1);
    expect(registry.remove('nonexistent')).toBe(false);
  });

  it('persists across instances', () => {
    registry.add(makeDome('persist', 'http://persist'));
    const registry2 = new FederationRegistry(tmpDir);
    expect(registry2.count).toBe(1);
    expect(registry2.get('persist')?.url).toBe('http://persist');
  });

  it('lists only enabled domes', () => {
    registry.add(makeDome('enabled', 'http://enabled', { enabled: true }));
    registry.add(makeDome('disabled', 'http://disabled', { enabled: false }));
    expect(registry.listEnabled().length).toBe(1);
    expect(registry.listEnabled()[0].id).toBe('enabled');
  });

  it('lists only healthy domes', () => {
    registry.add(makeDome('healthy', 'http://healthy', { status: 'healthy' }));
    registry.add(makeDome('degraded', 'http://degraded', { status: 'degraded' }));
    registry.add(makeDome('unhealthy', 'http://unhealthy', { status: 'unhealthy' }));
    expect(registry.getHealthy().length).toBe(2); // healthy + degraded
  });

  it('updates dome status', () => {
    registry.add(makeDome('test', 'http://test'));
    registry.updateStatus('test', 'healthy');
    expect(registry.get('test')?.status).toBe('healthy');
    expect(registry.get('test')?.lastHealthCheck).toBeDefined();
  });
});
