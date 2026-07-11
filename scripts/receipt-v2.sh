#!/usr/bin/env bash
# receipt-v2.sh — Content-bound review receipts (SE-260 S4)
# Replaces worktree-bound .pr-plan-ok with content-stable receipts.
# A receipt survives rebase/amend as long as the reviewed content is unchanged.
#
# Usage:
#   receipt-v2.sh sign    [--branch NAME] [--paths file1 file2...]
#   receipt-v2.sh verify  [--branch NAME]
#   receipt-v2.sh show    [--branch NAME]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RECEIPT_DIR=""
PROJECT=""

# ── Help ──
usage() {
  cat <<EOF
Usage: bash scripts/receipt-v2.sh <command> [options]

Commands:
  sign      Create a content-bound receipt for the current branch
  verify    Check if current content matches the receipt
  show      Display the receipt for the current branch

Options:
  --project DIR   Project root (default: git root detected from pwd)
  --branch NAME   Branch name (default: git branch --show-current)
  --paths FILES   Space-separated list of reviewed paths (sign only)

Description:
  A receipt v2 persists the patch-id of each reviewed file. This survives
  rebase/amend if the file CONTENT is unchanged. Unlike .pr-plan-ok (empty
  sentinel bound to worktree instant), receipt v2 compares content hashes.

  Normalization: git patch-id --stable with core.autocrlf=input and
  core.whitespace=trailing-space,space-before-tab for cross-env stability.
EOF
}

# ── Args ──
CMD=""
BRANCH=""
PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    sign|verify|show) CMD="$1"; shift ;;
    --project) PROJECT="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --paths) shift; while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do PATHS+=("$1"); shift; done ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$CMD" ]]; then
  echo "ERROR: command required (sign|verify|show)" >&2
  usage >&2
  exit 1
fi

# ── Resolve branch ──
if [[ -z "$BRANCH" ]]; then
  BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo "")
fi
if [[ -z "$BRANCH" ]]; then
  echo "ERROR: cannot determine branch" >&2
  exit 1
fi

# Sanitize branch name for filename
BRANCH_SAFE=$(echo "$BRANCH" | tr '/' '_')

# ── Resolve project root and receipt dir ──
if [[ -n "$PROJECT" ]]; then
  ROOT="$PROJECT"
elif git rev-parse --git-dir >/dev/null 2>&1; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
else
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
RECEIPT_DIR="$ROOT/output/receipts"
RECEIPT_FILE="$RECEIPT_DIR/${BRANCH_SAFE}.receipt.json"

# ── Git normalization config (for cross-env line-ending stability) ──
# Content hashing normalizes \r\n → \n before computing hash-object

# ── Compute content-id for a file ──
# Uses git hash-object of the file content (stable, cross-env after normalization).
# This survives rebase/amend as long as the file content is byte-identical.
content_id_for_file() {
  local f="$1"
  if [[ ! -f "$ROOT/$f" ]]; then
    echo "0000000000000000000000000000000000000000"
    return
  fi
  # Normalize line endings for cross-env stability, then hash
  local cid
  cid=$(sed 's/\r$//' "$ROOT/$f" | git hash-object --stdin 2>/dev/null)
  if [[ -z "$cid" ]]; then
    cid="0000000000000000000000000000000000000000"
  fi
  echo "$cid"
}

# ── Derive reviewed paths from git ──
derive_paths() {
  local base head_sha
  head_sha=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "")
  base=$(git -C "$ROOT" merge-base HEAD origin/main 2>/dev/null || \
         git -C "$ROOT" merge-base HEAD main 2>/dev/null || \
         git -C "$ROOT" rev-list --max-parents=0 HEAD 2>/dev/null || \
         echo "")
  # If base == HEAD (same branch, no divergence), use root commit
  if [[ "$base" == "$head_sha" ]]; then
    base=$(git -C "$ROOT" rev-list --max-parents=0 HEAD 2>/dev/null || echo "")
  fi
  local result
  if [[ -n "$base" && "$base" != "$head_sha" ]]; then
    result=$(git -C "$ROOT" diff --name-only "$base" 2>/dev/null | grep -v -E '(CHANGELOG|\.scm/|\.receipt\.json)' || true)
  fi
  if [[ -z "$result" ]]; then
    # Fallback: list all tracked files
    result=$(git -C "$ROOT" ls-files 2>/dev/null | grep -v -E '(CHANGELOG|\.scm/|\.receipt\.json)' || true)
  fi
  echo "$result"
}

# ══════════════════════════════════════════════════════════════════
# SIGN
# ══════════════════════════════════════════════════════════════════
cmd_sign() {
  mkdir -p "$RECEIPT_DIR"

  # Derive paths if not provided
  if [[ ${#PATHS[@]} -eq 0 ]]; then
    mapfile -t PATHS < <(derive_paths)
  fi

  if [[ ${#PATHS[@]} -eq 0 ]]; then
    echo "WARN: no paths to sign (empty diff?)" >&2
  fi

  local ts
  ts=$(date -Iseconds)
  local pid_entry=""
  local first=true
  local all_pids=""

  for f in "${PATHS[@]}"; do
    [[ -z "$f" ]] && continue
    [[ ! -f "$ROOT/$f" ]] && continue
    local pid
    pid=$(content_id_for_file "$f")
    $first || pid_entry+=","
    first=false
    pid_entry+="\"$f\": \"$pid\""
    all_pids+="$pid "
  done

  # Compute tree hash of all patch-ids aggregated
  local tree_hash
  tree_hash=$(echo "$all_pids" | sha256sum | awk '{print $1}')

  local commit_sha
  commit_sha=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")

  cat > "$RECEIPT_FILE" <<JSON
{
  "version": 2,
  "branch": "$BRANCH",
  "signed_at": "$ts",
  "commit_sha": "$commit_sha",
  "normalization": {
    "line_endings": "\\r\\n normalized to \\n before hashing",
    "hash_method": "git hash-object --stdin",
    "stability": "content-addressable, survives rebase/amend"
  },
  "tree_hash": "$tree_hash",
  "paths": {
    $pid_entry
  }
}
JSON

  echo "Receipt signed: $RECEIPT_FILE"
  echo "  branch:     $BRANCH"
  echo "  commit:     $commit_sha"
  echo "  tree_hash:  $tree_hash"
  echo "  paths:      ${#PATHS[@]} files reviewed"
}

# ══════════════════════════════════════════════════════════════════
# VERIFY
# ══════════════════════════════════════════════════════════════════
cmd_verify() {
  if [[ ! -f "$RECEIPT_FILE" ]]; then
    echo "VERIFY: no receipt found for branch '$BRANCH' — full plan required"
    exit 0
  fi

  local tree_hash_signed paths_data
  tree_hash_signed=$(grep -oE '"tree_hash": "[a-f0-9]+"' "$RECEIPT_FILE" | grep -oE '[a-f0-9]{64}' || echo "")

  # Extract paths from JSON without python dependency
  paths_data=$(grep -oE '"[^"]+": "[a-f0-9]+"' "$RECEIPT_FILE" \
    | grep -v '"version"\|"branch"\|"signed_at"\|"commit_sha"\|"tree_hash"\|"normalization"\|"paths"' \
    | sed 's/"//g; s/: /|/g' || echo "")

  if [[ -z "$paths_data" && -z "$tree_hash_signed" ]]; then
    echo "VERIFY: invalid receipt format — full plan required"
    exit 0
  fi

  local mismatches=0
  local missing=0
  local new_paths=()
  local all_pids=""
  local total=0

  while IFS='|' read -r path pid_signed; do
    [[ -z "$path" ]] && continue
    total=$((total + 1))

    if [[ ! -f "$ROOT/$path" ]]; then
      missing=$((missing + 1))
      echo "WARN: path in receipt no longer exists: $path" >&2
      continue
    fi

    local pid_current
    pid_current=$(content_id_for_file "$path")
    all_pids+="$pid_current "

    if [[ "$pid_current" != "$pid_signed" ]]; then
      mismatches=$((mismatches + 1))
      echo "MISMATCH: $path (receipt=${pid_signed:0:12}.. current=${pid_current:0:12}..)" >&2
    fi
  done <<< "$paths_data"

  # Check for new paths not in receipt
  local current_paths
  mapfile -t current_paths < <(derive_paths)
  for cp in "${current_paths[@]}"; do
    [[ -z "$cp" ]] && continue
    if ! echo "$paths_data" | grep -qF "$cp"; then
      new_paths+=("$cp")
    fi
  done

  # Compute current tree hash
  local tree_hash_current
  tree_hash_current=$(echo "$all_pids" | sha256sum | awk '{print $1}')

  # ── Verdict ──
  if [[ "$mismatches" -eq 0 && "$missing" -eq 0 ]]; then
    echo "VERIFY: RECEIPT VALID — $total paths unchanged (tree=$tree_hash_current)"
    if [[ ${#new_paths[@]} -gt 0 ]]; then
      echo "WARN: ${#new_paths[@]} new path(s) outside receipt — structural gates still run"
      for np in "${new_paths[@]}"; do
        echo "  new: $np"
      done
    fi
    exit 0
  elif [[ "$mismatches" -gt 0 ]]; then
    echo "VERIFY: RECEIPT STALE — $mismatches path(s) changed — full plan required"
    exit 1
  elif [[ "$missing" -gt 0 ]]; then
    echo "VERIFY: RECEIPT STALE — $missing path(s) missing — full plan required"
    exit 1
  fi
}

# ══════════════════════════════════════════════════════════════════
# SHOW
# ══════════════════════════════════════════════════════════════════
cmd_show() {
  if [[ ! -f "$RECEIPT_FILE" ]]; then
    echo "No receipt found for branch '$BRANCH'"
    exit 0
  fi
  cat "$RECEIPT_FILE"
}

# ── Dispatch ──
case "$CMD" in
  sign)   cmd_sign ;;
  verify) cmd_verify ;;
  show)   cmd_show ;;
esac
