# Hashline Edit Protocol — Stale-File Protection for L3 Agents (SE-149)

> **Rule** — All L3 agents (dotnet-developer, typescript-developer, python-developer,
> frontend-developer, et al.) MUST verify file freshness before applying edits
> when the file was read in a previous tool call turn.
>
> Implements the oh-my-pi "hashline anchor" pattern: edits are anchored to a
> content-hash of the surrounding context, not to line numbers. If the file
> changed since the agent read it, the hash fails and the edit is rejected
> before touching disk.

## When to use hashline-guard

Use `hashline-guard.sh check` before editing when **all** of the following are true:

1. You read the file in a previous turn (not the same tool call batch).
2. The file is shared or could be touched by the human or another agent.
3. You are about to apply an `Edit` tool call or call `hashline-edit.sh`.

You may **skip** the guard when:
- You just created the file in the same turn (you know the exact content).
- The file is a scratch/temp file owned exclusively by you in this session.

## Protocol — Step by Step

### Step 1: Generate anchor when reading

Immediately after reading a file, generate an anchor for each region you plan
to modify:

```bash
bash scripts/hashline-guard.sh anchor <file_path> <line_number>
# Outputs: <sha256_hash>\t<3-line context>
```

Save the hash and anchor text in your working notes.

### Step 2: Check before editing

Before emitting the `Edit` tool call or calling `hashline-edit.sh`:

```bash
bash scripts/hashline-guard.sh check <file_path> "<anchor_text>" <anchor_hash>
# exit 0: safe to edit
# exit 1: file is stale — anchor text found but hash changed
# exit 2: anchor text not found — file too different
```

### Step 3: React to failures

| Exit code | Meaning | Action |
|---|---|---|
| `0` | File intact | Proceed with edit |
| `1` | File stale (content changed) | Re-read the file, regenerate the edit, re-anchor |
| `2` | Anchor not found (major change) | Re-read entire file, discard previous edit plan |

**Never force an edit after a guard failure.** The guard exists to prevent
corrupting a file that was modified after you read it.

### Step 4: Use hashline-edit.sh for atomic safe edits

Instead of raw `Edit` calls on shared files, use the wrapper:

```bash
bash scripts/hashline-edit.sh <file_path> "<old_string>" "<new_string>"
```

This script:
1. Verifies `old_string` exists.
2. Generates an anchor hash.
3. Re-checks the hash (detects racing edits).
4. Applies the replacement (first occurrence only).
5. Logs the operation to `/tmp/hashline-edits.log`.

## Agent Notes Format

When a guard failure occurs, record it in your agent notes:

```yaml
hashline_guard_failure:
  file: "path/to/file.cs"
  anchor_line: 42
  anchor_hash: "abc123..."
  exit_code: 1          # 1=stale, 2=not_found
  action: "re-read"     # re-read | abort | escalate
  turn: 7
```

## Integration with Edit Tool

OpenCode's `Edit` tool uses `oldString` matching. Hashline guard complements
this — the guard runs **before** the tool call. Workflow:

```
Read file (turn N)
  → hashline-guard anchor <file> <line>   ← save hash
  ... (other tool calls, human may edit file) ...
  → hashline-guard check <file> <text> <hash>
      exit 0 → emit Edit tool call
      exit 1/2 → re-read, re-plan
```

## Exit Code Summary

| Script | Exit 0 | Exit 1 | Exit 2 | Exit 3 |
|---|---|---|---|---|
| `hashline-guard.sh check` | Intact | Stale (hash mismatch) | Anchor not found | Internal error |
| `hashline-edit.sh` | Edit applied | Stale | old_string not found | Internal error |

## References

- `scripts/hashline-guard.sh` — anchor generation + check
- `scripts/hashline-edit.sh` — safe edit wrapper
- `tests/hashline-guard.bats` — BATS test suite
- SE-149 spike
- `docs/rules/domain/verification-before-done.md` (Rule #22)
- `docs/rules/domain/autonomous-safety.md`
