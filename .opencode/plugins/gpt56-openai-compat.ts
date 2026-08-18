import type { Plugin } from "@opencode-ai/plugin";

type RequestBody = Record<string, unknown>;
type RequestTransformer = (body: RequestBody) => RequestBody;

export function normalizeGpt56Request(body: RequestBody): RequestBody {
  if (body.max_tokens != null) {
    body.max_completion_tokens ??= body.max_tokens;
    delete body.max_tokens;
  }

  delete body.reasoning_effort;
  return body;
}

export const Gpt56OpenAiCompatPlugin = (async () => ({
  config: async (config: any) => {
    for (const provider of Object.values(config.provider ?? {}) as any[]) {
      const isOpenAiCompatible = provider.npm === "@ai-sdk/openai-compatible";
      const hasGpt56Model = Object.entries(provider.models ?? {}).some(
        ([id, model]: [string, any]) =>
          `${id} ${model?.name ?? ""}`.toLowerCase().includes("gpt-5.6"),
      );
      if (!isOpenAiCompatible || !hasGpt56Model || !provider.options) continue;

      const previous = provider.options.transformRequestBody as
        | RequestTransformer
        | undefined;
      provider.options.transformRequestBody = (body: RequestBody) =>
        normalizeGpt56Request(previous ? previous(body) : body);
    }
  },
})) satisfies Plugin;

export default Gpt56OpenAiCompatPlugin;
