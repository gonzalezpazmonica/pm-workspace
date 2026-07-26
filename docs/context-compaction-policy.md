# Context Compaction Policy — SE-270 S7

> **Human-readable policy.** What survives, what drops, what's protected during
> context compaction. Executable version: `scripts/context-compaction-policy.sh`
> (sourcable).

---

## Window thresholds

| Threshold | Fraction | Action |
|---|---|---|
| WARN | 70% | Alert: window approaching compaction zone |
| COMPACT | 80% | Trigger compaction: drop ephemeral content |
| CRITICAL | 90% | Aggressive compaction: only survivors remain |

## Survivors — what survives compaction

These items persist across all compaction rounds:

| Category | Description |
|---|---|
| `current_task` | Active intent and immediate context of current task |
| `decisions_with_reasons` | Decisions made with their justification (not just outcome) |
| `error_context` | Recent errors and their causes to avoid repetition |
| `artifact_paths` | Paths of files created/modified this session |
| `style_rules` | Active style rules affecting current output |
| `last_action` | Last executed action and result for flow continuity |

## Droppable — what can fall

These categories can be dropped without data loss:

| Category | Description |
|---|---|
| `tool_dumps` | Full tool execution outputs (logs, raw output) |
| `discarded_exploration` | Paths explored but not taken |
| `stale_alternatives` | Evaluated and discarded alternatives |
| `search_noise` | Search results that led to no action |
| `verbose_confirmations` | Redundant confirmations of completed actions |
| `incremental_diffs` | Partial diffs already incorporated into final code |

## Protected — must live in system prompt

These items are NEVER in compactable context. They are loaded at session start
and persist immutably in the system prompt:

| Category | File | Reason |
|---|---|---|
| `constitution` | `CONSTITUCION.md` | Identity, duties, prohibitions, loyalty (ART-01 through ART-20) |
| `red_lines` | `autonomous-safety.md` | Immutable red lines: never send without approval, never hide uncertainty |
| `radical_honesty` | `radical-honesty.md` | Rule #24 prohibitions and obligations |
| `autonomous_safety` | `autonomous-safety.md` | Agent branch rules, PR Draft, human reviewer |
| `caveman_default` | `caveman-default.md` | Zero filler, token efficiency, base constraints |
| `critical_rules` | `CLAUDE.md` Rules 1-8 | PAT, WIQL, confirmation, project CLAUDE.md, SDD gates |

## How compaction works

1. When window reaches WARN (70%), log a metrics event but continue.
2. When window reaches COMPACT (80%), drop DROPPABLE categories in order:
   `tool_dumps` → `search_noise` → `verbose_confirmations` → `stale_alternatives`
   → `discarded_exploration` → `incremental_diffs`.
3. When window reaches CRITICAL (90%), keep only SURVIVORS. Compact survivors to
   summaries if still over budget.
4. PROTECTED items are never in the compaction scope — they are in the system
   prompt, which is immutable during the session.
5. Max 3 compaction rounds. If window is still over CRITICAL after 3 rounds,
   refuse further tool calls and request human intervention.

## Anti-collapse measures

Context collapse happens when an agent repeatedly rewrites its own context,
each iteration losing detail. Prevention:

- **Incremental updates.** When updating context files, modify only affected
  items, never rewrite the entire block.
- **Erosion detection.** `scripts/context-erosion-detect.sh` compares context
  snapshots over time. Volume loss without explicit item removal triggers a
  flag — potential collapse symptom.
- **Constitution anchoring.** During compaction, verify PROTECTED items are
  still present. If constitution or red lines are missing after compaction,
  abort and restore.

## JIT (Just-In-Time) loading

Prefer lightweight identifiers over preloaded content:

- **Path reference** (`scripts/foo.sh:42`) over inline content
- **Query reference** (`grep "pattern" file`) over file dump
- **Hash reference** (`sha256:abc123`) over content verification

`scripts/context-jit-lint.sh` scans agent/skill templates and flags
files with preloading patterns. Target: >=40% token reduction in
equivalent flows via JIT.

## Integration

```bash
# Source the policy in any context-aware script
source scripts/context-compaction-policy.sh

# Check if a category survives compaction
should_survive_compaction current_task

# Get window budget report
compaction_budget 120000 200000

# Commit gate: verify constitution present after compaction
grep -q "ART-01" <<<"$compacted_context" || abort "constitution lost in compaction"
```

---

> **SE-270 S7.** Erosion detection: `scripts/context-erosion-detect.sh`.
> JIT lint: `scripts/context-jit-lint.sh`.
