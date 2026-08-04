import { describe, it, expect } from 'vitest';
import {
  extractWikiLinks,
  validateWikiLinks,
  resolveBacklinks,
  buildEntityIndex,
  computeWikiLinkHealth,
} from '../../../src/knowledge/wikilink-validator.js';

describe('extractWikiLinks', () => {
  it('extracts simple wikilinks', () => {
    const links = extractWikiLinks('Ver [[SE-291]] y [[SE-288]]');
    expect(links).toHaveLength(2);
    expect(links[0].target).toBe('SE-291');
    expect(links[1].target).toBe('SE-288');
  });

  it('extracts wikilinks with alias', () => {
    const links = extractWikiLinks('Ver [[SE-291|spec multi-dome]]');
    expect(links).toHaveLength(1);
    expect(links[0].target).toBe('SE-291');
    expect(links[0].displayText).toBe('spec multi-dome');
  });

  it('handles no wikilinks', () => {
    const links = extractWikiLinks('No wikilinks here');
    expect(links).toHaveLength(0);
  });

  it('handles multiple wikilinks with mixed syntax', () => {
    const links = extractWikiLinks('[[A]] and [[B|alias B]] and [[C]]');
    expect(links).toHaveLength(3);
    expect(links[1].target).toBe('B');
    expect(links[1].displayText).toBe('alias B');
  });
});

describe('validateWikiLinks', () => {
  it('marks links as valid when entity exists', () => {
    const entities = new Set(['SE-291', 'SE-288']);
    const results = validateWikiLinks('test.md', 'Ver [[SE-291]]', entities);
    expect(results[0].exists).toBe(true);
  });

  it('marks links as broken when entity missing', () => {
    const entities = new Set(['SE-291']);
    const results = validateWikiLinks('test.md', 'Ver [[SE-999]]', entities);
    expect(results[0].exists).toBe(false);
  });
});

describe('buildEntityIndex', () => {
  it('indexes entities from frontmatter', () => {
    const notes = [
      { path: 'docs/SE-291.md', frontmatter: { entity: { type: 'document', id: 'SE-291' } } },
      { path: 'docs/other.md', frontmatter: { title: 'Other' } },
    ];
    const index = buildEntityIndex(notes);
    expect(index.has('SE-291')).toBe(true);
  });
});

describe('computeWikiLinkHealth', () => {
  it('computes health stats', () => {
    const notes = [
      { path: 'a.md', content: 'Ver [[SE-291]] y [[SE-999]]' },
      { path: 'b.md', content: 'Ver [[SE-291]]' },
    ];
    const entities = new Set(['SE-291']);
    const health = computeWikiLinkHealth(notes, entities);
    expect(health.total_links).toBe(3);
    expect(health.valid_links).toBe(2);
    expect(health.broken_links).toBe(1);
    expect(health.broken_details[0].target).toBe('SE-999');
  });

  it('handles empty notes', () => {
    const health = computeWikiLinkHealth([], new Set());
    expect(health.total_links).toBe(0);
    expect(health.valid_links).toBe(0);
    expect(health.broken_links).toBe(0);
  });
});

describe('resolveBacklinks', () => {
  it('finds notes linking to target', () => {
    const notes = [
      { path: 'a.md', content: 'Ver [[SE-291]] para detalles importantes sobre la arquitectura multi-dome' },
      { path: 'b.md', content: '[[SE-291]] fue implementado en agosto' },
      { path: 'c.md', content: 'Sin referencias' },
    ];
    const backlinks = resolveBacklinks('SE-291', notes);
    expect(backlinks).toHaveLength(2);
    expect(backlinks[0].source).toBe('a.md');
    expect(backlinks[1].source).toBe('b.md');
  });

  it('returns empty for target with no backlinks', () => {
    const notes = [{ path: 'a.md', content: 'Sin wikilinks' }];
    const backlinks = resolveBacklinks('orphan', notes);
    expect(backlinks).toHaveLength(0);
  });
});
