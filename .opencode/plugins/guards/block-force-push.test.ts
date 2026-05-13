// block-force-push.test.ts — SPEC-OC-01 regex regression tests
//
// Verifies that BLOCK_RULES distinguish between dangerous force operations
// and the safe --force-with-lease variant. Uses placeholders <remote>/<branch>/<ref>
// instead of real repo data.

import { test, expect } from "bun:test";
import { blockForcePush } from "./block-force-push.ts";
function bashInput(cmd: string) {
  return { tool: "bash", input: { command: cmd } } as any;
}
async function assertBlocked(cmd: string, snippet: string) {
  let err: Error | null = null;
  try {
    await blockForcePush(bashInput(cmd), null);
  } catch (e) {
    err = e as Error;
  }
  expect(err).not.toBeNull();
  expect(err!.message).toContain("BLOCKED");
  if (snippet) expect(err!.message).toContain(snippet);
}
async function assertAllowed(cmd: string) {
  let err: Error | null = null;
  try {
    await blockForcePush(bashInput(cmd), null);
  } catch (e) {
    err = e as Error;
  }
  expect(err).toBeNull();
}
test("blocks bare --force flag on push", async () => {
  await assertBlocked("git push --force <remote> <branch>", "force");
});
test("blocks short -f flag on push", async () => {
  await assertBlocked("git push -f <remote> <branch>", "force");
});
test("allows --force-with-lease on feature branch", async () => {
  await assertAllowed("git push --force-with-lease <remote> <branch>");
});
test("allows --force-with-lease=<ref> typed variant", async () => {
  await assertAllowed("git push --force-with-lease=<ref> <remote> <branch>");
});
test("blocks --force-with-lease targeting main", async () => {
  await assertBlocked("git push --force-with-lease <remote> main", "main");
});
test("blocks reset --hard", async () => {
  await assertBlocked("git reset --hard HEAD~1", "reset");
});
test("blocks checkout --force", async () => {
  await assertBlocked("git checkout --force <branch>", "checkout");
});
test("blocks plain push to main", async () => {
  await assertBlocked("git push <remote> main", "main");
});
test("blocks plain push to master", async () => {
  await assertBlocked("git push <remote> master", "master");
});
test("allows plain push to feature branch", async () => {
  await assertAllowed("git push <remote> <branch>");
});
test("allows --tags push", async () => {
  await assertAllowed("git push --tags <remote>");
});
test("blocks push to main from any remote (upstream)", async () => {
    await assertBlocked("git push upstream main", "main");
});
test("blocks push to main from any remote (fork)", async () => {
    await assertBlocked("git push fork main", "main");
});
test("blocks --force-with-lease to main on any remote", async () => {
    await assertBlocked("git push --force-with-lease upstream main", "main");
});
test("allows non-bash tool calls", async () => {
  let err: Error | null = null;
  try {
    await blockForcePush({ tool: "read", input: { command: "git push --force" } } as any, null);
  } catch (e) {
    err = e as Error;
  }
  expect(err).toBeNull();
});