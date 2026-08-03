import type { LlmProvider, LlmRequest, LlmResponse, ProviderTier } from './types.js';
import { ProviderError } from './types.js';
import type { ProviderRouterConfig, ProviderHealth } from './types.js';

export class ProviderRouter {
  private providers: LlmProvider[];
  private fallbackOrder: ProviderTier[];
  private health: Map<string, ProviderHealth> = new Map();
  private healthTimer: ReturnType<typeof setInterval> | null = null;

  constructor(private config: ProviderRouterConfig) {
    this.providers = config.providers;
    this.fallbackOrder = config.fallbackOrder;
    this.startHealthChecks();
  }

  async complete(request: LlmRequest): Promise<LlmResponse> {
    const candidates = this.getCandidates(request.tier);
    if (candidates.length === 0) {
      throw new ProviderError(`No healthy providers for tier ${request.tier}`, 'ALL_PROVIDERS_DOWN');
    }

    let lastError: Error | null = null;
    for (const provider of candidates) {
      try {
        const result = await this.withTimeout(
          provider.complete(request),
          30_000,
          `Provider ${provider.name} timed out`,
        );
        return result;
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
        this.markUnhealthy(provider.name);
      }
    }

    throw new ProviderError(
      `All providers failed for tier ${request.tier}: ${lastError?.message}`,
      'ALL_PROVIDERS_DOWN',
    );
  }

  async healthCheck(): Promise<Record<string, boolean>> {
    const results: Record<string, boolean> = {};
    await Promise.all(
      this.providers.map(async (p) => {
        const start = Date.now();
        try {
          const healthy = await this.withTimeout(p.healthCheck(), 5_000, '');
          const latency = Date.now() - start;
          this.health.set(p.name, { name: p.name, healthy, lastCheck: Date.now(), latencyMs: latency });
          results[p.name] = healthy;
        } catch {
          this.health.set(p.name, { name: p.name, healthy: false, lastCheck: Date.now(), latencyMs: -1 });
          results[p.name] = false;
        }
      }),
    );
    return results;
  }

  activeProvider(tier: ProviderTier): string {
    const candidates = this.getCandidates(tier);
    return candidates[0]?.name ?? 'none';
  }

  stop(): void {
    if (this.healthTimer) {
      clearInterval(this.healthTimer);
      this.healthTimer = null;
    }
  }

  private getCandidates(tier: ProviderTier): LlmProvider[] {
    return this.providers.filter(
      (p) => p.tiers.includes(tier) && this.isHealthy(p.name),
    );
  }

  private isHealthy(name: string): boolean {
    const h = this.health.get(name);
    return h ? h.healthy : true;
  }

  private markUnhealthy(name: string): void {
    this.health.set(name, { name, healthy: false, lastCheck: Date.now(), latencyMs: -1 });
  }

  private startHealthChecks(): void {
    this.healthCheck().catch(() => {});
    this.healthTimer = setInterval(() => {
      this.healthCheck().catch(() => {});
    }, this.config.healthCheckIntervalMs);
  }

  private async withTimeout<T>(promise: Promise<T>, ms: number, msg: string): Promise<T> {
    const timeout = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new ProviderError(msg, 'PROVIDER_TIMEOUT')), ms),
    );
    return Promise.race([promise, timeout]);
  }
}
