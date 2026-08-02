import type { LlmProvider, LlmRequest, LlmResponse, ProviderTier } from './types.js';

export interface ProviderRouterConfig {
  providers: LlmProvider[];
  fallbackOrder: ProviderTier[];
  healthCheckIntervalMs: number;
}

export interface ProviderRouter {
  complete(request: LlmRequest): Promise<LlmResponse>;
  healthCheck(): Promise<Record<string, boolean>>;
  activeProvider(tier: ProviderTier): string;
}
