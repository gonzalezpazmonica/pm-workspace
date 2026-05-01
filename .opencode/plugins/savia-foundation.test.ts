// savia-foundation.test.ts — SPEC-127 Slice 2b-ii (foundation + 5 guards)
//
// Verifies the foundation plugin loads and the registered tool.execute.before
// dispatcher chains the 5 TIER-1 guards. Per-guard correctness is covered
// by their individual *.test.ts files.

import { test, expect } from "bun:test";
import { SaviaFoundationPlugin } from "./savia-foundation.ts";

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
  const input = { tool: "bash", args: { command: "X=AKIAIOSFODNN7EXAMPLE" } };
  await expect(hooks["tool.execute.before"](input, {})).rejects.toThrow(/AWS/);
});

test("dispatcher: clean Edit on docs passes guards (md is TDD-exempt)", async () => {
  const hooks: any = await SaviaFoundationPlugin(ctx as any);
  const input = {
    tool: "edit",
    args: { file_path: "/repo/docs/x.md", content: "Just a doc." },
  };
  await expect(hooks["tool.execute.before"](input, {})).resolves.toBeUndefined();
});

test("dispatcher: foundation does not throw on partial context", async () => {
  const minimal: any = { directory: "/tmp/test" };
  const hooks: any = await SaviaFoundationPlugin(minimal);
  expect(hooks).toBeDefined();
  expect(typeof hooks["tool.execute.before"]).toBe("function");
});
