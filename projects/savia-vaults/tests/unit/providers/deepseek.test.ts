import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { DeepSeekProvider } from '../../../src/providers/deepseek.js';

describe('DeepSeekProvider', () => {
  let provider: DeepSeekProvider;
  beforeEach(() => {
    global.fetch = vi.fn();
    provider = new DeepSeekProvider({ apiKey: 'test-key', baseUrl: 'http://localhost:9999' });
  });
  afterEach(() => vi.restoreAllMocks());

  it('name is deepseek', () => expect(provider.name).toBe('deepseek'));
  it('has three tiers', () => expect(provider.tiers).toEqual(['heavy', 'mid', 'fast']));
  it('healthy on ok response', async () => {
    vi.mocked(global.fetch).mockResolvedValue({ ok: true } as Response);
    expect(await provider.healthCheck()).toBe(true);
  });
  it('unhealthy on error', async () => {
    vi.mocked(global.fetch).mockRejectedValue(new Error('fail'));
    expect(await provider.healthCheck()).toBe(false);
  });
  it('throws on 429', async () => {
    vi.mocked(global.fetch).mockResolvedValue({ status: 429, ok: false } as Response);
    await expect(provider.complete({ tier: 'heavy', messages: [{ role: 'user', content: 'hi' }] }))
      .rejects.toThrow('rate limited');
  });
});
