import { test, expect } from "bun:test";
import { tddGateForPath, tddGate } from "./tdd-gate.ts";

// Static helper tests — exercise the path classification logic without
// requiring filesystem access to find tests.

test("tddGateForPath: production .ts file requires test", () => {
  const r = tddGateForPath("/repo/src/orderService.ts");
  expect(r.needsTest).toBe(true);
});

test("tddGateForPath: test file is exempt (.test.ts)", () => {
  const r = tddGateForPath("/repo/src/orderService.test.ts");
  expect(r.needsTest).toBe(false);
});

test("tddGateForPath: spec file is exempt (.spec.ts)", () => {
  const r = tddGateForPath("/repo/src/orderService.spec.ts");
  expect(r.needsTest).toBe(false);
});

test("tddGateForPath: file under /tests/ dir is exempt", () => {
  const r = tddGateForPath("/repo/tests/orderService.ts");
  expect(r.needsTest).toBe(false);
});

test("tddGateForPath: migration file is exempt", () => {
  const r = tddGateForPath("/repo/src/migrations/0001_initial.ts");
  expect(r.needsTest).toBe(false);
});

test("tddGateForPath: DTO file is exempt", () => {
  const r = tddGateForPath("/repo/src/order.dto.ts");
  expect(r.needsTest).toBe(false);
});

test("tddGateForPath: Program.cs is exempt", () => {
  const r = tddGateForPath("/repo/src/Program.cs");
  expect(r.needsTest).toBe(false);
});

test("tddGateForPath: tsconfig.json is exempt (config)", () => {
  const r = tddGateForPath("/repo/tsconfig.json");
  expect(r.needsTest).toBe(false);
});

test("tddGateForPath: Markdown file is exempt", () => {
  const r = tddGateForPath("/repo/README.md");
  expect(r.needsTest).toBe(false);
});

test("tddGateForPath: production .py file requires test", () => {
  const r = tddGateForPath("/repo/src/order_service.py");
  expect(r.needsTest).toBe(true);
});

test("tddGate: skips non-edit/write tools", async () => {
  const input = { tool: "bash", args: { command: "echo hello" } };
  await expect(tddGate(input as any, {} as any)).resolves.toBeUndefined();
});

test("tddGate: skips when file_path empty", async () => {
  const input = { tool: "edit", args: {} };
  await expect(tddGate(input as any, {} as any)).resolves.toBeUndefined();
});
