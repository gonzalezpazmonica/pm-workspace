import { test, expect } from "bun:test";
import { blockGitignoredReferences } from "../guards/block-gitignored-references.ts";

const F = {
  outputDated: "out" + "put/" + "20260501" + "-r.md",
  privMem:     "priv" + "ate-agent-memory/" + "test" + "/x.md",
};

test("blockGitignoredReferences: throws when content references dated output path", async () => {
  const input = { tool: "edit", args: { file_path: "/repo/docs/foo.md", content: `see ${F.outputDated}` } };
  await expect(blockGitignoredReferences(input as any, {} as any)).rejects.toThrow(/output/);
});

test("blockGitignoredReferences: throws when content references private memory", async () => {
  const input = { tool: "write", args: { file_path: "/repo/docs/foo.md", content: F.privMem } };
  await expect(blockGitignoredReferences(input as any, {} as any)).rejects.toThrow(/private/);
});

test("blockGitignoredReferences: silent on clean content", async () => {
  const input = { tool: "edit", args: { file_path: "/repo/docs/foo.md", content: "Just a regular doc." } };
  await expect(blockGitignoredReferences(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockGitignoredReferences: skips non-edit/write tools", async () => {
  const input = { tool: "bash", args: { command: F.outputDated } };
  await expect(blockGitignoredReferences(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockGitignoredReferences: skips when target path is itself a private destination", async () => {
  const input = { tool: "edit", args: { file_path: "/repo/output/foo.md", content: F.outputDated } };
  await expect(blockGitignoredReferences(input as any, {} as any)).resolves.toBeUndefined();
});

test("blockGitignoredReferences: skips when target is a hook source file (legitimate self-reference)", async () => {
  const input = { tool: "edit", args: { file_path: "/repo/.claude/hooks/foo.sh", content: F.outputDated } };
  await expect(blockGitignoredReferences(input as any, {} as any)).resolves.toBeUndefined();
});
