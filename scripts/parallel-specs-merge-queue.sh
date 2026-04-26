#!/usr/bin/env bash
# parallel-specs-merge-queue.sh — SE-074 Slice 2 — PR queue + cascade-rebase
#
# Coordinates the merge order of stacked PRs produced by
# parallel-specs-orchestrator.sh. Implements the cascade-rebase pattern
# documented in `feedback_changelog_cascade_rebase` so that, when a PR ahead
# in the queue lands, the next branch is rebased onto the new main with
# CHANGELOG.md / CHANGELOG.d/ conflicts auto-resolved (because the conflict
# is purely mechanical: each batch adds its own fragment file or version
# block) and EVERYTHING ELSE escalated to the user.
#
# Hard safety boundaries (autonomous-safety.md):
#   - NEVER pushes
#   - NEVER merges PRs
#   - NEVER force-pushes
#   - NEVER auto-resolves a non-CHANGELOG conflict
#   - Refuses to operate on a dirty working tree
#
# Subcommands:
#   add <branch>       Append a branch to the queue (no-op if already present)
#   list               Print the queue with each branch's status vs main
#   remove <branch>    Drop a branch from the queue
#   rebase <branch>    Rebase one branch onto current main with auto-resolve
#   rebase-next        Find the first non-merged branch in the queue and rebase it
#   status             Short summary line (counts of ready / blocked / merged)
#   clear              Empty the queue (requires --confirm)
#
# Env (all optional):
#   QUEUE_FILE         default .claude/parallel-merge-queue
#   MAIN_BRANCH        default "main"
#   MAX_REBASE_STEPS   safeguard against infinite loops, default 30
#
# Exit codes:
#   0 — success (or queue empty / no rebase needed)
#   1 — escalation: a real conflict was found, user action required
#   2 — usage error
#   3 — environment error (dirty tree, missing branch, missing main, etc.)
#
# Reference: SE-074 Slice 2 (docs/propuestas/SE-074-parallel-spec-execution.md)
# Reference: docs/rules/domain/parallel-spec-merge-queue.md (canonical doc)
# Reference: docs/rules/domain/parallel-spec-execution.md (Slice 1+1.5 context)
# Reference: docs/rules/domain/autonomous-safety.md

set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
QUEUE_FILE="${QUEUE_FILE:-${ROOT}/.claude/parallel-merge-queue}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
MAX_REBASE_STEPS="${MAX_REBASE_STEPS:-30}"

usage() {
  cat <<USG
Usage: parallel-specs-merge-queue.sh <subcommand> [args]

Subcommands:
  add <branch>       Append a branch to the queue
  list               Print queue with per-branch status
  remove <branch>    Drop a branch from the queue
  rebase <branch>    Rebase one branch onto ${MAIN_BRANCH}
  rebase-next        Rebase the first non-merged branch in the queue
  status             Short summary
  clear --confirm    Empty the queue

Env (key):
  QUEUE_FILE        default ${QUEUE_FILE}
  MAIN_BRANCH       default ${MAIN_BRANCH}
USG
}

# ── Helpers ───────────────────────────────────────────────────────────────────

die() { echo "ERROR: $*" >&2; exit "${2:-3}"; }

ensure_queue_file() {
  local dir; dir=$(dirname "${QUEUE_FILE}")
  mkdir -p "${dir}"
  [[ -f "${QUEUE_FILE}" ]] || : > "${QUEUE_FILE}"
}

read_queue() {
  ensure_queue_file
  # Strip blank lines and inline comments (one branch per line)
  grep -v -E '^\s*(#|$)' "${QUEUE_FILE}" 2>/dev/null || true
}

queue_contains() {
  local branch="$1"
  read_queue | grep -Fxq "${branch}"
}

require_clean_tree() {
  # `git status --porcelain` covers tracked diffs AND untracked files; the
  # weaker `git diff` check missed bare drop-ins like `scratch.txt`.
  local dirty; dirty=$(git -C "${ROOT}" status --porcelain 2>/dev/null)
  if [[ -n "${dirty}" ]]; then
    die "working tree dirty — commit or stash before invoking the queue manager" 3
  fi
}

require_branch_exists() {
  local branch="$1"
  git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${branch}" \
    || die "local branch not found: ${branch}" 3
}

require_main_exists() {
  git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${MAIN_BRANCH}" \
    || die "main branch not found locally: ${MAIN_BRANCH}" 3
}

# Returns 0 when the branch is fully reachable from main (i.e. effectively merged)
branch_is_merged() {
  local branch="$1"
  local merge_base head_main
  head_main=$(git -C "${ROOT}" rev-parse "${MAIN_BRANCH}")
  merge_base=$(git -C "${ROOT}" merge-base "${MAIN_BRANCH}" "${branch}" 2>/dev/null || echo "")
  local head_branch; head_branch=$(git -C "${ROOT}" rev-parse "${branch}")
  # Either branch HEAD is an ancestor of main, or branch HEAD == main HEAD
  git -C "${ROOT}" merge-base --is-ancestor "${head_branch}" "${head_main}" 2>/dev/null
}

# Counts how many commits a branch is ahead/behind main
branch_ahead_behind() {
  local branch="$1"
  git -C "${ROOT}" rev-list --left-right --count "${MAIN_BRANCH}...${branch}" 2>/dev/null \
    || echo "? ?"
}

# ── Subcommands ───────────────────────────────────────────────────────────────

cmd_add() {
  local branch="${1:-}"
  [[ -z "${branch}" ]] && { usage >&2; exit 2; }
  ensure_queue_file
  if queue_contains "${branch}"; then
    echo "already queued: ${branch}"
    return 0
  fi
  echo "${branch}" >> "${QUEUE_FILE}"
  echo "queued: ${branch}"
}

cmd_remove() {
  local branch="${1:-}"
  [[ -z "${branch}" ]] && { usage >&2; exit 2; }
  ensure_queue_file
  if ! queue_contains "${branch}"; then
    echo "not queued: ${branch}"
    return 0
  fi
  local tmp; tmp=$(mktemp)
  grep -Fxv "${branch}" "${QUEUE_FILE}" > "${tmp}" || true
  mv "${tmp}" "${QUEUE_FILE}"
  echo "removed: ${branch}"
}

cmd_list() {
  ensure_queue_file
  local count=0
  echo "queue (${QUEUE_FILE}):"
  while IFS= read -r branch; do
    count=$((count + 1))
    if ! git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${branch}"; then
      printf "  %2d  %-50s  [missing-branch]\n" "${count}" "${branch}"
      continue
    fi
    if branch_is_merged "${branch}"; then
      printf "  %2d  %-50s  [merged]\n" "${count}" "${branch}"
      continue
    fi
    local ab; ab=$(branch_ahead_behind "${branch}")
    local behind ahead
    behind=$(echo "${ab}" | awk '{print $1}')
    ahead=$(echo "${ab}" | awk '{print $2}')
    if [[ "${behind}" == "0" ]]; then
      printf "  %2d  %-50s  [ready ahead=%s]\n" "${count}" "${branch}" "${ahead}"
    else
      printf "  %2d  %-50s  [needs-rebase ahead=%s behind=%s]\n" "${count}" "${branch}" "${ahead}" "${behind}"
    fi
  done < <(read_queue)
  if [[ "${count}" -eq 0 ]]; then
    echo "  (empty)"
  fi
}

cmd_status() {
  ensure_queue_file
  local total=0 merged=0 ready=0 blocked=0 missing=0
  while IFS= read -r branch; do
    total=$((total + 1))
    if ! git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${branch}"; then
      missing=$((missing + 1)); continue
    fi
    if branch_is_merged "${branch}"; then
      merged=$((merged + 1)); continue
    fi
    local ab; ab=$(branch_ahead_behind "${branch}")
    local behind; behind=$(echo "${ab}" | awk '{print $1}')
    if [[ "${behind}" == "0" ]]; then
      ready=$((ready + 1))
    else
      blocked=$((blocked + 1))
    fi
  done < <(read_queue)
  echo "queue: total=${total} merged=${merged} ready=${ready} needs-rebase=${blocked} missing=${missing}"
}

cmd_clear() {
  if [[ "${1:-}" != "--confirm" ]]; then
    echo "Pass --confirm to actually clear the queue file." >&2
    exit 2
  fi
  ensure_queue_file
  : > "${QUEUE_FILE}"
  echo "queue cleared"
}

# Auto-resolve cascading CHANGELOG conflicts during a rebase. Returns 0 if the
# rebase finished cleanly, 1 if it had to escalate. The function aborts the
# rebase before returning 1 so the working tree is left in a sane state.
attempt_cascade_rebase() {
  local branch="$1"
  local rebase_dir
  local steps=0
  local non_changelog=""

  if git -C "${ROOT}" rebase "${MAIN_BRANCH}" >/dev/null 2>&1; then
    return 0
  fi

  while :; do
    rebase_dir=$(git -C "${ROOT}" rev-parse --git-path rebase-merge 2>/dev/null)
    [[ -d "${rebase_dir}" ]] || rebase_dir=$(git -C "${ROOT}" rev-parse --git-path rebase-apply 2>/dev/null)
    [[ -d "${rebase_dir}" ]] || break

    steps=$((steps + 1))
    if [[ "${steps}" -gt "${MAX_REBASE_STEPS}" ]]; then
      git -C "${ROOT}" rebase --abort >/dev/null 2>&1 || true
      echo "ABORT: exceeded MAX_REBASE_STEPS=${MAX_REBASE_STEPS} on ${branch}" >&2
      return 1
    fi

    local conflicted; conflicted=$(git -C "${ROOT}" diff --name-only --diff-filter=U)
    if [[ -z "${conflicted}" ]]; then
      # No conflicts; rebase paused for some other reason (empty commit, etc.)
      GIT_EDITOR=true git -C "${ROOT}" rebase --continue >/dev/null 2>&1 || {
        git -C "${ROOT}" rebase --abort >/dev/null 2>&1 || true
        echo "ABORT: --continue failed without conflicts on ${branch}" >&2
        return 1
      }
      continue
    fi

    non_changelog=$(echo "${conflicted}" | grep -v -E '^(CHANGELOG\.md|CHANGELOG\.d/)' || true)
    if [[ -n "${non_changelog}" ]]; then
      git -C "${ROOT}" rebase --abort >/dev/null 2>&1 || true
      echo "ESCALATE: non-CHANGELOG conflicts on ${branch}:" >&2
      echo "${non_changelog}" | sed 's/^/  /' >&2
      return 1
    fi

    # Auto-resolve: take the upstream (main + already-replayed) version verbatim.
    # Our fragment files in CHANGELOG.d/ are ADDED on this branch — they have no
    # base, so git keeps them in the working tree without conflict markers.
    # The conflict, if any, is on CHANGELOG.md (regenerated on both sides) and
    # we deliberately defer regeneration to the post-merge consolidate hook.
    local f
    while IFS= read -r f; do
      [[ -z "${f}" ]] && continue
      git -C "${ROOT}" checkout --ours -- "${f}" >/dev/null 2>&1 \
        || { git -C "${ROOT}" rebase --abort >/dev/null 2>&1 || true; echo "ABORT: checkout --ours failed for ${f}" >&2; return 1; }
      git -C "${ROOT}" add -- "${f}"
    done <<< "${conflicted}"

    GIT_EDITOR=true git -C "${ROOT}" rebase --continue >/dev/null 2>&1 || {
      # If --continue fails, the rebase usually moves to next conflict; loop again.
      :
    }
  done

  return 0
}

cmd_rebase() {
  local branch="${1:-}"
  [[ -z "${branch}" ]] && { usage >&2; exit 2; }
  require_clean_tree
  require_main_exists
  require_branch_exists "${branch}"
  if branch_is_merged "${branch}"; then
    echo "skip: ${branch} already merged"
    return 0
  fi

  local original_branch; original_branch=$(git -C "${ROOT}" symbolic-ref --short HEAD 2>/dev/null || echo "")
  git -C "${ROOT}" checkout "${branch}" >/dev/null 2>&1 \
    || die "could not checkout ${branch}" 3

  if attempt_cascade_rebase "${branch}"; then
    echo "rebased OK: ${branch}"
    if [[ -n "${original_branch}" && "${original_branch}" != "${branch}" ]]; then
      git -C "${ROOT}" checkout "${original_branch}" >/dev/null 2>&1 || true
    fi
    return 0
  else
    if [[ -n "${original_branch}" && "${original_branch}" != "${branch}" ]]; then
      git -C "${ROOT}" checkout "${original_branch}" >/dev/null 2>&1 || true
    fi
    return 1
  fi
}

cmd_rebase_next() {
  ensure_queue_file
  while IFS= read -r branch; do
    if ! git -C "${ROOT}" show-ref --verify --quiet "refs/heads/${branch}"; then
      continue
    fi
    if branch_is_merged "${branch}"; then
      continue
    fi
    local ab; ab=$(branch_ahead_behind "${branch}")
    local behind; behind=$(echo "${ab}" | awk '{print $1}')
    if [[ "${behind}" == "0" ]]; then
      echo "skip: ${branch} already up-to-date with ${MAIN_BRANCH}"
      return 0
    fi
    cmd_rebase "${branch}"
    return $?
  done < <(read_queue)
  echo "no rebase candidate in queue"
  return 0
}

# ── Dispatcher ────────────────────────────────────────────────────────────────

CMD="${1:-}"
shift || true

case "${CMD}" in
  add)          cmd_add "$@" ;;
  remove)       cmd_remove "$@" ;;
  list)         cmd_list "$@" ;;
  status)       cmd_status "$@" ;;
  clear)        cmd_clear "$@" ;;
  rebase)       cmd_rebase "$@" ;;
  rebase-next)  cmd_rebase_next "$@" ;;
  --help|-h|help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
  *)  echo "Unknown subcommand: ${CMD}" >&2; usage >&2; exit 2 ;;
esac
