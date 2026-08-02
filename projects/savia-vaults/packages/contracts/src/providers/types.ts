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
