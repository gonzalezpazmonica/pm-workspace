// auto-redact-credentials.ts — SPEC-142
//
// Auto-redaction of credentials in bash commands via mutation of
// `input.args.command`. Runs BEFORE block-credential-leak so the
// downstream guard sees the redacted form. If the redaction target
// env var is not configured, the redactor leaves the command intact
// and block-credential-leak still aborts — fail-closed.
//
// Behavior:
//   - For each known pattern, if it matches and the configured env
//     var points to a real file, substitute the literal secret with
//     `$(cat $ENV_VAR)`.
//   - Append a JSONL audit record to `output/secret-redactions.jsonl`.
//   - Append a trailing bash comment `# [shield] redacted <kind>`
//     so the model sees a transparent breadcrumb.
//
// Non-goals:
//   - Does NOT try to detect every credential the world has invented.
//     It mirrors the high-confidence subset of credential-patterns.ts
//     where the redaction-via-env-file pattern is well-known.
//
// Reference: SPEC-142, docs/rules/domain/secret-redaction-policy.md

import { appendFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { extractToolName, extractCommand, mutableArgs, type ToolInput, type ToolOutput } from "../lib/hook-input.ts";

type RedactRule = {
  kind: string;
  rx: RegExp;
  envVar: string;
};

// Patterns chosen for high precision (low false-positive rate) and a
// well-established env-var convention. We deliberately do NOT include
// regex-heavy fuzzy patterns (e.g. `pat-hardcoded`) — those stay in
// block-credential-leak as fail-closed bouncers.
const RULES: RedactRule[] = [
  { kind: "github-pat-classic",  rx: /ghp_[A-Za-z0-9]{36}/g,                 envVar: "GITHUB_PAT_FILE" },
  { kind: "github-pat-fine",     rx: /github_pat_[A-Za-z0-9_]{82,}/g,        envVar: "GITHUB_PAT_FILE" },
  { kind: "azure-sas",           rx: /sv=20[0-9]{2}-[0-9]{2}-[0-9]{2}&s[a-z]=[A-Za-z0-9%+/_-]+/gi, envVar: "AZURE_SAS_FILE" },
  { kind: "openai-key",          rx: /sk-[A-Za-z0-9]{48,}/g,                 envVar: "OPENAI_KEY_FILE" },
  { kind: "anthropic-key",       rx: /sk-ant-[A-Za-z0-9_-]{20,}/g,           envVar: "ANTHROPIC_KEY_FILE" },
];

const AUDIT_LOG = "output/secret-redactions.jsonl";

function writeAudit(record: Record<string, unknown>): void {
  try {
    const path = resolve(process.cwd(), AUDIT_LOG);
    const dir = dirname(path);
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
    appendFileSync(path, JSON.stringify(record) + "\n");
  } catch {
    // Audit is best-effort. Never fail the tool call because audit failed.
  }
}

export async function autoRedactSecrets(input: ToolInput, output: ToolOutput): Promise<void> {
  if (extractToolName(input) !== "bash") return;
  const original = extractCommand(input, output);
  if (!original) return;

  let mutated = original;
  const redactions: string[] = [];
  const ts = new Date().toISOString();

  for (const rule of RULES) {
    rule.rx.lastIndex = 0;
    if (!rule.rx.test(mutated)) continue;
    const envFile = process.env[rule.envVar];
    if (!envFile) {
      // Cannot redact safely — leave it. block-credential-leak will abort
      // in the next guard. Audit the missed redaction so operator can fix.
      writeAudit({
        ts, kind: rule.kind, action: "skipped_no_env",
        env_var: rule.envVar,
      });
      continue;
    }
    rule.rx.lastIndex = 0;
    mutated = mutated.replace(rule.rx, `$(cat ${envFile})`);
    redactions.push(rule.kind);
    writeAudit({
      ts, kind: rule.kind, action: "redacted",
      env_var: rule.envVar, env_file: envFile,
    });
  }

  if (redactions.length > 0 && mutated !== original) {
    const breadcrumb = ` # [shield] redacted ${redactions.join(",")}`;
    mutated = mutated + breadcrumb;
    // SPEC-155: mutate args object the runtime observes (output.args in v1.14+).
    const args = mutableArgs(input, output);
    if (args) args.command = mutated;
  }
}
