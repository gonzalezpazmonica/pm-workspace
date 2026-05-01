import { test, expect } from "bun:test";
import { extractCommand, extractFilePath, extractContent, extractToolName } from "./hook-input.ts";

test("extractCommand: returns command from Bash tool input", () => {
  expect(extractCommand({ tool: "bash", args: { command: "ls -la" } } as any)).toBe("ls -la");
});

test("extractCommand: returns empty string when no command field", () => {
  expect(extractCommand({ tool: "edit", args: {} } as any)).toBe("");
  expect(extractCommand({} as any)).toBe("");
});

test("extractFilePath: handles Edit/Write file_path fields", () => {
  expect(extractFilePath({ args: { file_path: "/tmp/x.ts" } } as any)).toBe("/tmp/x.ts");
  expect(extractFilePath({ args: { path: "/tmp/y.ts" } } as any)).toBe("/tmp/y.ts");
  expect(extractFilePath({ args: {} } as any)).toBe("");
});

test("extractContent: pulls content or new_string field", () => {
  expect(extractContent({ args: { content: "hello" } } as any)).toBe("hello");
  expect(extractContent({ args: { new_string: "world" } } as any)).toBe("world");
  expect(extractContent({ args: {} } as any)).toBe("");
});

test("extractToolName: normalizes case and aliases", () => {
  expect(extractToolName({ tool: "Bash" } as any)).toBe("bash");
  expect(extractToolName({ tool: "edit" } as any)).toBe("edit");
  expect(extractToolName({} as any)).toBe("");
});
