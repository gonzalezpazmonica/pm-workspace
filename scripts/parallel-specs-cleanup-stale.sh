#!/usr/bin/env bash
# parallel-specs-cleanup-stale.sh — SE-074 Slice 3 — stale worktree cleanup
#
# Detects and (with explicit --confirm) removes parallel-specs worktrees that
# have been idle longer than SPEC_CLEANUP_THRESHOLD_HOURS. Default mode is
# list-only; the destructive path requires --confirm AND passes a battery of
# safety checks before touching anything.
#
# Hard safety boundaries (autonomous-safety.md):
#   - NEVER touches a worktree with uncommitted changes
#   - NEVER touches a worktree with commits not present in main / upstream
#   - NEVER touches a worktree with a `.do-not-clean` sentinel
#   - NEVER touches paths outside WORKTREES_DIR (path traversal guard)
#   - NEVER deletes a remote branch — local only
#   - REFUSES thresholds < 1h (foot-gun guard)
#   - List-mode is the default; prune requires --confirm
#
# Subcommands:
#   list                List stale candidates (read-only, default; cron-safe)
#   prune --confirm     Remove stale worktrees (idempotent on missing)
#   --threshold-hours N (default 24, env SPEC_CLEANUP_THRESHOLD_HOURS)
#   --dry-run           Alias of list
#
# Reference: SE-074 Slice 3 (docs/propuestas/SE-074-parallel-spec-execution.md)
# Reference: docs/rules/domain/parallel-spec-execution.md
# Reference: docs/rules/domain/autonomous-safety.md

set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
WORKTREES_DIR="${WORKTREES_DIR:-${ROOT}/.claude/worktrees}"
THRESHOLD_HOURS="${SPEC_CLEANUP_THRESHOLD_HOURS:-24}"
DB_SANDBOX="${ROOT}/scripts/parallel-specs-db-sandbox.sh"
MAIN_BRANCH="${MAIN_BRANCH:-main}"

CONFIRM=0
MODE="list"

usage() {
  cat <<USG
Usage: parallel-specs-cleanup-stale.sh <list|prune> [--confirm] [--threshold-hours N] [--dry-run]

Subcommands:
  list                List stale candidates (default, read-only, cron-safe)
  prune               Remove stale worktrees (idempotent); requires --confirm
  --threshold-hours N Override SPEC_CLEANUP_THRESHOLD_HOURS (default ${THRESHOLD_HOURS})
  --dry-run           Force list mode regardless of subcommand

Env:
  SPEC_CLEANUP_THRESHOLD_HOURS  default ${THRESHOLD_HOURS}
  WORKTREES_DIR                 default ${WORKTREES_DIR}
  MAIN_BRANCH                   default ${MAIN_BRANCH}
USG
}

die() { echo "ERROR: $*" >&2; exit "${2:-2}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    list)               MODE="list"; shift ;;
    prune)              MODE="prune"; shift ;;
    --confirm)          CONFIRM=1; shift ;;
    --dry-run)          MODE="list"; shift ;;
    --threshold-hours)  THRESHOLD_HOURS="${2:-}"; shift 2 ;;
    --help|-h|help)     usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# Min threshold guard (foot-gun)
if ! [[ "$THRESHOLD_HOURS" =~ ^[0-9]+$ ]] || [[ "$THRESHOLD_HOURS" -lt 1 ]]; then
  die "threshold-hours must be an integer ≥ 1 (got: ${THRESHOLD_HOURS})" 2
fi

[[ -d "${WORKTREES_DIR}" ]] || { echo "no worktrees directory: ${WORKTREES_DIR}"; exit 0; }

# Convert hours → seconds for find -mmin equivalent
threshold_minutes=$((THRESHOLD_HOURS * 60))

# ── Per-worktree analysis ─────────────────────────────────────────────────────

# Returns 0 if the worktree is safe to remove. Sets REASON for logging.
REASON=""
is_safe_to_remove() {
  local wt="$1"
  REASON=""

  # Path traversal guard: must be inside WORKTREES_DIR
  case "${wt}" in
    "${WORKTREES_DIR}"/*) ;;
    *) REASON="path outside WORKTREES_DIR"; return 1 ;;
  esac

  # Sentinel
  if [[ -f "${wt}/.do-not-clean" ]]; then
    REASON=".do-not-clean sentinel present"; return 1
  fi

  # Active worker pidfile
  if [[ -f "${wt}/.parallel-spec-running.pid" ]]; then
    local pid; pid=$(cat "${wt}/.parallel-spec-running.pid" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      REASON="active worker pid=${pid}"; return 1
    fi
  fi

  # Uncommitted changes
  local dirty
  dirty=$(git -C "${wt}" status --porcelain 2>/dev/null || true)
  if [[ -n "$dirty" ]]; then
    REASON="uncommitted changes"; return 1
  fi

  # Commits ahead of main (work that would be lost)
  local ahead
  ahead=$(git -C "${wt}" log "${MAIN_BRANCH}..HEAD" --oneline 2>/dev/null | head -1 || true)
  if [[ -n "$ahead" ]]; then
    # Worktree has unmerged commits — only OK if they exist on a remote branch
    local upstream
    upstream=$(git -C "${wt}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo "")
    if [[ -z "$upstream" ]]; then
      REASON="commits ahead of ${MAIN_BRANCH} with no upstream"; return 1
    fi
    local unpushed
    unpushed=$(git -C "${wt}" log "${upstream}..HEAD" --oneline 2>/dev/null | head -1 || true)
    if [[ -n "$unpushed" ]]; then
      REASON="commits not pushed to ${upstream}"; return 1
    fi
  fi

  # Age check
  local mtime
  mtime=$(stat -c %Y "${wt}" 2>/dev/null || stat -f %m "${wt}" 2>/dev/null || echo 0)
  local now; now=$(date +%s)
  local age_minutes=$(( (now - mtime) / 60 ))
  if [[ "$age_minutes" -lt "$threshold_minutes" ]]; then
    REASON="age=${age_minutes}m below threshold ${threshold_minutes}m"; return 1
  fi

  return 0
}

# Detect the branch a worktree points at (for safe deletion)
worktree_branch() {
  local wt="$1"
  git -C "${wt}" symbolic-ref --short HEAD 2>/dev/null || echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

if [[ "$MODE" == "prune" && "$CONFIRM" -ne 1 ]]; then
  echo "prune requested without --confirm — running list mode instead"
  MODE="list"
fi

stale_count=0
removed_count=0
skipped_count=0

for wt in "${WORKTREES_DIR}"/*/; do
  [[ -d "${wt%/}" ]] || continue
  wt="${wt%/}"
  if is_safe_to_remove "$wt"; then
    stale_count=$((stale_count + 1))
    if [[ "$MODE" == "prune" ]]; then
      branch=$(worktree_branch "$wt")
      # Run worktree remove (handles git metadata)
      if git -C "${ROOT}" worktree remove --force "$wt" >/dev/null 2>&1; then
        # Best-effort: drop the DB sandbox
        if [[ -x "${DB_SANDBOX}" ]]; then
          bash "${DB_SANDBOX}" destroy "$(basename "$wt")" >/dev/null 2>&1 || true
        fi
        # Branch deletion is gated on prefix + no upstream commits ahead
        if [[ -n "$branch" ]] && [[ "$branch" =~ ^(agent/|spec-) ]]; then
          git -C "${ROOT}" branch -D "$branch" >/dev/null 2>&1 || true
        fi
        echo "  removed: $wt"
        removed_count=$((removed_count + 1))
      else
        echo "  SKIP (git refused): $wt"
        skipped_count=$((skipped_count + 1))
      fi
    else
      echo "  stale: $wt"
    fi
  else
    [[ "$MODE" == "list" ]] && echo "  keep: $wt — ${REASON}"
  fi
done

echo ""
case "$MODE" in
  list)  echo "summary: ${stale_count} stale candidate(s); pass 'prune --confirm' to remove" ;;
  prune) echo "summary: ${removed_count} removed, ${skipped_count} skipped" ;;
esac
