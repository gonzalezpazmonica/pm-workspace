// savia-foundation.test.ts — SPEC-127 Slice 2b-ii (foundation + 5 guards)
//
// Verifies the foundation plugin loads and the registered tool.execute.before
// dispatcher chains the 5 TIER-1 guards. Per-guard correctness is covered
// by their individual *.test.ts files.

import { test, expect } from "bun:test";
import { SaviaFoundationPlugin } from "../savia-foundation.ts";

const ctx = {
  project: { name: "test" } as any,
  client: {} as any,
  $: () => ({}) as any,
  directory: "/tmp/test",
  worktree: "/tmp/test",
};

test("foundation plugin is an async function", () => {
  expect(typeof SaviaFoundationPlugin).toBe("function");
  expect(SaviaFoundationPlugin.constructor.name).toBe("AsyncFunction");
});

test("foundation plugin returns hooks object with tool.execute.before", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  expect(typeof hooks["tool.execute.before"]).toBe("function");
});

test("dispatcher: clean Bash command passes through all guards", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  const input = { tool: "bash", args: { command: "ls -la /tmp" } };
  await expect(hooks["tool.execute.before"](input, {})).resolves.toBeUndefined();
});

test("dispatcher: dangerous Bash (rm -rf /) is blocked by validate-bash-global", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  const input = { tool: "bash", args: { command: "rm -rf /" } };
  await expect(hooks["tool.execute.before"](input, {})).rejects.toThrow(/rm -rf/);
});

test("dispatcher: AWS key in Bash blocked by credential-leak guard", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  const input = { tool: "bash", args: { command: "X=" + "AKIA" + "IOSFODNN7EXAMPLE" } };
  await expect(hooks["tool.execute.before"](input, {})).rejects.toThrow(/AWS/);
});

test("dispatcher: clean Edit on docs passes guards (md is TDD-exempt)", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  // SPEC-155 + tool-call-healing: filePath must exist on disk. Resolve relative
  // to this test file so it works regardless of suite cwd ordering.
  const { fileURLToPath } = await import("node:url");
  const { dirname, resolve } = await import("node:path");
  const here = dirname(fileURLToPath(import.meta.url));
  const realPath = resolve(here, "..", "..", "..", "README.md");
  const input = {
    tool: "edit",
    args: { file_path: realPath, content: "Just a doc." },
  };
  await expect(hooks["tool.execute.before"](input, {})).resolves.toBeUndefined();
});

test("dispatcher: foundation does not throw on partial context", async () => {
  const minimal: any = { directory: "/tmp/test" };
  const hooks: any = await SaviaFoundationPlugin(minimal);
  expect(hooks).toBeDefined();
  expect(typeof hooks["tool.execute.before"]).toBe("function");
});

// ── SPEC-155 golden tests: real OpenCode v1.14+ shape ────────────────────────
// Per https://opencode.ai/docs/plugins/: input.tool (string), output.args (mutable).
// These tests assert guards correctly read from output.args, not input.args.

test("SPEC-155: v1.14 shape — clean bash passes when args live on output.args", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  const input = { tool: "bash" };
  const output = { args: { command: "ls -la /tmp" } };
  await expect(hooks["tool.execute.before"](input, output)).resolves.toBeUndefined();
});

test("SPEC-155: v1.14 shape — rm -rf / blocked when args on output.args", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  const input = { tool: "bash" };
  const output = { args: { command: "rm -rf /" } };
  await expect(hooks["tool.execute.before"](input, output)).rejects.toThrow(/rm -rf/);
});

test("SPEC-155: v1.14 shape — AWS key blocked when args on output.args", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  const input = { tool: "bash" };
  const output = { args: { command: "X=" + "AKIA" + "IOSFODNN7EXAMPLE" } };
  await expect(hooks["tool.execute.before"](input, output)).rejects.toThrow(/AWS/);
});

test("SPEC-155: v1.14 shape — empty output.args does NOT spurious-block read tool", async () => {
  // Pre-SPEC-155 bug: tool-call-healing rejected this with "empty file_path"
  // because it read input.args (undefined) instead of output.args.
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  const input = { tool: "read" };
  const output = { args: { filePath: "/tmp/some-real-path.txt" } };
  // Either passes or rejects for a non-args reason — but NOT "empty file_path".
  try {
    await hooks["tool.execute.before"](input, output);
  } catch (e: any) {
    expect(String(e?.message ?? e)).not.toMatch(/empty file_path/i);
  }
});
