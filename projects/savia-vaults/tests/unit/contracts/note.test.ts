import { describe, it, expect } from 'vitest';
import type { Note, Frontmatter, Receipt, CommitEntry } from '../../../packages/contracts/src/entities/note.js';

describe('Note types (compile-time)', () => {
  it('Note type is usable', () => {
    const note: Note = {
      path: 'test.md', name: 'test',
      frontmatter: { title: 'Test' }, tags: ['test'],
      content: '# Test', created: '2026-01-01', modified: '2026-01-01',
    };
    expect(note.path).toBe('test.md');
    expect(note.frontmatter.title).toBe('Test');
  });

  it('Frontmatter allows extra properties', () => {
    const fm: Frontmatter = { title: 'Test', custom: 'value' };
    expect(fm.custom).toBe('value');
  });

  it('Receipt has required fields', () => {
    const r: Receipt = { vault: 'test', path: 'test.md', contentHash: 'abc', signature: 'def', timestamp: '2026-01-01' };
    expect(r.vault).toBe('test');
  });
});
