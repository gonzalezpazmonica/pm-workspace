import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { AnthropicProvider } from '../../../src/providers/anthropic.js';

describe('AnthropicProvider', () => {
  let provider: AnthropicProvider;
  beforeEach(() => {
    global.fetch = vi.fn();
    provider = new AnthropicProvider({ apiKey: 'test-key', baseUrl: 'http://localhost:9999' });
  });
  afterEach(() => vi.restoreAllMocks());

  it('name is claude', () => expect(provider.name).toBe('claude'));
  it('has two tiers', () => expect(provider.tiers).toEqual(['heavy', 'mid']));
  it('healthy on ok', async () => {
    vi.mocked(global.fetch).mockResolvedValue({ ok: true } as Response);
    expect(await provider.healthCheck()).toBe(true);
  });
  it('unhealthy on error', async () => {
    vi.mocked(global.fetch).mockRejectedValue(new Error('timeout'));
    expect(await provider.healthCheck()).toBe(false);
  });
});
