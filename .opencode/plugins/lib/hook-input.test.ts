import { test, expect } from "bun:test";
import { extractCommand, extractFilePath, extractContent, extractToolName } from "./hook-input.ts";

test("extractCommand: returns command from Bash tool input", () => {
  expect(extractCommand({ tool: "bash", args: { command: "ls -la" } } as any)).toBe("ls -la");
});

test("extractCommand: returns empty string when no command field", () => {
  expect(extractCommand({ tool: "edit", args: {} } as any)).toBe("");
  expect(extractCommand({} as any)).toBe("");
});

test("extractFilePath: handles Edit/Write file_path fields (legacy snake_case)", () => {
  expect(extractFilePath({ args: { file_path: "/tmp/x.ts" } } as any)).toBe("/tmp/x.ts");
  expect(extractFilePath({ args: { path: "/tmp/y.ts" } } as any)).toBe("/tmp/y.ts");
  expect(extractFilePath({ args: {} } as any)).toBe("");
});

test("extractFilePath: handles OpenCode v1.14 filePath (camelCase) — regression for tool-healing false positives", () => {
  // Reproducer for the bug where read/write/edit were blocked by tool-healing
  // because the schema uses `filePath` (camelCase) but the extractor only
  // looked at `file_path` (snake_case).
  expect(extractFilePath({ tool: "read", args: { filePath: "/abs/path/x.md" } } as any)).toBe("/abs/path/x.md");
  expect(extractFilePath({ tool: "write", args: { filePath: "/abs/path/y.md", content: "x" } } as any)).toBe("/abs/path/y.md");
  expect(extractFilePath({ tool: "edit", args: { filePath: "/abs/path/z.ts", oldString: "a", newString: "b" } } as any)).toBe("/abs/path/z.ts");
});

test("extractFilePath: prefers filePath over file_path when both present", () => {
  // If a caller mixes both, camelCase wins (matches the live OpenCode schema).
  expect(extractFilePath({ args: { filePath: "/new.md", file_path: "/old.md" } } as any)).toBe("/new.md");
});

test("extractContent: pulls content or new_string field (legacy)", () => {
  expect(extractContent({ args: { content: "hello" } } as any)).toBe("hello");
  expect(extractContent({ args: { new_string: "world" } } as any)).toBe("world");
  expect(extractContent({ args: {} } as any)).toBe("");
});

test("extractContent: handles OpenCode v1.14 newString (camelCase)", () => {
  // Edit tool in OpenCode v1.14 uses `newString`, not `new_string`.
  expect(extractContent({ tool: "edit", args: { newString: "patched" } } as any)).toBe("patched");
});

test("extractToolName: normalizes case and aliases", () => {
  expect(extractToolName({ tool: "Bash" } as any)).toBe("bash");
  expect(extractToolName({ tool: "edit" } as any)).toBe("edit");
  expect(extractToolName({} as any)).toBe("");
});
