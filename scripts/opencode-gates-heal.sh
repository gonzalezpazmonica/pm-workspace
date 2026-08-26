#!/usr/bin/env bash
# opencode-gates-heal.sh — SE-077 process-leak self-heal (standalone)
#
# Kills hook processes left behind by hung/crashed opencode instances and
# removes their stale payload files in /tmp. Run it after an opencode session
# got "practically blocked" so savia can start clean again.
#
# What it kills:
#   * processes whose stdin (fd 0) is a `savia-gates-<ownerpid>-*.json` payload
#     whose owner pid is DEAD (safe, any mode)
#   * with --force: also savia-gates hook processes owned by LIVE pids that have
#     been hung for a while (use when the current opencode instances are stuck)
#
# Safety:
#   * NEVER kills the opencode processes themselves (their fd0 is a tty)
#   * NEVER touches processes whose payload owner is the current shell
#
# Usage:
#   bash scripts/opencode-gates-heal.sh            # dead owners only (safe)
#   bash scripts/opencode-gates-heal.sh --force    # also kill hung live-owner hooks
#   bash scripts/opencode-gates-heal.sh --dry-run  # print what would be done
#
# Reference: SE-077 (docs/propuestas/SE-077-opencode-replatform-v114.md)
# Reference: docs/rules/domain/opencode-savia-bridge.md

set -uo pipefail

FORCE=0
DRY=0
for _arg in "$@"; do
  [[ "$_arg" == "--force" ]] && FORCE=1
  [[ "$_arg" == "--dry-run" ]] && DRY=1
done

ME=$$
TMP_PAT='savia-gates-[0-9]\+-[0-9]\+-[a-z0-9]\+\.json'

kill_target() {
  local pid="$1"
  if [[ "$DRY" -eq 1 ]]; then
    echo "DRY: would kill $pid $(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)"
    return
  fi
  # kill the process group first (children like `ollama` die too), else the pid
  kill -9 -- "-$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
  echo "killed $pid"
}

killed=0
removed=0

# 1) stale payload files whose owner pid is dead
for f in /tmp/savia-gates-*.json; do
  [[ -e "$f" ]] || continue
  owner=$(basename "$f" | sed -n 's/^savia-gates-\([0-9]\+\).*/\1/p')
  [[ -n "$owner" ]] || continue
  [[ "$owner" == "$ME" ]] && continue
  if ! kill -0 "$owner" 2>/dev/null; then
    if [[ "$DRY" -eq 1 ]]; then
      echo "DRY: would remove $f (owner $owner dead)"
    else
      rm -f -- "$f" && echo "removed $f"
    fi
    removed=$((removed + 1))
  fi
done

# 2) pid-registry files (ptrace-independent): the plugin records each hook pid
#    as /tmp/savia-gates-<owner>-hook-<pid>.json, so a dead owner's leaked hook
#    can be killed with a same-uid signal (no /proc/<pid>/fd readlink needed).
REG_PAT='^savia-gates-\([0-9]\+\)-hook-\([0-9]\+\)\.json$'
for f in /tmp/savia-gates-*-hook-*.json; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f")
  owner=$(echo "$base" | sed -n "s/$REG_PAT/\1/p")
  hook=$(echo "$base" | sed -n "s/$REG_PAT/\2/p")
  [[ -n "$owner" && -n "$hook" ]] || continue
  [[ "$owner" == "$ME" ]] && continue
  if kill -0 "$owner" 2>/dev/null; then
    continue  # owner alive — registry is in use
  fi
  rm -f -- "$f" && echo "removed registry $f (owner $owner dead)"
  kill_target "$hook"
  killed=$((killed + 1))
done

# 3) hook processes whose stdin is a savia-gates payload
for p in /proc/[0-9]*; do
  pid="${p#/proc/}"
  [[ "$pid" == "$ME" ]] && continue
  fd0=$(readlink "$p/fd/0" 2>/dev/null) || continue
  echo "$fd0" | grep -q "$TMP_PAT" || continue
  owner=$(echo "$fd0" | sed -n 's/.*savia-gates-\([0-9]\+\).*/\1/p')
  [[ -n "$owner" ]] || continue
  [[ "$owner" == "$ME" ]] && continue

  if kill -0 "$owner" 2>/dev/null; then
    # owner alive: only kill with --force (hung live-owner hooks)
    [[ "$FORCE" -eq 1 ]] || continue
  fi
  kill_target "$pid"
  killed=$((killed + 1))
done

echo "done: killed=$killed removed=$removed"
