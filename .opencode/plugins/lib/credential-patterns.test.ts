import { test, expect } from "bun:test";
import { detectCredentialLeak } from "./credential-patterns.ts";

test("detectCredentialLeak: AWS access key", () => {
  const r = detectCredentialLeak("export key=AKIAIOSFODNN7EXAMPLE");
  expect(r).not.toBeNull();
  expect(r!.kind).toBe("aws-key");
});

test("detectCredentialLeak: GitHub token", () => {
  const r = detectCredentialLeak("token=ghp_abcdefghijklmnopqrstuvwxyz0123456789");
  expect(r).not.toBeNull();
  expect(r!.kind).toBe("github-token");
});

test("detectCredentialLeak: OpenAI key", () => {
  const r = detectCredentialLeak("sk-abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKL");
  expect(r).not.toBeNull();
  expect(r!.kind).toBe("openai-key");
});

test("detectCredentialLeak: Anthropic key", () => {
  const r = detectCredentialLeak("ANTHROPIC_API_KEY=sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWxYz");
  expect(r).not.toBeNull();
  expect(r!.kind).toBe("anthropic-key");
});

test("detectCredentialLeak: PEM private key header", () => {
  const r = detectCredentialLeak("cat << 'EOF'\n-----BEGIN RSA PRIVATE KEY-----");
  expect(r).not.toBeNull();
  expect(r!.kind).toBe("private-key");
});

test("detectCredentialLeak: chmod 777 in command (sanity, NOT a credential)", () => {
  expect(detectCredentialLeak("chmod 777 /tmp/x")).toBeNull();
});

test("detectCredentialLeak: clean command returns null", () => {
  expect(detectCredentialLeak("ls -la /tmp")).toBeNull();
  expect(detectCredentialLeak("git status")).toBeNull();
});

test("detectCredentialLeak: generic password=... pattern", () => {
  const r = detectCredentialLeak("export password=Sup3rSecr3tP@ssw0rd123");
  expect(r).not.toBeNull();
  expect(r!.kind).toBe("generic-secret");
});

test("detectCredentialLeak: docker login --password inline", () => {
  const r = detectCredentialLeak("docker login --password mypass123");
  expect(r).not.toBeNull();
  expect(r!.kind).toBe("docker-password");
});

test("detectCredentialLeak: empty command returns null", () => {
  expect(detectCredentialLeak("")).toBeNull();
});
