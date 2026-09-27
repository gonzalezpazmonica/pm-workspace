import { test, expect } from "bun:test";
import { buildLedgerPayload } from "../guards/edit-ledger-record.ts";

// SE-402: the OpenCode binding must emit the Claude Code payload shape so a
// single bash script records both frontends.

test("write with filePath produces a Claude-shaped Write payload", () => {
  const p = buildLedgerPayload({ tool: "write", sessionID: "ses1" } as any, { args: { filePath: "/r/a.txt" } } as any);
  expect(p).not.toBeNull();
  const d = JSON.parse(p as string);
  expect(d.tool_name).toBe("Write");
  expect(d.tool_input.file_path).toBe("/r/a.txt");
  expect(d.session_id).toBe("ses1");
});

test("edit maps to Edit", () => {
  const p = buildLedgerPayload({ tool: "edit" } as any, { args: { filePath: "/r/b.ts" } } as any);
  expect(JSON.parse(p as string).tool_name).toBe("Edit");
});

test("non-edit tools are ignored", () => {
  expect(buildLedgerPayload({ tool: "bash" } as any, { args: { command: "ls" } } as any)).toBeNull();
});

test("missing file path is ignored", () => {
  expect(buildLedgerPayload({ tool: "write" } as any, { args: {} } as any)).toBeNull();
});

test("a failed tool call (metadata.error) is not recorded", () => {
  expect(buildLedgerPayload({ tool: "write" } as any, { args: { filePath: "/r/a" }, metadata: { error: "EACCES" } } as any)).toBeNull();
});
