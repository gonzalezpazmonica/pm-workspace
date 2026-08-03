import type { LlmProvider, LlmRequest, LlmResponse, ProviderTier } from './types.js';

export class DeepSeekProvider implements LlmProvider {
  readonly name = 'deepseek';
  readonly tiers: ProviderTier[] = ['heavy', 'mid', 'fast'];

  private baseUrl: string;
  private apiKey: string;

  constructor(config?: { baseUrl?: string; apiKey?: string }) {
    this.baseUrl = config?.baseUrl ?? process.env.DEEPSEEK_BASE_URL ?? 'https://api.deepseek.com';
    this.apiKey = config?.apiKey ?? process.env.DEEPSEEK_API_KEY ?? process.env.OPENROUTER_API_KEY ?? '';
  }

  async complete(request: LlmRequest): Promise<LlmResponse> {
    const start = Date.now();
    const model = this.mapTierToModel(request.tier);

    const response = await fetch(`${this.baseUrl}/v1/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: request.messages,
        temperature: request.temperature ?? 0.7,
        max_tokens: request.maxTokens ?? 4096,
      }),
    });

    if (response.status === 429) {
      throw new Error('DeepSeek rate limited');
    }
    if (!response.ok) {
      throw new Error(`DeepSeek error ${response.status}: ${await response.text()}`);
    }

    const data = (await response.json()) as {
      choices: { message: { content: string } }[];
      usage: { total_tokens: number };
    };

    return {
      content: data.choices[0].message.content,
      provider: this.name,
      tier: request.tier,
      tokensUsed: data.usage.total_tokens,
      latencyMs: Date.now() - start,
    };
  }

  async healthCheck(): Promise<boolean> {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 5_000);

      const response = await fetch(`${this.baseUrl}/v1/models`, {
        headers: { Authorization: `Bearer ${this.apiKey}` },
        signal: controller.signal,
      });
      clearTimeout(timeout);
      return response.ok;
    } catch {
      return false;
    }
  }

  private mapTierToModel(tier: ProviderTier): string {
    const envKey = `DEEPSEEK_MODEL_${tier.toUpperCase()}`;
    return process.env[envKey] ?? 'deepseek-chat';
  }
}
