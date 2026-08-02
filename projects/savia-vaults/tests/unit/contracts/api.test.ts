import { describe, it, expect } from 'vitest';
import type { VaultReadParams, VaultReadResult } from '../../../packages/contracts/src/api/read.js';
import type { VaultWriteParams, VaultWriteResult } from '../../../packages/contracts/src/api/write.js';
import type { VaultSearchParams, VaultSearchResultItem } from '../../../packages/contracts/src/api/search.js';
import type { VaultListParams, VaultListItem } from '../../../packages/contracts/src/api/list.js';

describe('API contracts (compile-time)', () => {
  it('VaultReadParams and VaultReadResult compile', () => {
    const p: VaultReadParams = { path: 'test.md' };
    const r: VaultReadResult = { path: 't.md', name: 't', frontmatter: {}, tags: [], content: '' };
    expect(p.path).toBe('test.md');
    expect(r.name).toBe('t');
  });

  it('VaultWriteParams and VaultWriteResult compile', () => {
    const p: VaultWriteParams = { path: 't.md', content: '# test' };
    const r: VaultWriteResult = { vault: 'v', path: 't.md', contentHash: 'h', signature: 's', timestamp: 't' };
    expect(p.content).toBe('# test');
    expect(r.vault).toBe('v');
  });

  it('VaultSearchParams and VaultSearchResultItem compile', () => {
    const p: VaultSearchParams = { query: 'test' };
    const r: VaultSearchResultItem = { path: 't.md', score: 0.5, snippet: 's', tags: [] };
    expect(p.query).toBe('test');
    expect(r.score).toBe(0.5);
  });

  it('VaultListParams and VaultListItem compile', () => {
    const p: VaultListParams = {};
    const r: VaultListItem = { path: 'docs/', type: 'directory' };
    expect(r.type).toBe('directory');
  });

  it('all API types are importable from barrel', async () => {
    const mod = await import('../../../packages/contracts/src/api/index.js');
    expect(mod).toBeDefined();
  });
});
