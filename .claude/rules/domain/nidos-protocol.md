# Savia Nidos — Parallel Terminal Isolation Protocol

> Each nido is a named git worktree on a local path, isolated from cloud sync.
> One terminal = one nido. Changes stay isolated until merged.

## Why Nidos exist

Git worktrees inside OneDrive/Dropbox/iCloud cause sync conflicts that corrupt
the working tree. Nidos solves this by placing worktrees in `~/.savia/nidos/`
which is always on local disk, never cloud-synced.

## Naming convention

- Names: lowercase kebab-case, descriptive (`feat-auth`, `e2e-savia-web`, `spike-perf`)
- Branch default: `nido/<name>` (override with `--branch`)
- Max length: 50 characters

## Lifecycle

```
Create          Work in terminal       Merge & clean up
nidos create    cd ~/.savia/nidos/x    nidos remove x
```

1. **Create** before starting work: `bash scripts/nidos.sh create <name>`
2. **Open terminal** in the nido path: `cd ~/.savia/nidos/<name>`
3. **Work normally** — git add, commit, push from the nido
4. **Merge** via PR from the nido branch to main
5. **Remove** after merge: `bash scripts/nidos.sh remove <name>`

## Session detection

When Claude Code starts inside a nido path, `session-init.sh` detects it and:
- Shows `Nido: <name> | Rama: <branch>` in the session banner
- Sets `SAVIA_NIDO=<name>` environment variable

## Scope isolation

When `SAVIA_NIDO` is set, the terminal operates exclusively within that worktree.
Editing files outside the nido's worktree should trigger a scope warning.

## Path resolution (cross-platform)

| Platform | Nidos path |
|----------|-----------|
| Windows (Git Bash) | `$USERPROFILE/.savia/nidos/` |
| Linux / macOS | `$HOME/.savia/nidos/` |
| WSL | `$HOME/.savia/nidos/` |

The path is always on local disk, never inside OneDrive, Dropbox, or iCloud.

## Registry

Active nidos are tracked in `~/.savia/nidos/.registry` (plain text, `name=branch`).
This file is local and never committed to git.

## Commands

| Command | Action |
|---------|--------|
| `nidos.sh create <name>` | Create new worktree + branch |
| `nidos.sh list` | Show active nidos with branches |
| `nidos.sh enter <name>` | Print nido path (for `cd`) |
| `nidos.sh remove <name>` | Delete worktree + branch |
| `nidos.sh status` | Detect if current dir is a nido |

## Prohibited

```
NEVER  -> Create worktrees inside cloud-synced folders (OneDrive, Dropbox, iCloud)
NEVER  -> Work on two nidos from the same terminal (one terminal = one nido)
NEVER  -> Delete a nido with uncommitted changes without --force
ALWAYS -> Merge nido branch via PR before removing
ALWAYS -> Use descriptive names that reflect the task
```
