# Managed Agents Patterns — Brain/Hands/Session Architecture

> Inspired by Anthropic's Managed Agents engineering post (2026-04-14).
> Three patterns adapted for pm-workspace's sovereign, local-first model.

## Pattern 1: Credential Proxy (Vault + Proxy)

Agents NEVER read credential files directly. All credentialed operations
go through `scripts/credential-proxy.sh` which:

1. Reads credential from file in a subshell
2. Executes the operation (git push, API call)
3. Returns only sanitized output — credential never enters agent context
4. Logs every operation to append-only audit trail

Operations: `git-push`, `git-clone`, `api-call` (Azure DevOps, Graph).

### Why this matters

Rule #1 says "never hardcode PAT". The proxy eliminates the class of
vulnerability entirely — the agent cannot leak what it never sees.
Structural isolation > behavioral rules.

### Credential file locations

| Service | File | Env override |
|---------|------|-------------|
| GitHub / Azure DevOps | `$HOME/.azure/devops-pat` | `GITHUB_PAT_FILE` |
| Microsoft Graph | `$HOME/.azure/graph-secret` | `GRAPH_SECRET_FILE` |
| Miro | `$HOME/.azure/miro-token` | `MIRO_TOKEN_FILE` |

### Audit

Every proxy call logged to `~/.savia/credential-proxy-audit.jsonl`:
`{"ts","op","service","result","pid"}`. Append-only, never in git.

## Pattern 2: Durable Session Event Log

Context window is ephemeral — /compact destroys Tier C events.
The session event log is durable — events survive compaction.

`scripts/session-event-log.sh` provides:

- **emit**: append event (decision, correction, discovery, error)
- **query**: search events by type, date, or last N
- **recover**: reconstruct session context from event log post-crash

### Event types

| Type | When to emit | Recovery value |
|------|-------------|---------------|
| `decision` | User makes explicit choice | High — rebuild context |
| `correction` | User corrects agent behavior | High — avoid repeating |
| `discovery` | New fact learned | Medium — context enrichment |
| `error` | Operation fails | Medium — avoid retry loops |
| `milestone` | Task/slice completed | Low — progress tracking |
| `handoff` | Agent transition | Low — debugging |

### Storage

`~/.savia/session-events/{session-id}.jsonl` — one file per session.
Append-only JSONL. Never in git. Retained 30 days, then auto-pruned.

### v2: Monotonic seq + resume index (Multica-inspired)

Each emitted event includes a `seq` field per session for catch-up:

- `query --since-seq N` returns events with seq > N (resume after disconnect)
- `query --session <id>` scopes to a specific session file

Complementary script `scripts/session-resume-index.sh` maintains a
(agent_type, spec_id) → last_session_id mapping so agents don't scan
every log file to find their checkpoint. Commands: `record`, `lookup`,
`list`, `forget`. Storage: `~/.savia/session-resume-index.tsv`.

## Pattern 3: Stateless Brain + Lazy Provisioning

pm-workspace already follows this pattern:

- **Stateless brain**: Claude Code + CLAUDE.md. No persistent state in
  the harness — everything lives in `.md` files on disk.
- **Lazy provisioning**: Rule #19 (arranque seguro). MCP servers,
  integrations, and heavy context load on-demand, never at boot.
- **Durable session**: session-journal.md + pre-compact extraction +
  now session-event-log.sh for non-destructive recovery.

The Managed Agents architecture validates this design. The key insight
we adopt: treat the session log as a **queryable external object**,
not just a crash-recovery artifact.

## Integration

| Component | Uses |
|-----------|------|
| `block-credential-leak.sh` | Redirects to credential-proxy when PAT detected |
| `session-memory-protocol.md` | emit events before compact (Tier B → event log) |
| `/dev-session resume` | recover from session-event-log on crash |
| `agent-trace-log.sh` | emit milestone events for completed tool calls |

## Prohibido

```
NEVER  → Read credential files directly in agent context
NEVER  → Delete session event logs without 30-day retention
NEVER  → Trust agent output as credential-safe without sanitize_output()
ALWAYS → Use credential-proxy.sh for any operation requiring auth
ALWAYS → Emit decision/correction events before /compact
```
