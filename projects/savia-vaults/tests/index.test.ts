import { describe, it, expect } from 'vitest';

describe('knowledge/index barrel', () => {
  it('exposes OKF interop functions', async () => {
    const mod = await import('../src/knowledge/index.js');
    expect(typeof mod.validateOkfFrontmatter).toBe('function');
    expect(typeof mod.convertWikiLinksToMarkdown).toBe('function');
    expect(typeof mod.convertMarkdownLinksToWikiLinks).toBe('function');
    expect(typeof mod.inferOkfType).toBe('function');
    expect(typeof mod.serializeOkfNote).toBe('function');
    expect(typeof mod.checkOkfConformance).toBe('function');
    expect(typeof mod.exportOkfBundle).toBe('function');
    expect(typeof mod.importOkfBundle).toBe('function');
    expect(typeof mod.extractWikiLinks).toBe('function');
  });
});
