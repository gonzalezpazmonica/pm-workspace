# Savia Memory Architecture

> Canonical reference: unified view of all memory layers in pm-workspace.
> Ref: SPEC-110 (Memoria Externa Canónica), SPEC-089 (Memory Stack L0-L3).
> Last updated: 2026-05-01

## Layer map

```
┌──────────────────────────────────────────────────────┐
│  L4: Session context (in-flight, RAM-only)          │
│  .claude/context/ → current session working memory  │
├──────────────────────────────────────────────────────┤
│  L3: SQLite cache (~/.savia/memory-cache.db)        │
│  Fast keyword/topic lookup. Rebuildable from L1-L2. │
│  Built by: memory-cache-rebuild.sh                  │
├──────────────────────────────────────────────────────┤
│  L2: JSONL store (output/.memory-store.jsonl)       │
│  Structured entries with vector index.              │
│  Written by: memory-store.sh save                   │
│  Read via: memory-store.sh search/recall            │
├──────────────────────────────────────────────────────┤
│  L1: Session snapshots (~/.savia-memory/sessions/) │
│  Decisions, failures, discoveries per session.      │
│  Written by: stop-memory-extract.sh                 │
│              session-end-memory.sh                  │
│              memory-auto-capture.sh                 │
├──────────────────────────────────────────────────────┤
│  L0: Canonical index (~/.savia-memory/auto/)        │
│  Human-readable index of all persistent memory.     │
│  Updated by: memory-store.sh (on each save)         │
│  Rebuild via: memory-index-rebuild.sh               │
│  Loaded at: session start (via savia-identity)      │
└──────────────────────────────────────────────────────┘
```

## Directory structure

```
~/.savia-memory/
├── auto/                  L0: canonical memory index
│   └── MEMORY.md          Index file (≤200 lines, ≤25KB)
├── sessions/              L1: per-session snapshots
│   └── YYYY-MM-DD/
│       ├── session-hot.md     Hot decisions/failures
│       ├── MEMORY.md           Session index
│       ├── session_decisions*.md
│       └── session_failures*.md
├── projects/              Per-project memory (future)
├── agents/                Agent-specific memory
│   ├── public/
│   ├── private/
│   └── projects/
├── shield-maps/           Data sovereignty mappings
├── pm-radar/              PM radar state
└── jsonl-archive/         Archived JSONL exports
```

## Data flow

```
session-start:
  savia-identity skill → reads ~/.savia-memory/auto/MEMORY.md
  memory-stack-load.sh L0 → loads identity/prefs from active profile

during session:
  memory-auto-capture.sh → writes to output/.memory-store.jsonl
  memory-store.sh save → writes JSONL + updates auto/MEMORY.md index
  memory-store.sh recall/search → reads JSONL + vector index

session-end:
  session-end-memory.sh → writes ~/.savia-memory/sessions/YYYY-MM-DD/session-hot.md
  stop-memory-extract.sh → extracts decisions/failures → sessions/YYYY-MM-DD/
  pre-compact-backup.sh → saves to JSONL

cache rebuild (on demand):
  memory-cache-rebuild.sh → reads .savia-memory/ + legacy → writes SQLite
  memory-stack-load.sh L3 → reads SQLite cache for deep context
```

## Scripts

| Script | Reads from | Writes to | Purpose |
|--------|-----------|-----------|---------|
| `memory-store.sh` | JSONL | JSONL + auto/MEMORY.md | Save/search/recall |
| `memory-index-rebuild.sh` | JSONL | auto/MEMORY.md | Regenerate index |
| `memory-cache-rebuild.sh` | .savia-memory/ + legacy | ~/.savia/memory-cache.db | Build SQLite cache |
| `memory-stack-load.sh` | profiles + SQLite | stdout | Token-budgeted loading |
| `memory-vector.py` | JSONL | FAISS/HNSW index | Vector embeddings |
| `savia-memory-bootstrap.sh` | — | .savia-memory/ + markers | Initial setup |
| `memory-prime-hook.sh` | JSONL | context (stdin) | Auto-prime context |

## Hooks

| Hook | Trigger | Writes to |
|------|---------|-----------|
| `memory-auto-capture.sh` | PostToolUse | `output/.memory-store.jsonl` |
| `session-end-memory.sh` | SessionEnd | `~/.savia-memory/sessions/YYYY-MM-DD/` |
| `stop-memory-extract.sh` | Stop | `~/.savia-memory/sessions/YYYY-MM-DD/` |
| `pre-compact-backup.sh` | PreCompact | `output/.memory-store.jsonl` |
| `memory-prime-hook.sh` | PreToolUse | context injection (read-only) |
| `memory-verified-gate.sh` | PreToolUse | gate (no write) |

## Provider-agnostic compliance

All scripts use these resolution chains for workspace paths:
1. `$PM_WORKSPACE_ROOT` env var (preferred)
2. `$CLAUDE_PROJECT_DIR` or `$OPENCODE_PROJECT_DIR` (frontend native)
3. `git rev-parse --show-toplevel` (VCS fallback)
4. `$HOME/claude` (hard fallback)

No script hardcodes vendor-specific paths. Legacy `~/.claude/projects/*/memory/` is
still scanned as secondary source during migration period.

## Invariants

- `auto/MEMORY.md` always reflects current JSONL store (via save hook or rebuild)
- `recall` is an alias for `search` in `memory-store.sh`
- Session snapshots are written to `YYYY-MM-DD` directories under `sessions/`
- SQLite cache is ephemeral — always rebuildable from canonical sources
- Vector index auto-rebuilds in background on JSONL changes
