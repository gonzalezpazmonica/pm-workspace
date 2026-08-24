import { test, expect, beforeEach, afterEach } from "bun:test";
import { blockCommitToMain } from "../guards/block-commit-to-main.ts";

// TEST_BRANCH simula la rama actual sin depender del repo real.
const OLD = process.env.TEST_BRANCH;
const OLD_ALLOW = process.env.SAVIA_ALLOW_MAIN_COMMIT;
beforeEach(() => { delete process.env.SAVIA_ALLOW_MAIN_COMMIT; });
afterEach(() => {
  if (OLD === undefined) delete process.env.TEST_BRANCH; else process.env.TEST_BRANCH = OLD;
  if (OLD_ALLOW === undefined) delete process.env.SAVIA_ALLOW_MAIN_COMMIT; else process.env.SAVIA_ALLOW_MAIN_COMMIT = OLD_ALLOW;
});

// ── Debe BLOQUEAR ───────────────────────────────────────────────────────────

test("bloquea git commit en main", async () => {
  process.env.TEST_BRANCH = "main";
  const input = { tool: "bash", args: { command: "git commit -m 'feat: x'" } };
  await expect(blockCommitToMain(input as any, {} as any)).rejects.toThrow(/BLOCKED \[commit-to-main\]/);
});

test("bloquea git commit en master", async () => {
  process.env.TEST_BRANCH = "master";
  const input = { tool: "bash", args: { command: "git commit -m 'x'" } };
  await expect(blockCommitToMain(input as any, {} as any)).rejects.toThrow(/BLOCKED \[commit-to-main\]/);
});

test("bloquea git commit --amend en main", async () => {
  process.env.TEST_BRANCH = "main";
  const input = { tool: "bash", args: { command: "git commit --amend -m 'x'" } };
  await expect(blockCommitToMain(input as any, {} as any)).rejects.toThrow(/BLOCKED \[commit-to-main\]/);
});

// ── Bypass consciente de la operadora ──────────────────────────────────────

test("bypass SAVIA_ALLOW_MAIN_COMMIT=1 permite commit en main (registrado)", async () => {
  process.env.TEST_BRANCH = "main";
  process.env.SAVIA_ALLOW_MAIN_COMMIT = "1";
  const input = { tool: "bash", args: { command: "git commit -m 'bypass intencional'" } };
  await expect(blockCommitToMain(input as any, {} as any)).resolves.toBeUndefined();
});

// ── Debe PERMITIR ──────────────────────────────────────────────────────────

test("permite git commit en rama agent/*", async () => {
  process.env.TEST_BRANCH = "agent/overnight-20260824-x";
  const input = { tool: "bash", args: { command: "git commit -m 'feat: correcto'" } };
  await expect(blockCommitToMain(input as any, {} as any)).resolves.toBeUndefined();
});

test("permite git commit en feature/*", async () => {
  process.env.TEST_BRANCH = "feature/foo";
  const input = { tool: "bash", args: { command: "git commit -m 'x'" } };
  await expect(blockCommitToMain(input as any, {} as any)).resolves.toBeUndefined();
});

test("no interviene en comandos que no son git commit", async () => {
  process.env.TEST_BRANCH = "main";
  for (const cmd of ["git branch --show-current", "git status", "ls", "git push origin main"]) {
    const input = { tool: "bash", args: { command: cmd } };
    await expect(blockCommitToMain(input as any, {} as any)).resolves.toBeUndefined();
  }
});