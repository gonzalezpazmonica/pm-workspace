#!/usr/bin/env bash
set -euo pipefail
# restore-checkpoint.sh — Git stash checkpoint for high-radius operations

action="${1:-list}"
shift 2>/dev/null || true

checkpoint_file="/tmp/savia-checkpoint.json"

case "$action" in
  save)
    desc="${1:-checkpoint}"
    scope="${2:-}"
    echo "WARNING: This checkpoint does NOT cover: untracked files, external state, running processes, network effects."
    echo ""
    if [[ -n "$scope" ]]; then
      git stash push -m "SAVIA-CHECKPOINT: $desc" -- "$scope"
    else
      git stash push -m "SAVIA-CHECKPOINT: $desc"
    fi
    echo '{"description":"'"$desc"'","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","stash_ref":"'"$(git stash list -1 --format='%gd')"'"}' > "$checkpoint_file"
    echo "Checkpoint saved: $desc"
    ;;
  restore)
    if ! git stash list | grep -q "SAVIA-CHECKPOINT:"; then
      echo "No checkpoints found."
      exit 2
    fi
    git stash pop --index
    if [[ "${1:-}" == "--verify" ]]; then
      if git diff --exit-code HEAD >/dev/null 2>&1; then
        echo "VERIFIED: working tree matches HEAD after restore."
      else
        echo "WARNING: working tree differs from HEAD after restore."
        exit 1
      fi
    fi
    rm -f "$checkpoint_file"
    ;;
  list)
    git stash list | grep "SAVIA-CHECKPOINT:" || echo "No checkpoints."
    ;;
  *)
    echo "Usage: restore-checkpoint.sh {save|restore|list} [args...]"
    exit 2
    ;;
esac
