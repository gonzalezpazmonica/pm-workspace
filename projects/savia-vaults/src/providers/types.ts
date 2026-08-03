export type ProviderTier = 'heavy' | 'mid' | 'fast';

export interface LlmRequest {
  tier: ProviderTier;
  messages: { role: 'system' | 'user' | 'assistant'; content: string }[];
  temperature?: number;
  maxTokens?: number;
}

export interface LlmResponse {
  content: string;
  provider: string;
  tier: ProviderTier;
  tokensUsed: number;
  latencyMs: number;
}

export interface LlmProvider {
  readonly name: string;
  readonly tiers: ProviderTier[];
  complete(request: LlmRequest): Promise<LlmResponse>;
  healthCheck(): Promise<boolean>;
}

export interface ProviderRouterConfig {
  providers: LlmProvider[];
  fallbackOrder: ProviderTier[];
  healthCheckIntervalMs: number;
}

export interface ProviderHealth {
  name: string;
  healthy: boolean;
  lastCheck: number;
  latencyMs: number;
}

export class ProviderError extends Error {
  constructor(
    message: string,
    public readonly code: 'ALL_PROVIDERS_DOWN' | 'PROVIDER_TIMEOUT' | 'PROVIDER_ERROR' | 'RATE_LIMITED',
    public readonly providerName?: string,
  ) {
    super(message);
    this.name = 'ProviderError';
  }
}
