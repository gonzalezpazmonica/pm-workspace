import { test, expect } from "bun:test";
import { blockBlindSigning } from "../guards/block-blind-signing.ts";

// ── Should BLOCK (sign without prior audit) ───────────────────────────────

test("blockBlindSigning: blocks bare sign call", async () => {
  const input = { tool: "bash", args: { command: "bash scripts/confidentiality-sign.sh sign" } };
  await expect(blockBlindSigning(input as any, {} as any)).rejects.toThrow(/BLOCKED \[blind-signing\]/);
});

test("blockBlindSigning: blocks sign with extra flags but no audit", async () => {
  const input = { tool: "bash", args: { command: "cd /repo && bash scripts/confidentiality-sign.sh sign 2>&1" } };
  await expect(blockBlindSigning(input as any, {} as any)).rejects.toThrow(/BLOCKED \[blind-signing\]/);
});

test("blockBlindSigning: blocks sign even with git add before it", async () => {
  const input = { tool: "bash", args: { command: "git add .confidentiality-signature && bash scripts/confidentiality-sign.sh sign" } };
  await expect(blockBlindSigning(input as any, {} as any)).rejects.toThrow(/BLOCKED \[blind-signing\]/);
});

test("blockBlindSigning: error message explains required steps", async () => {
  const input = { tool: "bash", args: { command: "bash scripts/confidentiality-sign.sh sign" } };
  await expect(blockBlindSigning(input as any, {} as any)).rejects.toThrow(/N3\/N4/);
});

// ── Should ALLOW (audit chained or verify) ───────────────────────────────

test("blockBlindSigning: allows verify (read-only)", async () => {
  const input = { tool: "bash", args: { command: "bash scripts/confidentiality-sign.sh verify" } };
  await expect(blockBlindSigning(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockBlindSigning: allows status (read-only)", async () => {
  const input = { tool: "bash", args: { command: "bash scripts/confidentiality-sign.sh status" } };
  await expect(blockBlindSigning(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockBlindSigning: allows audit && sign chain", async () => {
  const input = { tool: "bash", args: { command: "bash scripts/confidentiality-sign.sh audit && bash scripts/confidentiality-sign.sh sign" } };
  await expect(blockBlindSigning(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockBlindSigning: allows pii-scan before sign", async () => {
  const input = { tool: "bash", args: { command: "bash scripts/pii-scan.sh && bash scripts/confidentiality-sign.sh sign" } };
  await expect(blockBlindSigning(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockBlindSigning: allows SAVIA_CONFIDENTIALITY_AUDITED=1 env var", async () => {
  const input = { tool: "bash", args: { command: "SAVIA_CONFIDENTIALITY_AUDITED=1 bash scripts/confidentiality-sign.sh sign" } };
  await expect(blockBlindSigning(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockBlindSigning: allows data-sovereignty-audit before sign", async () => {
  const input = { tool: "bash", args: { command: "bash scripts/data-sovereignty-audit.sh && bash scripts/confidentiality-sign.sh sign" } };
  await expect(blockBlindSigning(input as any, {} as any)).resolves.toBeUndefined();
});

// ── Non-sign commands ─────────────────────────────────────────────────────

test("blockBlindSigning: ignores unrelated bash commands", async () => {
  const input = { tool: "bash", args: { command: "git push origin my-branch" } };
  await expect(blockBlindSigning(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockBlindSigning: ignores non-bash tools", async () => {
  const input = { tool: "edit", args: { command: "bash scripts/confidentiality-sign.sh sign" } };
  await expect(blockBlindSigning(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockBlindSigning: ignores empty input", async () => {
  await expect(blockBlindSigning({} as any, {} as any)).resolves.toBeUndefined();
});
