# Context Optimization Discipline

> SPEC-CONTEXT-OPT-GATE — operator-facing discipline rules.

## Principle

Cache hit rate is a measurable proxy for context discipline. When edits to
`CLAUDE.md` files degrade the workspace's global cache hit rate by ≥5pp on a
14-day window, those edits are paying for themselves with measurably worse
prompt economics. The Context Optimization Gate makes that drift visible and
optionally enforceable.

## Discipline rules

1. **Baseline before scale.** Every monitored `CLAUDE.md` must be baselined
   (`/context-opt-baseline`) before it is allowed to grow. Pre-baseline edits
   are tracked as `baseline_pending` and do not count toward enforcement.

2. **Δ −5pp is the line.** A drop of 5 percentage points or more on d14 hit
   rate is the canonical alert threshold. It is calibrated to be larger than
   day-to-day noise (~±2pp) and small enough to catch sustained regressions.

3. **Dry-run by default.** The gate ships in dry-run until the workspace has
   ≥1000 turns over the last 14 days. Until then, no write is blocked; events
   are logged for retrospective analysis.

4. **Bypass is a smell.** Set `SAVIA_CONTEXT_OPT_BYPASS=1` only for known,
   bounded edits (e.g. an active spec-driven refactor of `CLAUDE.md`). Two or
   more bypasses on the same file within 24h is a re-baseline signal, not a
   licence to disable the gate.

5. **Snapshots are immutable.** `~/.savia/context-opt-snapshots/` is content-
   addressed (SHA256). Never edit a snapshot; recapture instead.

6. **Per-project files count.** `projects/<name>/CLAUDE.md` is monitored
   independently from workspace `CLAUDE.md`. Bloating a project file degrades
   workspace caching as much as bloating the root.

7. **Revert is cheap, regret is expensive.** If a `CLAUDE.md` enters `alert`
   status, the default move is `/context-opt-revert`. Defending the edit
   requires demonstrating a separate qualitative benefit; "I already wrote it"
   is not a benefit.

## Operator habits

- Run `/context-opt-status` before opening a PR that touches any `CLAUDE.md`.
- After approving a CLAUDE.md edit, run `/context-opt-baseline` to lock the
  new baseline.
- When in doubt, prefer adding context to `docs/rules/domain/*.md` (lazy
  loaded) over `CLAUDE.md` (loaded every turn).

## Interaction with other rules

- **Rule #11** (150-line cap for workspace markdown) still applies and is
  stricter than this rule on size. This rule adds the **economic** dimension:
  even a short edit can degrade caching if placed wrong.
- **`docs/rules/domain/prompt-caching.md`** documents the baseline hit rates
  used as reference points for the gate.

## References

- Spec: `docs/specs/SPEC-CONTEXT-OPT-GATE.spec.md`
- Monitored files: `docs/rules/domain/context-opt-monitored.md`
- Caching baselines: `docs/rules/domain/prompt-caching.md`
- Commands: `/context-opt-baseline`, `/context-opt-status`, `/context-opt-revert`
