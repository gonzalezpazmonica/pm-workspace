// data-sovereignty-gate.test.ts — verifies guard logging does NOT corrupt OpenCode TUI overlay
//
// Regression: previously auditLog() and the AMBIGUOUS warning wrote to
// process.stderr, which OpenCode v1.14 concatenated into the TUI render
// without separators (visible as "Ollama AMBIGUOUS ..." overlay text).
//
// Fix: both must write to output/*.log files via fs.appendFile, NEVER stderr.
// Only legitimate stderr surface is the BLOCKED Error thrown to OpenCode
// (surfaced as tool failure, not overlay text).

import { test, expect, beforeEach, afterEach } from "bun:test";
import { auditLog, warnLog } from "./data-sovereignty-gate.ts";

let stderrWrites: string[] = [];
let originalStderrWrite: typeof process.stderr.write;

beforeEach(() => {
  stderrWrites = [];
  originalStderrWrite = process.stderr.write.bind(process.stderr);
  process.stderr.write = ((chunk: any) => {
    stderrWrites.push(typeof chunk === "string" ? chunk : chunk.toString());
    return true;
  }) as any;
});

afterEach(() => {
  process.stderr.write = originalStderrWrite;
});

test("auditLog: never writes to stderr (no TUI overlay corruption)", async () => {
  auditLog({ layer: "ollama", verdict: "WARN", reason: "test", file: "x.md" });
  // Allow async appendFile microtasks to flush
  await new Promise((r) => setTimeout(r, 20));
  expect(stderrWrites).toEqual([]);
});

test("warnLog: never writes to stderr (no TUI overlay corruption)", async () => {
  warnLog("test warning that previously polluted TUI overlay");
  await new Promise((r) => setTimeout(r, 20));
  expect(stderrWrites).toEqual([]);
});

test("auditLog: appends JSONL line to output/data-sovereignty-audit.jsonl", async () => {
  const { readFile, stat } = await import("node:fs/promises");
  let sizeBefore = 0;
  try {
    sizeBefore = (await stat("output/data-sovereignty-audit.jsonl")).size;
  } catch {
    // file may not exist yet
  }
  const marker = `marker-${Date.now()}-${Math.random()}`;
  auditLog({ layer: "test", verdict: "TEST", marker });
  await new Promise((r) => setTimeout(r, 20));
  const buf = await readFile("output/data-sovereignty-audit.jsonl", "utf-8");
  expect(buf.length).toBeGreaterThan(sizeBefore);
  expect(buf).toContain(marker);
});

test("warnLog: appends line to output/data-sovereignty-warnings.log", async () => {
  const { readFile, stat } = await import("node:fs/promises");
  let sizeBefore = 0;
  try {
    sizeBefore = (await stat("output/data-sovereignty-warnings.log")).size;
  } catch {
    // file may not exist yet
  }
  const marker = `marker-${Date.now()}-${Math.random()}`;
  warnLog(`test ${marker}`);
  await new Promise((r) => setTimeout(r, 20));
  const buf = await readFile("output/data-sovereignty-warnings.log", "utf-8");
  expect(buf.length).toBeGreaterThan(sizeBefore);
  expect(buf).toContain(marker);
});
