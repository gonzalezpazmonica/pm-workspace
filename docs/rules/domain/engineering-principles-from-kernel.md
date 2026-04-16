# Engineering Principles from the Linux Kernel

> Era 211. Distilled from mapping the Linux kernel tree at
> `/home/monica/research/linux-kernel/` into five .acm files plus a
> patterns digest. The kernel is a 30-year laboratory of what actually
> works under adversarial load. These are its five most transferable
> engineering principles, adapted for pm-workspace and Savia.

## 1. Pay for what you use — the compile-out-in-prod discipline

Debug and verification machinery must be **free** when disabled.
`CONFIG_PROVE_LOCKING`, `CONFIG_DEBUG_*`, KASAN, lockdep: on in CI,
gone from the shipping binary. The same discipline applies to Savia.

**How to apply:**
- Hooks that verify invariants (scope-guard, tdd-gate, plan-gate,
  pre-commit-review) run ONLY in the profile they belong to. The
  `minimal` hook profile exists for a reason — demos, quick edits,
  CI that already re-runs the full pipeline.
- Expensive BATS suites must be gated behind `standard`/`strict`
  profiles. Do not make every session pay for every check.
- Observability metrics (context-tracker, agent-trace, memory-prime)
  run `async: true` so they never block user interaction.
- Never leave a debug-only assertion firing in `minimal` profile code.

## 2. Make mechanisms visible — no hidden control flow

The kernel has no exceptions, no magic resource management, no
invisible globals on hot paths. Every error path is `if (err) goto
out_free;`. Every lock acquisition is explicit. You can grep for any
mechanism and read the full story in the source.

**How to apply:**
- Savia's agents declare their `permission_level`, `token_budget`,
  and `tools` in frontmatter. No hidden side effects.
- Scripts return specific exit codes (0/1/2/126) that mean specific
  things. `scripts/context-budget-check.sh` is the canonical example:
  0=no action, 1=compact recommended, 2=emergency, 3=circuit open.
- Hooks print a single line describing what they did and why, or
  nothing at all if they had nothing to do. Silent success is fine;
  silent failure is a bug.
- CHANGELOG entries describe the *why*, not the *what*. The git diff
  covers the what. The CHANGELOG covers the hidden reason.

## 3. Verify at runtime in debug, not at compile-time

Static analysis catches what can be caught with types. Lockdep catches
the rest by instrumenting every acquisition at runtime and building a
DAG in memory. When a new edge closes a cycle, the first thread to
hit it gets a stack trace. Catches bugs the first time they happen,
not the first time they deadlock in production.

**How to apply:**
- BATS suites are Savia's lockdep. They run on every commit that
  touches hooks, rules, or scripts. They catch regressions the first
  time a rule drifts from its contract.
- The `agent-dispatch-validate.sh` hook checks that Task invocations
  include the context subagents need. That's runtime verification of
  an invariant (agents receive sufficient context) that can't be
  expressed statically.
- `scripts/validate-commands.sh`, `pr-plan-gates.sh`, and
  `confidence-calibrate.sh` are all instances of the same idiom:
  verify the invariant every time, not once.
- When a rule is violated, fail loudly with file + line + the exact
  rule identifier. Never fail silently, never "warn and continue" on
  an invariant violation.

## 4. Interface tables > class hierarchies — polymorphism in plain text

The kernel gets 70+ filesystems to share one syscall layer with no
class system, no inheritance. Each fs implements `inode_operations`,
`file_operations`, `super_operations`, `address_space_operations`:
structs of function pointers. Generic code calls
`inode->i_op->lookup(...)`. Adding a new filesystem is a bounded task
of populating the ops table.

**How to apply:**
- Agents (`.claude/agents/*.md`) are Savia's ops tables. Each has
  `name`, `description`, `tools`, `token_budget`, `permission_level`.
  The dispatcher (Task tool) reads the table and invokes. No
  inheritance, no framework.
- Language packs (`docs/rules/languages/*`) follow the same idiom:
  each lang declares its conventions, rules file, agent, layer matrix.
  `rules/domain/language-packs.md` is the dispatch table.
- When adding a new capability (new language, new agent, new hook),
  populate the existing table instead of adding a new abstraction.
  If the table doesn't fit, fix the table, not the instance.

## 5. Safe extension via verified bytecode — the eBPF model

eBPF lets users load programs into the hottest kernel paths without
loading a module. The verifier proves termination (bounded loops),
memory safety (in-bounds accesses), and helper-call validity BEFORE
the program runs. Programs that fail verification are rejected with a
specific error. Programs that pass run at near-native speed.

**How to apply:**
- Hooks in `.claude/hooks/` are Savia's eBPF programs — they run in
  the user's hot path and they cannot be "mostly safe". The pre-commit
  verifier is `scripts/validate-commands.sh` + BATS + `shellcheck`.
  No hook merges without passing all three.
- Agents (`.claude/agents/*.md`) should declare their preconditions
  in the frontmatter so `agent-dispatch-validate.sh` can verify BEFORE
  invocation. Failing agents must be rejected with a specific reason.
- Skills that execute shell should sandbox unknown inputs with
  validated schemas, not trust the caller. The hook fixing 15 scripts
  without exec bit (Era 209) is an example of how easy it is to ship
  broken safety surface.

## What to NOT copy from the kernel

- **Per-CPU data structures** — Savia is not CPU-bound and not
  parallel. Don't design for cache-line locality you won't use.
- **Refcount-based ownership** — git handles object lifetime. Don't
  invent a parallel refcount scheme for `.md` files.
- **Hand-rolled intrusive data structures** — Savia's hot path is
  disk I/O and LLM calls, not data structure traversal. Use the
  language's libraries.
- **Real-time scheduling** — Savia is batch. Don't latency-engineer
  the pipeline.

## References

- `/home/monica/research/linux-kernel/agent-maps/INDEX.acm` — 22 subsystems
- `/home/monica/research/linux-kernel/agent-maps/mm.acm`, `kernel.acm`,
  `net.acm`, `fs.acm` — 4 detailed subsystem maps
- `/home/monica/research/linux-kernel/digest/PATTERNS.md` — 12 patterns
  with concrete file references
- `/home/monica/research/linux-kernel/digest/SUMMARY.md` — top-level
  digest + 10 files every newcomer should read first
- `/home/monica/research/linux-kernel/digest/GLOSSARY.md` — kernel
  vocabulary for future grep sessions
