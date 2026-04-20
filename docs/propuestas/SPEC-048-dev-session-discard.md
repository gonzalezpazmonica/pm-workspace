---
id: SPEC-048
status: PROPOSED
---

# SPEC-048: Dev Session Discard

> Discard a dev-session cleanly: log reason, clean lock, archive state.

## Problem

Dev sessions can become stale, irrelevant, or based on outdated specs.
Currently there is no clean way to discard a session — locks linger,
state files accumulate, and there is no audit trail of why a session
was abandoned.

## Solution

A `dev-session-discard` script and command that:

1. Validates the session exists (lock or state file)
2. Logs the discard reason to an append-only discard log
3. Removes the lock file from `.claude/sessions/`
4. Archives the state file (rename with `.discarded` suffix)
5. Reports success with summary

## Phases

### Phase 1 (this spec)

- Script: `scripts/dev-session-discard.sh`
- Input: session ID (required), reason (optional, default: "manual discard")
- Validates session existence via lock file or state directory
- Appends discard entry to `output/dev-sessions/discard-log.jsonl`
- Removes `.claude/sessions/{id}.lock`
- Renames `output/dev-sessions/{id}/state.json` to `state.json.discarded`
- BATS tests: 8+ covering core scenarios

### Phase 2 (future)

- Slash command `/dev-session discard`
- Interactive mode: list active sessions, pick one
- Bulk discard of stale sessions (>24h)
- Integration with `/dev-session resume` to suggest discard

## Discard Log Format

```json
{
  "session_id": "20260319-AB102-feature",
  "reason": "spec changed, session obsolete",
  "timestamp": "2026-03-29T10:00:00Z",
  "had_lock": true,
  "had_state": true,
  "slices_completed": 2,
  "slices_total": 5
}
```

## Exit Codes

- 0: success
- 1: missing arguments or session not found
- 2: internal error during cleanup

## Constraints

- Script max 120 lines
- `set -uo pipefail` required
- Graceful if lock or state missing (log what was found)
- Never deletes state files — only renames (recoverable)
- Discard log is append-only, never truncated
