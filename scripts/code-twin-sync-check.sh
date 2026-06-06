#!/usr/bin/env bash
# code-twin-sync-check.sh — SPEC-190 Slice 8 (AC-12)
# Scans all CTFs in a twin directory and reports those whose
# last_sync + stale_after_days < today.
#
# Usage:
#   code-twin-sync-check.sh <twin_dir> [-q]
#
# Options:
#   -q   Quiet: suppress stdout, only set exit code
#
# Exit codes:
#   0 — all CTFs are fresh
#   1 — one or more CTFs are stale (list printed to stdout unless -q)
#   2 — argument / IO error
set -uo pipefail

TWIN_DIR=""
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -q) QUIET=1; shift ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [[ -z "$TWIN_DIR" ]]; then
        TWIN_DIR="$1"
      else
        echo "ERROR: unexpected argument: $1" >&2
        exit 2
      fi
      shift
      ;;
  esac
done

if [[ -z "$TWIN_DIR" ]]; then
  echo "Usage: code-twin-sync-check.sh <twin_dir> [-q]" >&2
  exit 2
fi

if [[ ! -d "$TWIN_DIR" ]]; then
  echo "ERROR: twin directory not found: $TWIN_DIR" >&2
  exit 2
fi

TODAY=$(date +%Y-%m-%d)

# Use Python to parse dates robustly (avoids GNU/BSD date -d portability issues)
python3 - "$TWIN_DIR" "$TODAY" "$QUIET" << 'PYEOF'
import sys, os, re
from datetime import datetime, timedelta, date

twin_dir  = sys.argv[1]
today_str = sys.argv[2]
quiet     = sys.argv[3] == "1"

today = datetime.strptime(today_str, "%Y-%m-%d").date()

stale = []

for root, dirs, files in os.walk(twin_dir):
    for fname in sorted(files):
        if not fname.endswith(".md") or fname == "index.md":
            continue
        fpath = os.path.join(root, fname)
        with open(fpath, encoding="utf-8") as fh:
            content = fh.read()

        mid_m = re.search(r"^module_id:\s*(.+)$", content, re.MULTILINE)
        ls_m  = re.search(r"^last_sync:\s*[\"']?([0-9]{4}-[0-9]{2}-[0-9]{2})", content, re.MULTILINE)
        sad_m = re.search(r"^stale_after_days:\s*([0-9]+)", content, re.MULTILINE)

        if not (mid_m and ls_m and sad_m):
            continue

        module_id      = mid_m.group(1).strip().strip('"\'')
        last_sync      = datetime.strptime(ls_m.group(1), "%Y-%m-%d").date()
        stale_days     = int(sad_m.group(1))
        expiry         = last_sync + timedelta(days=stale_days)

        if today >= expiry:
            stale.append((module_id, str(last_sync), stale_days))

if not stale:
    if not quiet:
        print("OK: all CTFs are fresh")
    sys.exit(0)
else:
    if not quiet:
        print(f"STALE CTFs ({len(stale)}):")
        for mid, ls, sd in stale:
            print(f"  - {mid} (last_sync={ls} stale_after={sd}d)")
    sys.exit(1)
PYEOF
