// Unit tests: Hash Verifier
import { describe, it, expect } from 'vitest';
import { hashContent, verifyContentHash } from '../../../src/federation/hash-verify.js';
import type { FederatedSearchResult } from '../../../src/federation/types.js';

describe('Hash Verifier', () => {
  it('produces deterministic hash', () => {
    expect(hashContent('hello')).toBe(hashContent('hello'));
  });

  it('different content produces different hash', () => {
    expect(hashContent('hello')).not.toBe(hashContent('world'));
  });

  it('verifies valid hash', () => {
    const snippet = 'test snippet';
    const h = hashContent(snippet);
    const result: FederatedSearchResult = {
      path: 'test.md', score: 1, snippet, tags: [], source: 'remote', contentHash: h,
    };
    expect(verifyContentHash(result)).toBe(true);
  });

  it('rejects tampered content', () => {
    const result: FederatedSearchResult = {
      path: 'test.md', score: 1, snippet: 'original', tags: [], source: 'remote', contentHash: 'deadbeef',
    };
    expect(verifyContentHash(result)).toBe(false);
  });

  it('rejects empty snippet', () => {
    const result: FederatedSearchResult = {
      path: 'test.md', score: 1, snippet: '', tags: [], source: 'remote', contentHash: hashContent('something'),
    };
    expect(verifyContentHash(result)).toBe(false);
  });
});
