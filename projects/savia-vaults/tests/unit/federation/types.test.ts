// Unit tests: Federation types validation
import { describe, it, expect } from 'vitest';
import type { FederatedDome, FederationConfig, FederatedSearchResult } from '../../src/federation/types.js';

describe('Federation Types', () => {
  it('FederatedDome type has required fields', () => {
    const dome: FederatedDome = {
      id: 'test', name: 'Test', url: 'http://test',
      timeout: 5000, enabled: true, weight: 1.0, tags: [], status: 'unknown',
    };
    expect(dome.id).toBe('test');
    expect(dome.url).toBe('http://test');
  });

  it('FederatedSearchResult includes source attribution', () => {
    const result: FederatedSearchResult = {
      path: 'notes/test.md', score: 0.9, snippet: 'test', tags: [], source: 'remote-1', contentHash: 'abc123',
    };
    expect(result.source).toBe('remote-1');
  });
});
