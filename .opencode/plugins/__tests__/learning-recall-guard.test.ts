// learning-recall-guard.test.ts — SCL-003/SCL-008 (OpenCode port)
//
// TDD for guards/learning-recall-guard.ts.
// Uses a fake scripts/learning-recall.sh to keep the test deterministic
// (the real script depends on the SaviaLearning vault state).

import { test, expect, afterEach } from "bun:test";
import { learningRecallGuard } from "../guards/learning-recall-guard.ts";
import { mkdtempSync, rmSync, writeFileSync, mkdirSync, chmodSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

let tmpDirs: string[] = [];

function makeFakeRecall(json: string, exitCode = 0): { root: string; restore: () => void } {
  const root = mkdtempSync(join(tmpdir(), "scl-recall-"));
  tmpDirs.push(root);
  mkdirSync(join(root, "scripts"), { recursive: true });
  const script = join(root, "scripts", "learning-recall.sh");
  writeFileSync(
    script,
    `#!/usr/bin/env bash\nprintf '%s' '${json}'\nexit ${exitCode}\n`,
  );
  chmodSync(script, 0o755);
  const prev = process.env.SAVIA_WORKSPACE_DIR;
  process.env.SAVIA_WORKSPACE_DIR = root;
  return {
    root,
    restore: () => {
      if (prev === undefined) delete process.env.SAVIA_WORKSPACE_DIR;
      else process.env.SAVIA_WORKSPACE_DIR = prev;
    },
  };
}

function makeOutput(text: string) {
  return {
    message: { id: "msg-1", sessionID: "sess-1" },
    parts: [{ id: "p1", sessionID: "sess-1", messageID: "msg-1", type: "text", text }],
  };
}

afterEach(() => {
  for (const d of tmpDirs) {
    try { rmSync(d, { recursive: true, force: true }); } catch {}
  }
  tmpDirs = [];
  delete process.env.SAVIA_LEARNING_RECALL;
});

// ── No-op cases ────────────────────────────────────────────────────────────

test("recall off (SAVIA_LEARNING_RECALL=off): no mutation", async () => {
  process.env.SAVIA_LEARNING_RECALL = "off";
  const fake = makeFakeRecall('{"effective_hits":[{"criterion_id":"CRIT-001","principle":"x"}]}');
  const output = makeOutput("revisa las cupulas savia vaults");
  await learningRecallGuard({ messageID: "msg-1" }, output as any);
  fake.restore();
  expect(output.parts.length).toBe(1);
  expect(output.parts[0].synthetic).toBeUndefined();
});

test("missing output.parts: does not throw", async () => {
  await expect(learningRecallGuard({ messageID: "m" } as any, {} as any)).resolves.toBeUndefined();
});

test("short text (< 8 chars): no injection", async () => {
  const fake = makeFakeRecall('{"effective_hits":[{"criterion_id":"CRIT-001","principle":"x"}]}');
  const output = makeOutput("hola");
  await learningRecallGuard({ messageID: "msg-1" }, output as any);
  fake.restore();
  expect(output.parts.length).toBe(1);
});

test("skip phrases (ok, vale, listo): no injection", async () => {
  const fake = makeFakeRecall('{"effective_hits":[{"criterion_id":"CRIT-001","principle":"x"}]}');
  const output = makeOutput("vale");
  await learningRecallGuard({ messageID: "msg-1" }, output as any);
  fake.restore();
  expect(output.parts.length).toBe(1);
});

// ── Effective injection ────────────────────────────────────────────────────

test("effective hits: prepends synthetic text part", async () => {
  const fake = makeFakeRecall(
    '{"mode":"effective","effective_hits":[{"criterion_id":"CRIT-001","principle":"Soberania del dato por defecto"},{"criterion_id":"CRIT-002","principle":"Anti vendor lock-in"}]}',
  );
  const output = makeOutput("revisa las cupulas savia vaults");
  await learningRecallGuard({ messageID: "msg-1" }, output as any);
  fake.restore();
  expect(output.parts.length).toBe(2);
  const head = output.parts[0] as any;
  expect(head.synthetic).toBe(true);
  expect(head.type).toBe("text");
  expect(String(head.id)).toMatch(/^prt_/);
  expect(String(head.text)).toContain("## Criterios humanos aplicables");
  expect(String(head.text)).toContain("[CRIT-001] Soberania del dato por defecto");
  expect(String(head.text)).toContain("[CRIT-002]"); // both hits injected (2 ≤ cap 3)
});

test("effective hits: caps injection at 3, ordered", async () => {
  const fake = makeFakeRecall(
    '{"mode":"effective","effective_hits":[{"criterion_id":"CRIT-001","principle":"Soberania del dato por defecto"},{"criterion_id":"CRIT-002","principle":"Anti vendor lock-in"},{"criterion_id":"CRIT-003","principle":"Texto como verdad"},{"criterion_id":"CRIT-004","principle":"Reversible por git"}]}',
  );
  const output = makeOutput("revisa las cupulas savia vaults");
  await learningRecallGuard({ messageID: "msg-1" }, output as any);
  fake.restore();
  const head = output.parts[0] as any;
  expect(String(head.text)).toContain("[CRIT-001]");
  expect(String(head.text)).toContain("[CRIT-002]");
  expect(String(head.text)).toContain("[CRIT-003]");
  expect(String(head.text)).not.toContain("[CRIT-004]"); // caps at 3
});

test("empty effective_hits: no mutation", async () => {
  const fake = makeFakeRecall('{"mode":"effective","effective_hits":[]}');
  const output = makeOutput("revisa las cupulas savia vaults");
  await learningRecallGuard({ messageID: "msg-1" }, output as any);
  fake.restore();
  expect(output.parts.length).toBe(1);
});

test("script exit code 1: no throw, no mutation", async () => {
  const fake = makeFakeRecall("", 1);
  const output = makeOutput("revisa las cupulas savia vaults");
  await learningRecallGuard({ messageID: "msg-1" }, output as any);
  fake.restore();
  expect(output.parts.length).toBe(1);
});
