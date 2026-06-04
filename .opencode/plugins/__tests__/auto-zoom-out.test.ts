import { test, expect } from "bun:test";
import { shouldZoomOutPath, autoZoomOut } from "../guards/auto-zoom-out.ts";

// shouldZoomOutPath (static, no IO)

test("shouldZoomOutPath: Edit on ROADMAP.md triggers", () => {
  expect(shouldZoomOutPath("Edit", "/workspace/ROADMAP.md")).toBe(true);
});

test("shouldZoomOutPath: Write on ARCHITECTURE.md triggers", () => {
  expect(shouldZoomOutPath("Write", "/docs/ARCHITECTURE.md")).toBe(true);
});

test("shouldZoomOutPath: Edit on docs/architecture/ triggers", () => {
  expect(shouldZoomOutPath("Edit", "/workspace/docs/architecture/overview.md")).toBe(true);
});

test("shouldZoomOutPath: Edit on docs/propuestas/ triggers", () => {
  expect(shouldZoomOutPath("Edit", "/workspace/docs/propuestas/SE-091.md")).toBe(true);
});

test("shouldZoomOutPath: Edit on docs/specs/ triggers", () => {
  expect(shouldZoomOutPath("Edit", "/workspace/docs/specs/spec-001.md")).toBe(true);
});

test("shouldZoomOutPath: Edit on docs/rules/ triggers", () => {
  expect(shouldZoomOutPath("Edit", "/workspace/docs/rules/domain/critical-rules.md")).toBe(true);
});

test("shouldZoomOutPath: Edit on .arch.md triggers", () => {
  expect(shouldZoomOutPath("Edit", "/workspace/system.arch.md")).toBe(true);
});

test("shouldZoomOutPath: Read does not trigger", () => {
  expect(shouldZoomOutPath("Read", "/workspace/ROADMAP.md")).toBe(false);
});

test("shouldZoomOutPath: Bash does not trigger", () => {
  expect(shouldZoomOutPath("Bash", "/workspace/ROADMAP.md")).toBe(false);
});

test("shouldZoomOutPath: Edit on source code does not trigger", () => {
  expect(shouldZoomOutPath("Edit", "/src/orderService.ts")).toBe(false);
});

test("shouldZoomOutPath: Edit on CHANGELOG.md does not trigger", () => {
  expect(shouldZoomOutPath("Edit", "/workspace/CHANGELOG.md")).toBe(false);
});

// autoZoomOut integration — must not throw, must resolve

test("autoZoomOut: resolves on ROADMAP edit", async () => {
  await expect(
    autoZoomOut(
      { tool: "Edit", args: { filePath: "/workspace/ROADMAP.md" } },
      { args: { filePath: "/workspace/ROADMAP.md" } },
    ),
  ).resolves.toBeUndefined();
});

test("autoZoomOut: resolves on source code (no-op)", async () => {
  await expect(
    autoZoomOut(
      { tool: "Edit", args: { filePath: "/src/service.ts" } },
      { args: { filePath: "/src/service.ts" } },
    ),
  ).resolves.toBeUndefined();
});

test("autoZoomOut: resolves when tool is missing", async () => {
  await expect(autoZoomOut({}, {})).resolves.toBeUndefined();
});

test("autoZoomOut: resolves on Write to docs/rules/", async () => {
  await expect(
    autoZoomOut(
      { tool: "Write", args: { filePath: "/workspace/docs/rules/domain/new-rule.md" } },
      { args: { filePath: "/workspace/docs/rules/domain/new-rule.md" } },
    ),
  ).resolves.toBeUndefined();
});
