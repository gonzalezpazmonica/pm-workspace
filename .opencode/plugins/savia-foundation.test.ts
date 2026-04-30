// savia-foundation.test.ts — SPEC-127 Slice 2b-i
//
// Foundation contract tests. Verifies the plugin loads, exports the
// expected shape, and is a no-op (returns empty hooks object). Actual
// hook behaviour tests are added incrementally with each ported hook in
// Slice 2b-ii.
//
// This file is currently a contract scaffold — the runtime test harness
// (Bun test runner) is not yet wired into CI. Slice 2b-ii adds the
// runner. For now the contract is enforced by BATS structural tests in
// tests/structure/test-spec-127-slice2b-i-ts-toolchain.bats.

import { test, expect } from "bun:test";
import { SaviaFoundationPlugin } from "./savia-foundation.ts";

test("foundation plugin is an async function", () => {
  expect(typeof SaviaFoundationPlugin).toBe("function");
  expect(SaviaFoundationPlugin.constructor.name).toBe("AsyncFunction");
});

test("foundation plugin returns empty hooks object (no-op stub)", async () => {
  const ctx = {
    project: { name: "test" },
    client: {} as any,
    $: () => ({}) as any,
    directory: "/tmp/test",
    worktree: "/tmp/test",
  };
  const hooks = await SaviaFoundationPlugin(ctx as any);
  expect(hooks).toEqual({});
});

test("foundation plugin does not throw on partial context", async () => {
  // OpenCode v1.14 may pass minimal context in some scenarios; ensure
  // the foundation is robust to missing optional fields.
  const ctx = { directory: "/tmp/test" };
  const hooks = await SaviaFoundationPlugin(ctx as any);
  expect(hooks).toBeDefined();
});
