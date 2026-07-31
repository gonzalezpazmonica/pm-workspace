// Integration test: Federated search with 2 local domes
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { FederationRegistry } from '../../src/federation/registry.js';
import { A2AClient } from '../../src/federation/a2a-client.js';
import type { FederatedDome } from '../../src/federation/types.js';

describe('Federation Integration — A2A Client', () => {
  let tmpDir: string;
  let registry: FederationRegistry;
  let client: A2AClient;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'savia-fed-int-'));
    registry = new FederationRegistry(tmpDir);
    client = new A2AClient();
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('health check detects invalid URL', async () => {
    const dome: FederatedDome = {
      id: 'invalid', name: 'Invalid', url: 'http://127.0.0.1:19999',
      timeout: 1000, enabled: true, weight: 1, tags: [], status: 'unknown',
    };
    const result = await client.healthCheck(dome);
    expect(result.healthy).toBe(false);
  });

  it('search returns error for invalid URL', async () => {
    const dome: FederatedDome = {
      id: 'invalid', name: 'Invalid', url: 'http://127.0.0.1:19999',
      timeout: 1000, enabled: true, weight: 1, tags: [], status: 'unknown',
    };
    const result = await client.search(dome, 'test');
    expect(result.status).toBe('error');
    expect(result.results).toEqual([]);
  });

  it('registry persists federation state', () => {
    registry.add({
      id: 'persist-test', name: 'Persist', url: 'http://example.com',
      timeout: 3000, enabled: true, weight: 1.5, tags: ['docs'], status: 'unknown',
    });

    expect(registry.get('persist-test')?.weight).toBe(1.5);

    // New instance loads same data
    const registry2 = new FederationRegistry(tmpDir);
    expect(registry2.get('persist-test')?.tags).toEqual(['docs']);
  });
});
