---
version_bump: patch
section: Fixed
---

### Fixed

- SE-077 process leak: `savia-gates` plugin now kills hung hook process trees on
  timeout and self-heals orphans of dead opencode instances.
  - `spawnHook` uses `Bun.spawn({ detached: true })` (own process group) instead
    of Bun `$` shell, so `process.kill(-pid, SIGKILL)` reaps the whole tree
    (including hook children like `ollama` classify).
  - `runHookOnce` kills the process group on timeout (sync hooks) or a 60s hard
    cap (async/fire-and-forget hooks) — no more accumulated `bash`/`ollama`
    processes holding thousands of FDs inside opencode.
  - `sweepOrphanedHooks()` runs at plugin load: removes stale
    `/tmp/savia-gates-<deadpid>-*.json` payloads and kills hook processes owned
    by dead opencode pids via a per-hook **pid registry**
    (`/tmp/savia-gates-<owner>-hook-<hookpid>.json`). The registry makes the
    sweep ptrace-independent: killing a same-uid pid needs no signal more than
    a plain SIGKILL, whereas reading `/proc/<pid>/fd/0` of an unrelated process
    is blocked by Yama `ptrace_scope=1` (the `/proc` scan is kept as
    best-effort for descendant processes).
  - New `scripts/opencode-gates-heal.sh` for manual cleanup
    (`--force` to also reap hung live-owner hooks; `--dry-run` to preview).
    Uses the same pid registry, so it works from any shell (no ptrace).
  - Mitigates the "opencode blocked in savia" symptom (4 instances accumulated
    387 leaked `bash` + 24 `ollama` + ~5000 FDs in ~5h).
