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

  it('exposes SE-309 governance functions', async () => {
    const mod = await import('../src/knowledge/index.js');
    expect(typeof mod.createDecisionRecord).toBe('function');
    expect(typeof mod.validateDecision).toBe('function');
    expect(typeof mod.detectConflicts).toBe('function');
    expect(typeof mod.resolveConflict).toBe('function');
    expect(typeof mod.promote).toBe('function');
    expect(typeof mod.getActiveState).toBe('function');
  });
});
