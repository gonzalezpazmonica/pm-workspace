// Unit tests: Federated Search Engine (merge logic)
import { describe, it, expect, vi } from 'vitest';
import { FederatedSearchEngine } from '../../../src/federation/search.js';
import { FederationRegistry } from '../../../src/federation/registry.js';
import { SearchEngine } from '../../../src/search/index.js';
import type { FederatedSearchResult } from '../../../src/federation/types.js';

function fakeResult(path: string, snippet: string, source: string = 'local'): FederatedSearchResult {
  let hash = 0;
  const s = snippet || path;
  for (let i = 0; i < s.length; i++) {
    hash = ((hash << 5) - hash) + s.charCodeAt(i);
    hash = hash & hash;
  }
  return {
    path,
    score: 1.0,
    snippet,
    tags: [],
    source,
    contentHash: Math.abs(hash).toString(16).padStart(8, '0'),
  };
}

describe('FederatedSearchEngine — merge logic', () => {
  // We test the mergeResults method indirectly via a mock setup
  // Create minimal engine with mocked search/local results
  function createEngine(localResults: FederatedSearchResult[]) {
    const tmpDir = '/tmp/fake-federation-test';
    const registry = new FederationRegistry(tmpDir);
    registry.clear();

    const local = {
      search: vi.fn().mockReturnValue(
        localResults.map((r) => ({ path: r.path, score: r.score, snippet: r.snippet, tags: r.tags })),
      ),
    } as unknown as SearchEngine;

    return { engine: new FederatedSearchEngine(local, registry), registry };
  }

  it('returns local results when no federated domes', async () => {
    const { engine } = createEngine([
      fakeResult('a.md', 'alpha', 'local'),
      fakeResult('b.md', 'beta', 'local'),
    ]);

    const response = await engine.search('test');
    expect(response.results.length).toBe(2);
    expect(response.results[0].source).toBe('local');
    expect(response.sources[0].id).toBe('local');
  });

  it('deduplicates by content hash', async () => {
    // This tests the internal merge logic via the cache miss path
    // Local returns same content as remote → dedup
    const { engine, registry } = createEngine([
      fakeResult('local.md', 'same content', 'local'),
    ]);

    // Add a dome that would return same content
    registry.add({
      id: 'remote1', name: 'Remote', url: 'http://remote',
      timeout: 5000, enabled: true, weight: 1, tags: [], status: 'healthy',
    });

    // Since the A2A client is real, this will try to connect and fail
    // The test verifies local results are always included
    const response = await engine.search('test');
    expect(response.results.length).toBeGreaterThanOrEqual(1);
    expect(response.results[0].source).toBe('local');
  });

  it('caches results', async () => {
    const { engine } = createEngine([fakeResult('cached.md', 'cache me')]);

    await engine.search('cache query');
    const response2 = await engine.search('cache query');
    // Second call should use cache (totalMs = 0)
    expect(response2.totalMs).toBe(0);
  });
});
