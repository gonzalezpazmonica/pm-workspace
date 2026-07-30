// Unit tests: Federation Cache
import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { FederationCache } from '../../../src/federation/cache.js';
import type { FederatedSearchResult } from '../../../src/federation/types.js';

function makeResult(path: string, snippet: string): FederatedSearchResult {
  return { path, score: 1, snippet, tags: [], source: 'local', contentHash: 'hash' + path };
}

describe('FederationCache', () => {
  let cache: FederationCache;

  beforeEach(() => {
    vi.useFakeTimers();
    cache = new FederationCache(10, 60000); // 10 entries, 60s TTL
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('returns null for uncached query', () => {
    expect(cache.get('test', ['local'])).toBeNull();
  });

  it('stores and retrieves results', () => {
    const results = [makeResult('a.md', 'snippet a')];
    cache.set('test', ['local'], results);
    expect(cache.get('test', ['local'])).toEqual(results);
  });

  it('returns null after TTL expires', () => {
    const results = [makeResult('a.md', 'snippet a')];
    cache.set('test', ['local'], results);
    vi.advanceTimersByTime(61000);
    expect(cache.get('test', ['local'])).toBeNull();
  });

  it('different query+dome combos are separate entries', () => {
    cache.set('query1', ['local'], [makeResult('a.md', 'a')]);
    cache.set('query2', ['local'], [makeResult('b.md', 'b')]);
    expect(cache.get('query1', ['local'])!.length).toBe(1);
    expect(cache.get('query2', ['local'])!.length).toBe(1);
  });

  it('different dome order produces same cache key', () => {
    cache.set('q', ['a', 'b'], [makeResult('x.md', 'x')]);
    expect(cache.get('q', ['b', 'a'])).not.toBeNull();
  });

  it('evicts oldest when full', () => {
    for (let i = 0; i < 10; i++) {
      cache.set(`q${i}`, ['local'], [makeResult(`${i}.md`, `${i}`)]);
    }
    expect(cache.size).toBe(10);
    cache.set('new', ['local'], [makeResult('new.md', 'new')]);
    expect(cache.size).toBe(10); // still 10, oldest evicted
  });

  it('invalidate clears everything', () => {
    cache.set('a', ['local'], [makeResult('a.md', 'a')]);
    cache.set('b', ['local'], [makeResult('b.md', 'b')]);
    cache.invalidate();
    expect(cache.size).toBe(0);
  });
});
