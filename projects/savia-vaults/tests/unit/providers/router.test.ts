import { describe, it, expect, vi, afterEach } from 'vitest';
import { ProviderRouter } from '../../../src/providers/router.js';
import { ProviderError } from '../../../src/providers/types.js';
import type { LlmProvider, LlmRequest, LlmResponse } from '../../../src/providers/types.js';

function mockProvider(name: string, tiers: string[]): LlmProvider {
  return {
    name,
    tiers: tiers as ('heavy' | 'mid' | 'fast')[],
    complete: vi.fn<[LlmRequest], Promise<LlmResponse>>(),
    healthCheck: vi.fn<[], Promise<boolean>>(),
  };
}

const req: LlmRequest = { tier: 'heavy', messages: [{ role: 'user', content: 'hi' }] };

describe('ProviderRouter', () => {
  let router: ProviderRouter;
  afterEach(() => { if (router) router.stop(); });

  it('routes to healthy provider', async () => {
    const p = mockProvider('deepseek', ['heavy', 'mid', 'fast']);
    vi.mocked(p.complete).mockResolvedValue({ content: 'ok', provider: 'deepseek', tier: 'heavy', tokensUsed: 10, latencyMs: 100 });
    vi.mocked(p.healthCheck).mockResolvedValue(true);
    router = new ProviderRouter({ providers: [p], fallbackOrder: ['heavy'], healthCheckIntervalMs: 60_000 });
    const r = await router.complete(req);
    expect(r.provider).toBe('deepseek');
  });

  it('fails over when first provider fails', async () => {
    const a = mockProvider('a', ['heavy']);
    const b = mockProvider('b', ['heavy']);
    vi.mocked(a.complete).mockRejectedValue(new Error('down'));
    vi.mocked(a.healthCheck).mockResolvedValue(true);
    vi.mocked(b.complete).mockResolvedValue({ content: 'backup', provider: 'b', tier: 'heavy', tokensUsed: 5, latencyMs: 200 });
    vi.mocked(b.healthCheck).mockResolvedValue(true);
    router = new ProviderRouter({ providers: [a, b], fallbackOrder: ['heavy'], healthCheckIntervalMs: 60_000 });
    const r = await router.complete(req);
    expect(r.provider).toBe('b');
  });

  it('throws ALL_PROVIDERS_DOWN when all fail', async () => {
    const p = mockProvider('a', ['heavy']);
    vi.mocked(p.complete).mockRejectedValue(new Error('down'));
    vi.mocked(p.healthCheck).mockResolvedValue(true);
    router = new ProviderRouter({ providers: [p], fallbackOrder: ['heavy'], healthCheckIntervalMs: 60_000 });
    await expect(router.complete(req)).rejects.toThrow(ProviderError);
    await expect(router.complete(req)).rejects.toMatchObject({ code: 'ALL_PROVIDERS_DOWN' });
  });

  it('skips unhealthy providers', async () => {
    const a = mockProvider('a', ['heavy']);
    const b = mockProvider('b', ['heavy']);
    vi.mocked(a.healthCheck).mockResolvedValue(false);
    vi.mocked(b.complete).mockResolvedValue({ content: 'ok', provider: 'b', tier: 'heavy', tokensUsed: 1, latencyMs: 10 });
    vi.mocked(b.healthCheck).mockResolvedValue(true);
    router = new ProviderRouter({ providers: [a, b], fallbackOrder: ['heavy'], healthCheckIntervalMs: 60_000 });
    await router.healthCheck(); // wait for initial health check
    const r = await router.complete(req);
    expect(r.provider).toBe('b');
    expect(a.complete).not.toHaveBeenCalled();
  });

  it('healthCheck reports all', async () => {
    const a = mockProvider('a', ['heavy']);
    const b = mockProvider('b', ['heavy']);
    vi.mocked(a.healthCheck).mockResolvedValue(true);
    vi.mocked(b.healthCheck).mockResolvedValue(false);
    router = new ProviderRouter({ providers: [a, b], fallbackOrder: ['heavy'], healthCheckIntervalMs: 60_000 });
    const r = await router.healthCheck();
    expect(r).toEqual({ a: true, b: false });
  });

  it('activeProvider returns first healthy', () => {
    const p = mockProvider('deepseek', ['heavy']);
    vi.mocked(p.healthCheck).mockResolvedValue(true);
    router = new ProviderRouter({ providers: [p], fallbackOrder: ['heavy'], healthCheckIntervalMs: 60_000 });
    expect(router.activeProvider('heavy')).toBe('deepseek');
    expect(router.activeProvider('fast')).toBe('none');
  });
});
