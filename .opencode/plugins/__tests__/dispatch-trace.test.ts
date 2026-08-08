// dispatch-trace.test.ts — SE-313 S7c (OpenCode port)
//
// TDD for guards/dispatch-trace.ts.
// PreToolUse `task` guard: resolves the subagent model (tier→model via
// ~/.savia/preferences.yaml), verifies against config/model-registry.json,
// and appends dispatch.resolved | dispatch.failed to telemetry-events.jsonl.
// Non-blocking by default (shadow); SAVIA_DISPATCH_GATE=block fails the task.

import { test, expect, beforeAll, afterAll } from "bun:test";
import { dispatchTrace } from "../guards/dispatch-trace.ts";
import {
  mkdtempSync,
  rmSync,
  writeFileSync,
  existsSync,
  readFileSync,
  mkdirSync,
} from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

let testWs: string;
let telemetry: string;
let registry: string;
let prefs: string;
let prevWs: string | undefined;
let prevTelemetry: string | undefined;
let prevPrefs: string | undefined;

const SAMPLE_PREFS = [
  "version: 1",
  "frontend: opencode",
  "provider: deepseek",
  "model_heavy: deepseek/deepseek-v4-pro",
  "model_mid:   deepseek/deepseek-v4-pro",
  "model_fast:  deepseek/deepseek-v4-flash",
].join("\n") + "\n";

const SAMPLE_REGISTRY = {
  schema: "savia.model-registry/1.0",
  generated_at: "2026-08-08T00:00:00Z",
  models: ["deepseek/deepseek-v4-pro", "deepseek/deepseek-v4-flash"],
};

beforeAll(() => {
  testWs = mkdtempSync(join(tmpdir(), "se313-dispatch-"));
  mkdirSync(join(testWs, "output"), { recursive: true });
  mkdirSync(join(testWs, "config"), { recursive: true });
  telemetry = join(testWs, "output", "telemetry-events.jsonl");
  registry = join(testWs, "config", "model-registry.json");
  prefs = join(testWs, "preferences.yaml");
  writeFileSync(registry, JSON.stringify(SAMPLE_REGISTRY, null, 1));
  writeFileSync(prefs, SAMPLE_PREFS);

  prevWs = process.env.SAVIA_WORKSPACE_DIR;
  process.env.SAVIA_WORKSPACE_DIR = testWs;
  prevTelemetry = process.env.SAVIA_TELEMETRY_FILE;
  process.env.SAVIA_TELEMETRY_FILE = telemetry;
  prevPrefs = process.env.SAVIA_PREFS;
  process.env.SAVIA_PREFS = prefs;
});

afterAll(() => {
  if (prevWs === undefined) delete process.env.SAVIA_WORKSPACE_DIR;
  else process.env.SAVIA_WORKSPACE_DIR = prevWs;
  if (prevTelemetry === undefined) delete process.env.SAVIA_TELEMETRY_FILE;
  else process.env.SAVIA_TELEMETRY_FILE = prevTelemetry;
  if (prevPrefs === undefined) delete process.env.SAVIA_PREFS;
  else process.env.SAVIA_PREFS = prevPrefs;
  rmSync(testWs, { recursive: true, force: true });
});

function taskInput(subagent: string, model?: string) {
  return {
    args: {
      tool_name: "task",
      description: "test",
      subagent_type: subagent,
      prompt: "do something",
      ...(model ? { model } : {}),
    },
  } as any;
}

function readEvents(): any[] {
  if (!existsSync(telemetry)) return [];
  return readFileSync(telemetry, "utf-8")
    .split("\n")
    .filter((l) => l.trim())
    .map((l) => JSON.parse(l));
}

test("AC-7.3: dispatch.resolved para tier mid (dotnet-developer)", async () => {
  await dispatchTrace(taskInput("dotnet-developer", "mid"), {} as any);
  const events = readEvents();
  expect(events.length).toBe(1);
  expect(events[0].event).toBe("dispatch.resolved");
  expect(events[0].agent_name).toBe("dotnet-developer");
  expect(events[0].resolved_model).toBe("deepseek/deepseek-v4-pro");
  expect(events[0].schema).toBe("savia.event/1.0");
  expect(events[0].trace_id).toBeTruthy();
});

test("AC-7.3: dispatch.resolved hereda ID con prefijo (explore→mid default)", async () => {
  await dispatchTrace(taskInput("explore"), {} as any);
  const events = readEvents();
  expect(events.length).toBe(1);
  expect(events[0].event).toBe("dispatch.resolved");
  expect(events[0].agent_name).toBe("explore");
  expect(events[0].resolved_model).toContain("/");
});

test("AC-7.6/7.7: modelo no resolubible emite dispatch.failed sin bloquear", async () => {
  // Registry solo contiene deepseek/*; un modelo inexistente debe fallar.
  const before = readEvents().length;
  await dispatchTrace(taskInput("fake-agent", "claude-3-7-sonnet-20250219"), {} as any);
  const after = readEvents();
  expect(after.length).toBe(before + 1);
  const last = after[after.length - 1];
  expect(last.event).toBe("dispatch.failed");
  expect(last.agent_name).toBe("fake-agent");
  expect(last.error).toContain("Model not found");
});

test("AC-7.3: guard ignora tools que no son task (no escribe telemetría)", async () => {
  const before = readEvents().length;
  await dispatchTrace({ args: { tool_name: "edit" } } as any, {} as any);
  expect(readEvents().length).toBe(before);
});

test("AC-7.3: modelo con prefijo directo se usa tal cual si existe", async () => {
  await dispatchTrace(taskInput("direct", "deepseek/deepseek-v4-flash"), {} as any);
  const events = readEvents();
  const last = events[events.length - 1];
  expect(last.event).toBe("dispatch.resolved");
  expect(last.resolved_model).toBe("deepseek/deepseek-v4-flash");
});

test("SAVIA_DISPATCH_GATE=block: falla el dispatch con modelo irresoluble", async () => {
  const prev = process.env.SAVIA_DISPATCH_GATE;
  process.env.SAVIA_DISPATCH_GATE = "block";
  let threw = false;
  try {
    await dispatchTrace(taskInput("nope", "gpt-4o"), {} as any);
  } catch {
    threw = true;
  } finally {
    if (prev === undefined) delete process.env.SAVIA_DISPATCH_GATE;
    else process.env.SAVIA_DISPATCH_GATE = prev;
  }
  expect(threw).toBe(true);
});
