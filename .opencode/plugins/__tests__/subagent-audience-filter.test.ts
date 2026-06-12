// subagent-audience-filter.test.ts — SE-221 Slice 3 (OpenCode port)
//
// TDD for guards/subagent-audience-filter.ts.
// Mirrors tests/test-context-capability.bats audience-filter assertions
// (AC-16 in SE-221 spec). PreToolUse `task` hook: logs which lazy imports
// each subagent has audience access to, deny-by-default for unknown agents.
//
// The hook is non-blocking: it only logs to output/audience-filter.jsonl,
// never mutates the task invocation. Tests assert log payload shape.

import { test, expect, beforeAll, afterAll } from "bun:test";
import { subagentAudienceFilter } from "../guards/subagent-audience-filter.ts";
import { mkdtempSync, rmSync, writeFileSync, existsSync, readFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

let testWs: string;
let auditLog: string;
let graphPath: string;
let prevWs: string | undefined;
let prevAudit: string | undefined;

const SAMPLE_GRAPH = {
  agents: {
    architect: [
      "/ws/docs/rules/domain/architecture.md",
      "/ws/docs/rules/domain/layering.md",
    ],
    "code-reviewer": [
      "/ws/docs/rules/domain/owasp.md",
      "/ws/docs/rules/domain/layering.md",
    ],
    "all-agents": [
      "/ws/docs/rules/domain/radical-honesty.md",
      "/ws/CLAUDE.md",
    ],
    "humans-only": [
      "/ws/docs/private/personnel.md",
    ],
  },
};

beforeAll(() => {
  testWs = mkdtempSync(join(tmpdir(), "se221-audience-"));
  mkdirSync(join(testWs, "output"), { recursive: true });
  graphPath = join(testWs, "output", "context-audience-graph.json");
  auditLog = join(testWs, "output", "audience-filter.jsonl");
  writeFileSync(graphPath, JSON.stringify(SAMPLE_GRAPH, null, 2));

  prevWs = process.env.SAVIA_WORKSPACE_DIR;
  process.env.SAVIA_WORKSPACE_DIR = testWs;
  prevAudit = process.env.AUDIENCE_FILTER_AUDIT_LOG;
  process.env.AUDIENCE_FILTER_AUDIT_LOG = auditLog;
});

afterAll(() => {
  if (prevWs === undefined) delete process.env.SAVIA_WORKSPACE_DIR;
  else process.env.SAVIA_WORKSPACE_DIR = prevWs;
  if (prevAudit === undefined) delete process.env.AUDIENCE_FILTER_AUDIT_LOG;
  else process.env.AUDIENCE_FILTER_AUDIT_LOG = prevAudit;
  rmSync(testWs, { recursive: true, force: true });
});

function makeTaskInput(subagent: string) {
  return { tool: "task", args: { subagent_type: subagent, description: "test", prompt: "x" } };
}

function readLastAudit(): any | null {
  if (!existsSync(auditLog)) return null;
  const content = readFileSync(auditLog, "utf-8").trim();
  if (!content) return null;
  const last = content.split("\n").filter(Boolean).pop()!;
  return JSON.parse(last);
}

// ── Shape & no-op cases ─────────────────────────────────────────────────────

test("non-task tool: passthrough, no audit entry", async () => {
  const before = existsSync(auditLog) ? readFileSync(auditLog, "utf-8").length : 0;
  const input = { tool: "read", args: { filePath: "/x" } };
  await subagentAudienceFilter(input as any, {} as any);
  const after = existsSync(auditLog) ? readFileSync(auditLog, "utf-8").length : 0;
  expect(after).toBe(before);
});

test("task without subagent_type: passthrough", async () => {
  const before = existsSync(auditLog) ? readFileSync(auditLog, "utf-8").length : 0;
  const input = { tool: "task", args: { description: "no subagent" } };
  await subagentAudienceFilter(input as any, {} as any);
  const after = existsSync(auditLog) ? readFileSync(auditLog, "utf-8").length : 0;
  expect(after).toBe(before);
});

test("before-guard contract: never throws on garbage input", async () => {
  await expect(subagentAudienceFilter(null as any, null as any)).resolves.toBeUndefined();
  await expect(subagentAudienceFilter({} as any, {} as any)).resolves.toBeUndefined();
});

// ── Filter logic ───────────────────────────────────────────────────────────

test("known agent (architect): allowed includes own + all-agents files", async () => {
  await subagentAudienceFilter(makeTaskInput("architect") as any, {} as any);
  const entry = readLastAudit();
  expect(entry).not.toBeNull();
  expect(entry.filter.subagent).toBe("architect");
  expect(entry.filter.allowed).toContain("/ws/docs/rules/domain/architecture.md");
  expect(entry.filter.allowed).toContain("/ws/docs/rules/domain/layering.md");
  expect(entry.filter.allowed).toContain("/ws/CLAUDE.md");
  expect(entry.filter.allowed).toContain("/ws/docs/rules/domain/radical-honesty.md");
  // OWASP belongs to code-reviewer only → architect must NOT have it
  expect(entry.filter.allowed).not.toContain("/ws/docs/rules/domain/owasp.md");
});

test("known agent: humans-only files are denied", async () => {
  await subagentAudienceFilter(makeTaskInput("architect") as any, {} as any);
  const entry = readLastAudit();
  expect(entry.filter.denied).toContain("/ws/docs/private/personnel.md");
});

test("unknown agent: only all-agents files are allowed (deny-by-default)", async () => {
  await subagentAudienceFilter(makeTaskInput("never-seen-agent") as any, {} as any);
  const entry = readLastAudit();
  expect(entry.filter.subagent).toBe("never-seen-agent");
  expect(entry.filter.allowed).toContain("/ws/CLAUDE.md");
  expect(entry.filter.allowed).toContain("/ws/docs/rules/domain/radical-honesty.md");
  expect(entry.filter.allowed).not.toContain("/ws/docs/rules/domain/architecture.md");
  expect(entry.filter.allowed).not.toContain("/ws/docs/rules/domain/owasp.md");
  expect(entry.filter.denied).toContain("/ws/docs/private/personnel.md");
});

test("count fields match allowed/denied lengths", async () => {
  await subagentAudienceFilter(makeTaskInput("code-reviewer") as any, {} as any);
  const entry = readLastAudit();
  expect(entry.filter.n_allowed).toBe(entry.filter.allowed.length);
  expect(entry.filter.n_denied).toBe(entry.filter.denied.length);
});

test("audit log entry has timestamp", async () => {
  await subagentAudienceFilter(makeTaskInput("architect") as any, {} as any);
  const entry = readLastAudit();
  expect(typeof entry.ts).toBe("string");
  expect(entry.ts).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
});

// ── Missing graph fallback ─────────────────────────────────────────────────

test("missing graph file: passthrough silently, no audit", async () => {
  const tmpEmpty = mkdtempSync(join(tmpdir(), "se221-empty-"));
  mkdirSync(join(tmpEmpty, "output"), { recursive: true });
  const tmpAudit = join(tmpEmpty, "output", "audience-filter.jsonl");

  const prevWsLocal = process.env.SAVIA_WORKSPACE_DIR;
  const prevAuditLocal = process.env.AUDIENCE_FILTER_AUDIT_LOG;
  process.env.SAVIA_WORKSPACE_DIR = tmpEmpty;
  process.env.AUDIENCE_FILTER_AUDIT_LOG = tmpAudit;
  try {
    await subagentAudienceFilter(makeTaskInput("architect") as any, {} as any);
    expect(existsSync(tmpAudit)).toBe(false);
  } finally {
    if (prevWsLocal === undefined) delete process.env.SAVIA_WORKSPACE_DIR;
    else process.env.SAVIA_WORKSPACE_DIR = prevWsLocal;
    if (prevAuditLocal === undefined) delete process.env.AUDIENCE_FILTER_AUDIT_LOG;
    else process.env.AUDIENCE_FILTER_AUDIT_LOG = prevAuditLocal;
    rmSync(tmpEmpty, { recursive: true, force: true });
  }
});

test("malformed graph file: passthrough silently, no throw", async () => {
  const tmpBad = mkdtempSync(join(tmpdir(), "se221-bad-"));
  mkdirSync(join(tmpBad, "output"), { recursive: true });
  const tmpGraph = join(tmpBad, "output", "context-audience-graph.json");
  writeFileSync(tmpGraph, "{ not valid json");

  const prevWsLocal = process.env.SAVIA_WORKSPACE_DIR;
  process.env.SAVIA_WORKSPACE_DIR = tmpBad;
  try {
    await expect(subagentAudienceFilter(makeTaskInput("architect") as any, {} as any)).resolves.toBeUndefined();
  } finally {
    if (prevWsLocal === undefined) delete process.env.SAVIA_WORKSPACE_DIR;
    else process.env.SAVIA_WORKSPACE_DIR = prevWsLocal;
    rmSync(tmpBad, { recursive: true, force: true });
  }
});

test("guard does not mutate input.args (passthrough)", async () => {
  const input = makeTaskInput("architect");
  const argsBefore = JSON.stringify(input.args);
  await subagentAudienceFilter(input as any, {} as any);
  expect(JSON.stringify(input.args)).toBe(argsBefore);
});
