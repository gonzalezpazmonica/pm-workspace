import { test, expect } from "bun:test";
import {
  extractCommand,
  extractFilePath,
  extractContent,
  extractToolName,
  extractPattern,
} from "./hook-input.ts";

// ─── extractCommand ────────────────────────────────────────────────────────
test("extractCommand: nested args.command", () => {
  expect(extractCommand({ tool: "bash", args: { command: "ls -la" } } as any)).toBe("ls -la");
});

test("extractCommand: top-level command (shape drift)", () => {
  expect(extractCommand({ tool: "bash", command: "pwd" } as any)).toBe("pwd");
});

test("extractCommand: nested input.cmd alias", () => {
  expect(extractCommand({ tool: "bash", input: { cmd: "echo hi" } } as any)).toBe("echo hi");
});

test("extractCommand: empty when missing", () => {
  expect(extractCommand({ tool: "edit", args: {} } as any)).toBe("");
  expect(extractCommand({} as any)).toBe("");
  expect(extractCommand(null as any)).toBe("");
});

// ─── extractFilePath ───────────────────────────────────────────────────────
test("extractFilePath: nested args.filePath (camelCase)", () => {
  expect(extractFilePath({ tool: "read", args: { filePath: "/abs/x.md" } } as any)).toBe("/abs/x.md");
});

test("extractFilePath: nested args.file_path (snake_case legacy)", () => {
  expect(extractFilePath({ args: { file_path: "/tmp/x.ts" } } as any)).toBe("/tmp/x.ts");
});

test("extractFilePath: top-level filePath (shape drift — KEY REGRESSION)", () => {
  // Some OpenCode versions/forks pass tool args at top level, not under `args`.
  // The healer must NOT block these as "empty file_path".
  expect(extractFilePath({ tool: "read", filePath: "/abs/y.md" } as any)).toBe("/abs/y.md");
  expect(extractFilePath({ tool: "write", filePath: "/abs/z.md", content: "x" } as any)).toBe("/abs/z.md");
});

test("extractFilePath: top-level path alias", () => {
  expect(extractFilePath({ tool: "read", path: "/abs/p.md" } as any)).toBe("/abs/p.md");
});

test("extractFilePath: nested tool_input.file_path (Claude Code legacy)", () => {
  expect(extractFilePath({ tool: "read", tool_input: { file_path: "/legacy.md" } } as any)).toBe("/legacy.md");
});

test("extractFilePath: empty/null returns empty string", () => {
  expect(extractFilePath({ args: {} } as any)).toBe("");
  expect(extractFilePath({} as any)).toBe("");
  expect(extractFilePath(null as any)).toBe("");
});

test("extractFilePath: prefers camelCase when both present", () => {
  expect(extractFilePath({ args: { filePath: "/new.md", file_path: "/old.md" } } as any)).toBe("/new.md");
});

// ─── extractPattern ────────────────────────────────────────────────────────
test("extractPattern: top-level pattern (KEY REGRESSION for grep)", () => {
  // grep tool in OpenCode passes `pattern` at top level, not under `args`.
  expect(extractPattern({ tool: "grep", pattern: "BLOCKED" } as any)).toBe("BLOCKED");
});

test("extractPattern: nested args.pattern", () => {
  expect(extractPattern({ tool: "glob", args: { pattern: "*.ts" } } as any)).toBe("*.ts");
});

test("extractPattern: empty when missing", () => {
  expect(extractPattern({ tool: "grep" } as any)).toBe("");
});

// ─── extractContent ────────────────────────────────────────────────────────
test("extractContent: nested args.content", () => {
  expect(extractContent({ args: { content: "hello" } } as any)).toBe("hello");
});

test("extractContent: top-level content (shape drift)", () => {
  expect(extractContent({ tool: "write", content: "hello" } as any)).toBe("hello");
});

test("extractContent: nested args.newString (camelCase)", () => {
  expect(extractContent({ tool: "edit", args: { newString: "patched" } } as any)).toBe("patched");
});

test("extractContent: legacy new_string", () => {
  expect(extractContent({ args: { new_string: "world" } } as any)).toBe("world");
});

test("extractContent: empty when missing", () => {
  expect(extractContent({ args: {} } as any)).toBe("");
});

// ─── extractToolName ───────────────────────────────────────────────────────
test("extractToolName: lowercases", () => {
  expect(extractToolName({ tool: "Bash" } as any)).toBe("bash");
  expect(extractToolName({ tool: "READ" } as any)).toBe("read");
});

test("extractToolName: handles `name` and `toolName` aliases", () => {
  expect(extractToolName({ name: "edit" } as any)).toBe("edit");
  expect(extractToolName({ toolName: "Write" } as any)).toBe("write");
});

test("extractToolName: empty when missing", () => {
  expect(extractToolName({} as any)).toBe("");
  expect(extractToolName(null as any)).toBe("");
});
