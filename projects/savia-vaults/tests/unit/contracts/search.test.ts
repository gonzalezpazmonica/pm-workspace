import { describe, it, expect } from 'vitest';
import type { SearchResult, SearchQuery, VaultStats } from '../../../packages/contracts/src/entities/search.js';

describe('Search types (compile-time)', () => {
  it('SearchResult works', () => {
    const r: SearchResult = { path: 't.md', score: 0.85, snippet: 's', tags: ['t'] };
    expect(r.score).toBe(0.85);
  });

  it('SearchQuery optional fields', () => {
    const q: SearchQuery = { query: 'test' };
    expect(q.maxResults).toBeUndefined();
    const withOpts: SearchQuery = { query: 'test', maxResults: 5, pathPrefix: 'docs/' };
    expect(withOpts.maxResults).toBe(5);
  });

  it('VaultStats works', () => {
    const s: VaultStats = { name: 'test', noteCount: 10, totalSize: 1000 };
    expect(s.name).toBe('test');
  });
});
