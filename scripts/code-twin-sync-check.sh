#!/usr/bin/env bash
# code-twin-sync-check.sh — SPEC-190 Slice 8 (AC-12)
# Scans all CTFs in a twin directory and reports those whose
# last_sync + stale_after_days < today.
#
# Usage:
#   code-twin-sync-check.sh <twin_dir> [-q] [--json]
#   code-twin-sync-check.sh --twin-dir <dir> [-q] [--json]
#
# Options:
#   --twin-dir <dir>   Alternative flag for twin directory path
#   -q, --quiet        Suppress stdout, only set exit code
#   --json             Output JSON: {total_ctfs, stale_count, fresh_count, stale_files:[...]}
#
# Exit codes:
#   0 — all CTFs are fresh (or no CTFs found)
#   1 — one or more CTFs are stale
#   2 — argument / IO error
set -uo pipefail

TWIN_DIR=""
QUIET=0
JSON_OUTPUT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -q|--quiet) QUIET=1; shift ;;
    --json) JSON_OUTPUT=1; shift ;;
    --twin-dir)
      shift
      [[ $# -eq 0 ]] && { echo "ERROR: --twin-dir requires a value" >&2; exit 2; }
      TWIN_DIR="$1"; shift
      ;;
    --twin-dir=*)
      TWIN_DIR="${1#*=}"; shift
      ;;
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
  echo "Usage: code-twin-sync-check.sh <twin_dir> [-q] [--json]" >&2
  exit 2
fi

if [[ ! -d "$TWIN_DIR" ]]; then
  echo "ERROR: twin directory not found: $TWIN_DIR" >&2
  exit 2
fi

TODAY=$(date +%Y-%m-%d)

# Use Python to parse dates robustly (avoids GNU/BSD date -d portability issues)
python3 - "$TWIN_DIR" "$TODAY" "$QUIET" "$JSON_OUTPUT" << 'PYEOF'
import sys, os, re, json
from datetime import datetime, timedelta, date

twin_dir    = sys.argv[1]
today_str   = sys.argv[2]
quiet       = sys.argv[3] == "1"
json_output = sys.argv[4] == "1"

today = datetime.strptime(today_str, "%Y-%m-%d").date()

all_ctfs = []
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

        module_id  = mid_m.group(1).strip().strip('"\'')
        last_sync  = datetime.strptime(ls_m.group(1), "%Y-%m-%d").date()
        stale_days = int(sad_m.group(1))
        expiry     = last_sync + timedelta(days=stale_days)

        all_ctfs.append(module_id)
        if today >= expiry:
            stale.append({
                "module_id": module_id,
                "last_sync": str(last_sync),
                "stale_after_days": stale_days,
                "file": os.path.relpath(fpath, twin_dir),
            })

total   = len(all_ctfs)
fresh   = total - len(stale)

if json_output:
    result = {
        "total_ctfs":  total,
        "stale_count": len(stale),
        "fresh_count": fresh,
        "stale_files": [s["file"] for s in stale],
    }
    print(json.dumps(result, indent=2))
    sys.exit(1 if stale else 0)

if not stale:
    if not quiet:
        print("OK: all CTFs are fresh")
    sys.exit(0)
else:
    if not quiet:
        print(f"STALE CTFs ({len(stale)}):")
        for s in stale:
            print(f"  - {s['module_id']} (last_sync={s['last_sync']} stale_after={s['stale_after_days']}d)")
    sys.exit(1)
PYEOF
