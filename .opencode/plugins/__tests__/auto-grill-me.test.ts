import { test, expect } from "bun:test";
import { shouldGrillPath, autoGrillMe } from "../guards/auto-grill-me.ts";

// shouldGrillPath (static, no IO)

test("shouldGrillPath: Edit on .ts triggers", () => {
  expect(shouldGrillPath("Edit", "/repo/src/orderService.ts")).toBe(true);
});

test("shouldGrillPath: Write on .py triggers", () => {
  expect(shouldGrillPath("Write", "/scripts/extract.py")).toBe(true);
});

test("shouldGrillPath: Edit on .sh triggers", () => {
  expect(shouldGrillPath("Edit", "/scripts/deploy.sh")).toBe(true);
});

test("shouldGrillPath: Edit on .cs triggers", () => {
  expect(shouldGrillPath("Edit", "/src/Domain/Order.cs")).toBe(true);
});

test("shouldGrillPath: Edit on .go triggers", () => {
  expect(shouldGrillPath("Edit", "/cmd/main.go")).toBe(true);
});

test("shouldGrillPath: Edit on .rs triggers", () => {
  expect(shouldGrillPath("Edit", "/src/main.rs")).toBe(true);
});

test("shouldGrillPath: Edit on .java triggers", () => {
  expect(shouldGrillPath("Edit", "/src/Service.java")).toBe(true);
});

test("shouldGrillPath: Read does not trigger", () => {
  expect(shouldGrillPath("Read", "/src/orderService.ts")).toBe(false);
});

test("shouldGrillPath: Bash does not trigger", () => {
  expect(shouldGrillPath("Bash", "/src/orderService.ts")).toBe(false);
});

test("shouldGrillPath: Edit on .md does not trigger", () => {
  expect(shouldGrillPath("Edit", "/docs/architecture/overview.md")).toBe(false);
});

test("shouldGrillPath: Edit on .json does not trigger", () => {
  expect(shouldGrillPath("Edit", "/opencode.json")).toBe(false);
});

test("shouldGrillPath: Edit on .yaml does not trigger", () => {
  expect(shouldGrillPath("Edit", "/docker-compose.yaml")).toBe(false);
});

// autoGrillMe integration — must not throw, must resolve

test("autoGrillMe: resolves on code file Edit", async () => {
  await expect(
    autoGrillMe(
      { tool: "Edit", args: { filePath: "/src/service.ts" } },
      { args: { filePath: "/src/service.ts" } },
    ),
  ).resolves.toBeUndefined();
});

test("autoGrillMe: resolves on non-code file (no-op)", async () => {
  await expect(
    autoGrillMe(
      { tool: "Edit", args: { filePath: "/docs/architecture/overview.md" } },
      { args: { filePath: "/docs/architecture/overview.md" } },
    ),
  ).resolves.toBeUndefined();
});

test("autoGrillMe: resolves when tool is missing", async () => {
  await expect(autoGrillMe({}, {})).resolves.toBeUndefined();
});

test("autoGrillMe: resolves on Write to .py", async () => {
  await expect(
    autoGrillMe(
      { tool: "Write", args: { filePath: "/src/new-file.py" } },
      { args: { filePath: "/src/new-file.py" } },
    ),
  ).resolves.toBeUndefined();
});
