import { expect, test } from "bun:test";
import {
  Gpt56OpenAiCompatPlugin,
  normalizeGpt56Request,
} from "../gpt56-openai-compat.ts";

test("renames legacy max_tokens for GPT-5.6 chat completions", () => {
  const body = normalizeGpt56Request({ max_tokens: 8000 });

  expect(body.max_tokens).toBeUndefined();
  expect(body.max_completion_tokens).toBe(8000);
});

test("is idempotent when the SDK already sends the supported parameter", () => {
  const body: Record<string, unknown> = {
    max_tokens: 8000,
    max_completion_tokens: 4000,
  };

  normalizeGpt56Request(body);
  normalizeGpt56Request(body);

  expect(body).toEqual({ max_completion_tokens: 4000 });
});

test("removes reasoning_effort rejected by constrained endpoints", () => {
  const body = normalizeGpt56Request({ reasoning_effort: "high" });

  expect(body.reasoning_effort).toBeUndefined();
});

test("config hook preserves an existing request transformer", async () => {
  const unrelatedOptions = {};
  const config = {
    provider: {
      unrelated: {
        npm: "@ai-sdk/openai-compatible",
        models: { "other-model": { name: "Other model" } },
        options: unrelatedOptions,
      },
      compatible: {
        npm: "@ai-sdk/openai-compatible",
        models: { "gpt-5.6-example": { name: "GPT-5.6 Example" } },
        options: {
          transformRequestBody: (body: Record<string, unknown>) => ({
            ...body,
            existing: true,
          }),
        },
      },
    },
  };
  const plugin = await (Gpt56OpenAiCompatPlugin as any)({});

  await plugin.config!(config as any);
  const transform = config.provider.compatible.options
    .transformRequestBody as (body: Record<string, unknown>) => Record<string, unknown>;
  const body = transform({ max_tokens: 42 });

  expect(body).toEqual({ existing: true, max_completion_tokens: 42 });
  expect(unrelatedOptions).toEqual({});
});

test("ignores GPT-5.6 models from providers using another SDK", async () => {
  const options = {};
  const config = {
    provider: {
      incompatible: {
        npm: "@ai-sdk/openai",
        models: { "gpt-5.6-example": { name: "GPT-5.6 Example" } },
        options,
      },
    },
  };
  const plugin = await (Gpt56OpenAiCompatPlugin as any)({});

  await plugin.config!(config as any);

  expect(options).toEqual({});
});
