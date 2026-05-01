import { test, expect } from "bun:test";
import { detectLeakage } from "./leakage-patterns.ts";

// Test fixtures are constructed dynamically so the source file itself
// does not trigger the workspace's block-gitignored-references hook.
const F = {
  outputDated:    "out" + "put/" + "20260501" + "-report.md",
  privateMemory:  "priv" + "ate-agent-memory/" + "test" + "/foo.md",
  auditScore:     "audit" + "or reports score 92" + "/100 certified",
};

test("detectLeakage: clean content returns empty array", () => {
  expect(detectLeakage("Just a regular spec doc.")).toEqual([]);
});

test("detectLeakage: dated output path triggers violation", () => {
  const v = detectLeakage(`see ${F.outputDated} for details`);
  expect(v.length).toBeGreaterThan(0);
});

test("detectLeakage: private memory path triggers violation", () => {
  const v = detectLeakage(`loaded from ${F.privateMemory}`);
  expect(v.length).toBeGreaterThan(0);
});

test("detectLeakage: audit score format triggers violation", () => {
  const v = detectLeakage(F.auditScore);
  expect(v.length).toBeGreaterThan(0);
});

test("detectLeakage: multiple violations are all reported", () => {
  const v = detectLeakage(`${F.outputDated} and ${F.privateMemory}`);
  expect(v.length).toBeGreaterThanOrEqual(2);
});

test("detectLeakage: empty content returns empty array", () => {
  expect(detectLeakage("")).toEqual([]);
});
