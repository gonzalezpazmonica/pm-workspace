import type { FederatedSearchResult } from './types.js';

interface CacheEntry { results: FederatedSearchResult[]; timestamp: number; }

export class FederationCache {
  private cache: Map<string, CacheEntry> = new Map();
  private maxSize: number; private ttlMs: number;
  constructor(maxSize = 1000, ttlMs = 300000) { this.maxSize = maxSize; this.ttlMs = ttlMs; }

  private buildKey(query: string, domeIds: string[]): string { return `${query}::${[...domeIds].sort().join(',')}`; }

  get(query: string, domeIds: string[]): FederatedSearchResult[] | null {
    const key = this.buildKey(query, domeIds); const entry = this.cache.get(key);
    if (!entry || Date.now() - entry.timestamp > this.ttlMs) { if (entry) this.cache.delete(key); return null; }
    this.cache.delete(key); this.cache.set(key, entry); return entry.results;
  }

  set(query: string, domeIds: string[], results: FederatedSearchResult[]): void {
    const key = this.buildKey(query, domeIds);
    if (this.cache.size >= this.maxSize) { const oldest = this.cache.keys().next().value; if (oldest) this.cache.delete(oldest); }
    this.cache.set(key, { results, timestamp: Date.now() });
  }

  invalidate(): void { this.cache.clear(); }
  get size(): number { return this.cache.size; }
}
