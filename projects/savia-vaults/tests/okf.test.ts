import { describe, it, expect } from 'vitest';
import {
  validateOkfFrontmatter,
  convertWikiLinksToMarkdown,
  convertMarkdownLinksToWikiLinks,
  inferOkfType,
  serializeOkfNote,
  OKF_REQUIRED_FIELDS,
  OKF_OPTIONAL_FIELDS,
  OKF_RESERVED_FILENAMES,
} from '../src/knowledge/okf.js';

describe('OKF Frontmatter Validation', () => {
  it('accepts a conformant frontmatter with type + optional fields', () => {
    const report = validateOkfFrontmatter(
      {
        type: 'BigQuery Table',
        title: 'Orders',
        description: 'One row per completed order',
        resource: 'https://console.cloud.google.com/orders',
        tags: ['sales', 'revenue'],
        timestamp: '2026-05-28T14:30:00Z',
      },
      'tables/orders.md',
    );
    expect(report.conformant).toBe(true);
    expect(report.violations).toHaveLength(0);
  });

  it('rejects a frontmatter missing the required type field', () => {
    const report = validateOkfFrontmatter({ title: 'Orders' }, 'tables/orders.md');
    expect(report.conformant).toBe(false);
    expect(report.violations.some(v => v.includes('type'))).toBe(true);
  });

  it('rejects an invalid timestamp', () => {
    const report = validateOkfFrontmatter(
      { type: 'Concept', timestamp: 'not-a-date' },
      'concepts/foo.md',
    );
    expect(report.conformant).toBe(false);
    expect(report.violations.some(v => v.includes('timestamp'))).toBe(true);
  });

  it('warns on non-OKF fields', () => {
    const report = validateOkfFrontmatter(
      { type: 'Concept', customField: 'x' },
      'concepts/foo.md',
    );
    expect(report.conformant).toBe(true);
    expect(report.warnings.some(w => w.includes('customField'))).toBe(true);
  });

  it('accepts a minimal frontmatter with only type', () => {
    const report = validateOkfFrontmatter({ type: 'Runbook' }, 'runbooks/incident.md');
    expect(report.conformant).toBe(true);
  });

  it('warns on reserved filenames', () => {
    const report = validateOkfFrontmatter({ type: 'Concept' }, 'sales/index.md');
    expect(report.warnings.some(w => w.includes('reserved'))).toBe(true);
  });
});

describe('OKF Constants', () => {
  it('exposes type as the only required field', () => {
    expect(OKF_REQUIRED_FIELDS).toEqual(['type']);
  });

  it('exposes the 5 optional fields', () => {
    expect(OKF_OPTIONAL_FIELDS).toEqual(['title', 'description', 'resource', 'tags', 'timestamp']);
  });

  it('exposes reserved filenames', () => {
    expect(OKF_RESERVED_FILENAMES).toEqual(['index.md', 'log.md']);
  });
});

describe('WikiLink ↔ Markdown Link Conversion', () => {
  it('converts wikilinks to markdown links', () => {
    const input = 'Joined with [[tables/customers|customers]] on id.';
    const output = convertWikiLinksToMarkdown(input);
    expect(output).toContain('[customers](tables/customers.md)');
  });

  it('converts wikilinks without pipe to markdown links', () => {
    const input = 'See [[tables/orders]].';
    const output = convertWikiLinksToMarkdown(input);
    expect(output).toContain('[tables/orders](tables/orders.md)');
  });

  it('converts markdown links to wikilinks', () => {
    const input = 'Joined with [customers](tables/customers.md) on id.';
    const output = convertMarkdownLinksToWikiLinks(input);
    expect(output).toContain('[[tables/customers|customers]]');
  });

  it('preserves non-link text in both directions', () => {
    const body = '## Schema\n\n| col | type |\n|-----|------|\n| id | STRING |';
    const withWiki = convertWikiLinksToMarkdown(`${body}\n\nLink [[x|label]]`);
    expect(withWiki).toContain('## Schema');
    expect(withWiki).toContain('| id | STRING |');
  });
});

describe('Type Inference', () => {
  it('infers Metric from tags', () => {
    expect(inferOkfType('metrics/wau.md', { tags: ['metric'] })).toBe('Metric');
  });

  it('infers BigQuery Table from filename with table', () => {
    expect(inferOkfType('tables/orders_table.md', {})).toBe('BigQuery Table');
  });

  it('infers Runbook from filename', () => {
    expect(inferOkfType('runbooks/incident-response.md', {})).toBe('Runbook');
  });

  it('defaults to Concept', () => {
    expect(inferOkfType('some/random/path.md', {})).toBe('Concept');
  });
});

describe('Note Serialization', () => {
  it('serializes frontmatter + content in OKF format', () => {
    const out = serializeOkfNote(
      { type: 'Concept', title: 'Foo', tags: ['a', 'b'], timestamp: '2026-01-01T00:00:00Z' },
      '# Foo\n\nBody.',
    );
    expect(out.startsWith('---\n')).toBe(true);
    expect(out).toContain('type: Concept');
    expect(out).toContain('tags: [a, b]');
    expect(out).toContain('# Foo');
  });

  it('drops created/modified in favor of timestamp', () => {
    const out = serializeOkfNote(
      { type: 'Concept', created: '2026-01-01', modified: '2026-01-02', timestamp: '2026-01-03' },
      'body',
    );
    expect(out).not.toContain('created:');
    expect(out).not.toContain('modified:');
    expect(out).toContain('timestamp: 2026-01-03');
  });
});
