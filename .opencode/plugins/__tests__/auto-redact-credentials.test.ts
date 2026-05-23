// SPEC-142 — Auto-redaction guard
//
// Tests the mutation behavior of auto-redact-credentials.ts.
// Uses tmp dirs and tmp env vars so we don't depend on operator setup.

import { test, expect, beforeEach } from "bun:test";
import { mkdtempSync, writeFileSync, rmSync, existsSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { autoRedactSecrets } from "../guards/auto-redact-credentials.ts";

let workDir: string;
let patFile: string;
let sasFile: string;

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), "redact-test-"));
  patFile = join(workDir, "github-pat");
  sasFile = join(workDir, "azure-sas");
  writeFileSync(patFile, "test-pat\n");
  writeFileSync(sasFile, "test-sas\n");
  process.env.GITHUB_PAT_FILE = patFile;
  process.env.AZURE_SAS_FILE = sasFile;
  // Run in a tmp cwd so audit log lands in throw-away dir
  process.chdir(workDir);
});

test("AC-01: redacts classic ghp_* PAT to $(cat $GITHUB_PAT_FILE) literal", async () => {
  const cmd = "curl -H 'Authorization: token ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII' https://api.github.com";
  const input = { tool: "bash", args: { command: cmd } };
  await autoRedactSecrets(input as any, {});
  expect(input.args.command).toContain(`$(cat ${patFile})`);
  expect(input.args.command).not.toContain("ghp_AAAABBBB");
  expect(input.args.command).toContain("[shield] redacted github-pat-classic");
});

test("AC-01b: redacts github_pat_* fine-grained PAT", async () => {
  const longPat = "github_pat_" + "A".repeat(82);
  const input = { tool: "bash", args: { command: `gh api -H 'Authorization: ${longPat}' /user` } };
  await autoRedactSecrets(input as any, {});
  expect(input.args.command).toContain(`$(cat ${patFile})`);
  expect(input.args.command).toContain("github-pat-fine");
});

test("AC-02: leaves command intact when env var unset (block-credential-leak takes over)", async () => {
  delete process.env.GITHUB_PAT_FILE;
  const orig = "echo ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII";
  const input = { tool: "bash", args: { command: orig } };
  await autoRedactSecrets(input as any, {});
  // Unchanged — downstream guard will abort.
  expect(input.args.command).toBe(orig);
  // Audit logged the skip.
  const log = readFileSync(join(workDir, "output/secret-redactions.jsonl"), "utf8");
  expect(log).toContain("skipped_no_env");
});

test("AC-03: zero false positives on benign strings", async () => {
  const benign = [
    "ls -la /tmp/ghp_directory",                    // 'ghp_' in path, not PAT length
    "echo sk-not-a-real-key-just-short",            // sk- but too short
    "git log --grep='ghp_token in commit message'", // ghp_ but no 36 hex
    "cat README.md | grep 'see ghp_xxx for example'", // ghp_xxx not 36 chars
  ];
  for (const cmd of benign) {
    const input = { tool: "bash", args: { command: cmd } };
    await autoRedactSecrets(input as any, {});
    expect(input.args.command).toBe(cmd);  // untouched
  }
});

test("AC-04: writes audit JSONL record with timestamp, kind, env_var, env_file", async () => {
  const cmd = "echo ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII";
  const input = { tool: "bash", args: { command: cmd } };
  await autoRedactSecrets(input as any, {});
  const log = readFileSync(join(workDir, "output/secret-redactions.jsonl"), "utf8");
  const lines = log.trim().split("\n");
  expect(lines.length).toBeGreaterThanOrEqual(1);
  const rec = JSON.parse(lines[lines.length - 1]);
  expect(rec.kind).toBe("github-pat-classic");
  expect(rec.action).toBe("redacted");
  expect(rec.env_var).toBe("GITHUB_PAT_FILE");
  expect(rec.env_file).toBe(patFile);
  expect(rec.ts).toMatch(/^20\d{2}-\d{2}-\d{2}T/);
});

test("AC-05: non-bash tools are ignored (write/edit handled by other guards)", async () => {
  const cmd = "ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII";
  const input = { tool: "edit", args: { content: cmd, command: cmd } };
  await autoRedactSecrets(input as any, {});
  expect(input.args.command).toBe(cmd);  // tool != "bash" → no-op
});

test("AC-06: redacts Azure SAS token to $(cat $AZURE_SAS_FILE)", async () => {
  const sas = "sv=2024-08-04&ss=b&srt=sco&sp=rwdlac";
  const input = { tool: "bash", args: { command: `curl 'https://x.blob.core.windows.net/?${sas}'` } };
  await autoRedactSecrets(input as any, {});
  expect(input.args.command).toContain(`$(cat ${sasFile})`);
  expect(input.args.command).toContain("azure-sas");
});

test("AC-07: empty input is a no-op", async () => {
  await expect(autoRedactSecrets({} as any, {})).resolves.toBeUndefined();
});

test("AC-08: chained PATs in same command all get redacted", async () => {
  const cmd = "echo ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIII && echo ghp_ZZZZYYYYXXXXWWWWVVVVUUUUTTTTSSSSRRRR";
  const input = { tool: "bash", args: { command: cmd } };
  await autoRedactSecrets(input as any, {});
  expect(input.args.command).not.toContain("ghp_AAAABBBB");
  expect(input.args.command).not.toContain("ghp_ZZZZYYYY");
  const count = (input.args.command.match(new RegExp(patFile, "g")) || []).length;
  expect(count).toBe(2);
});
