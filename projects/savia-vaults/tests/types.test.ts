import { describe, it, expect } from 'vitest';
import type { SearchQuery, SearchResult } from '../src/types.js';

describe('SE-330 SearchQuery/SearchResult contract', () => {
  it('SearchQuery admite enrich (SE-330)', () => {
    const q: SearchQuery = { query: 'x', maxResults: 5, enrich: true };
    expect(q.enrich).toBe(true);
  });

  it('SearchQuery sin enrich → undefined (backward compatible)', () => {
    const q: SearchQuery = { query: 'x' };
    expect(q.enrich).toBeUndefined();
  });

  it('SearchResult shape válida', () => {
    const r: SearchResult = { path: 'a.md', score: 0.5, snippet: 's', tags: [] };
    expect(r.path).toBe('a.md');
    expect(typeof r.score).toBe('number');
  });
});
