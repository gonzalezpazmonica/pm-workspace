# Secret Redaction Policy — SPEC-142

> **Rule** — `.opencode/plugins/guards/auto-redact-credentials.ts` mutates
> `args.command` for the `bash` tool to substitute literal credentials with
> `$(cat $ENV_FILE)` expansions BEFORE the command runs. If the env var
> is unset the command is left intact and `block-credential-leak` aborts
> in the next guard. Fail-closed by composition.

## Why mutate instead of block-only

Rule #1 ("NUNCA hardcodear PAT") was previously enforced by aborting the
tool call and letting the model retry. That penalises latency and the
re-prompt often produces a different command. The mutate-before-execute
plugin pattern (OpenCode v1.14+ `tool.execute.before`) corrects the
command in-place so the first invocation already runs against the
operator's vault.

The redactor does NOT replace the abort guard — it composes with it:

```
auto-redact-credentials    →  block-credential-leak
  (mutate if possible)     (abort if anything still looks like a secret)
```

If the redaction cannot substitute (env var missing, unknown shape),
the next guard catches the leak. The operator's vault config is the
single source of authority.

## Pattern table

| Kind | Regex (high-precision) | Env var | Example destination |
|---|---|---|---|
| `github-pat-classic`  | `ghp_[A-Za-z0-9]{36}`                          | `GITHUB_PAT_FILE`     | `~/.azure/devops-pat`  |
| `github-pat-fine`     | `github_pat_[A-Za-z0-9_]{82,}`                 | `GITHUB_PAT_FILE`     | `~/.azure/devops-pat`  |
| `azure-sas`           | `sv=20\d{2}-\d{2}-\d{2}&s[a-z]=[A-Za-z0-9%+/_-]+` | `AZURE_SAS_FILE`   | `~/.azure/sas-token`   |
| `openai-key`          | `sk-[A-Za-z0-9]{48,}`                          | `OPENAI_KEY_FILE`     | `~/.openai/key`        |
| `anthropic-key`       | `sk-ant-[A-Za-z0-9_-]{20,}`                    | `ANTHROPIC_KEY_FILE`  | `~/.anthropic/key`     |

Patterns are deliberately narrow. Fuzzy patterns (`pat = "..."`, generic
`token=`) stay in `block-credential-leak` as abort-only — too many false
positives to safely mutate.

## Operator setup

```bash
# Per-shell (or in ~/.bashrc):
export GITHUB_PAT_FILE="$HOME/.azure/devops-pat"
export AZURE_SAS_FILE="$HOME/.azure/sas-token"
# Files must be 0600, single line, no trailing newline.
```

If a kind is detected but its `*_FILE` env var is unset, the redactor
appends a JSONL `skipped_no_env` audit record and lets the next guard
abort. Configure the env var to enable redaction.

## Audit trail

Every action lands in `output/secret-redactions.jsonl` (gitignored):

```json
{"ts":"2026-05-23T10:00:00Z","kind":"github-pat-classic","action":"redacted","env_var":"GITHUB_PAT_FILE","env_file":"/home/me/.azure/devops-pat"}
{"ts":"2026-05-23T10:00:01Z","kind":"openai-key","action":"skipped_no_env","env_var":"OPENAI_KEY_FILE"}
```

Audit is best-effort: a failed audit write never blocks the tool call.

## Ordering with other plugins

`auto-redact-credentials` runs at position 2 of `BEFORE_GUARDS` in
`.opencode/plugins/savia-foundation.ts`, between `validate-bash-global`
(cheap regex sanity) and `block-credential-leak` (the abort gate). If a
third-party plugin also mutates `args.command` it MUST run AFTER
`auto-redact-credentials` so it operates on the redacted form.

## Compatibility & legacy

- **OpenCode v1.14+**: native via this plugin.
- **Claude Code**: equivalent via `hookSpecificOutput.modifiedInput` in
  `.claude/hooks/pretooluse-secret-redaction.sh` — SPEC-142 Slice 3 (not
  shipped in initial implementation; tracked as follow-up).

## What this rule does NOT do

- Does not detect every credential ever invented.
- Does not redact `write`/`edit` content — that path is owned by
  `block-credential-leak` and `data-sovereignty-gate`.
- Does not validate the contents of the destination file (operator
  responsibility — file must hold the actual secret).

## References

- SPEC-142: `docs/propuestas/SPEC-142-pretooluse-input-modification.md`
- Implementation: `.opencode/plugins/guards/auto-redact-credentials.ts`
- Tests: `.opencode/plugins/__tests__/auto-redact-credentials.test.ts`
- Composition: `.opencode/plugins/savia-foundation.ts` (BEFORE_GUARDS)
