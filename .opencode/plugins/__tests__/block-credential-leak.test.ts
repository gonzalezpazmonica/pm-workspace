import { test, expect } from "bun:test";
import { blockCredentialLeak } from "../guards/block-credential-leak.ts";

test("blockCredentialLeak: throws on AWS key in bash command", async () => {
  const input = { tool: "bash", args: { command: "export X=AKIAIOSFODNN7EXAMPLE" } };
  await expect(blockCredentialLeak(input as any, {} as any)).rejects.toThrow(/AWS/);
});

test("blockCredentialLeak: throws on Anthropic key", async () => {
  const input = { tool: "bash", args: { command: "ANTHROPIC_API_KEY=sk-ant-api03-AbCdEfGhIjKlMnOpQrStUv" } };
  await expect(blockCredentialLeak(input as any, {} as any)).rejects.toThrow(/Anthropic/);
});

test("blockCredentialLeak: silent on clean command", async () => {
  const input = { tool: "bash", args: { command: "ls -la" } };
  await expect(blockCredentialLeak(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockCredentialLeak: skips non-bash tools (per bash hook semantics)", async () => {
  const input = { tool: "edit", args: { command: "sk-ant-api03-AAAAAAAAAAAAAAAAAAAA" } };
  await expect(blockCredentialLeak(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockCredentialLeak: empty input is no-op", async () => {
  await expect(blockCredentialLeak({} as any, {} as any)).resolves.toBeUndefined();
});
