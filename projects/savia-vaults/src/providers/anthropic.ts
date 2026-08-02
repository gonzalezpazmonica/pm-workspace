import type { LlmProvider, LlmRequest, LlmResponse, ProviderTier } from './types.js';

export class AnthropicProvider implements LlmProvider {
  readonly name = 'claude';
  readonly tiers: ProviderTier[] = ['heavy', 'mid'];

  private baseUrl: string;
  private apiKey: string;

  constructor(config?: { baseUrl?: string; apiKey?: string }) {
    this.baseUrl = config?.baseUrl ?? process.env.ANTHROPIC_BASE_URL ?? 'https://api.anthropic.com';
    this.apiKey = config?.apiKey ?? process.env.ANTHROPIC_API_KEY ?? '';
  }

  async complete(request: LlmRequest): Promise<LlmResponse> {
    const start = Date.now();
    const model = this.mapTierToModel(request.tier);

    const systemMsg = request.messages.find((m) => m.role === 'system')?.content;
    const userMsgs = request.messages
      .filter((m) => m.role !== 'system')
      .map((m) => ({ role: m.role, content: m.content }));

    const response = await fetch(`${this.baseUrl}/v1/messages`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': this.apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model,
        system: systemMsg,
        messages: userMsgs,
        max_tokens: request.maxTokens ?? 4096,
      }),
    });

    if (response.status === 429) {
      throw new Error('Anthropic rate limited');
    }
    if (!response.ok) {
      throw new Error(`Anthropic error ${response.status}: ${await response.text()}`);
    }

    const data = (await response.json()) as {
      content: { type: string; text: string }[];
      usage: { input_tokens: number; output_tokens: number };
    };

    return {
      content: data.content[0].text,
      provider: this.name,
      tier: request.tier,
      tokensUsed: data.usage.input_tokens + data.usage.output_tokens,
      latencyMs: Date.now() - start,
    };
  }

  async healthCheck(): Promise<boolean> {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 5_000);

      const response = await fetch(`${this.baseUrl}/v1/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-3-haiku-20240307',
          max_tokens: 1,
          messages: [{ role: 'user', content: '.' }],
        }),
        signal: controller.signal,
      });
      clearTimeout(timeout);
      return response.ok;
    } catch {
      return false;
    }
  }

  private mapTierToModel(tier: ProviderTier): string {
    const envKey = `ANTHROPIC_MODEL_${tier.toUpperCase()}`;
    return process.env[envKey] ?? 'claude-sonnet-4-20250514';
  }
}
