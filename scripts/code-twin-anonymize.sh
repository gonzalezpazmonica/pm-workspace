#!/usr/bin/env bash
# code-twin-anonymize.sh — SPEC-190 Slice 8 (AC-14)
# Produces an anonymized copy of a code twin directory where:
#   (a) No module_id or content contains real project names from the exclusion list
#   (b) Absolute paths are replaced by {project_path}
#   (c) All output CTFs pass code-twin-lint.sh
#
# Usage:
#   code-twin-anonymize.sh <twin_dir> <out_dir> [--anon-list <file>]
#
# Options:
#   --anon-list  Path to project name list (one name per line, # = comment).
#                Default: .claude/rules/twin-anon-projects.local.txt
#
# Exit codes:
#   0 — success
#   2 — argument / IO error
set -uo pipefail

TWIN_DIR=""
OUT_DIR=""
ANON_LIST="${ANON_PROJECTS_FILE:-.claude/rules/twin-anon-projects.local.txt}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --anon-list)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --anon-list requires an argument" >&2
        exit 2
      fi
      ANON_LIST="$2"
      shift 2
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [[ -z "$TWIN_DIR" ]]; then
        TWIN_DIR="$1"
      elif [[ -z "$OUT_DIR" ]]; then
        OUT_DIR="$1"
      else
        echo "ERROR: unexpected argument: $1" >&2
        exit 2
      fi
      shift
      ;;
  esac
done

if [[ -z "$TWIN_DIR" || -z "$OUT_DIR" ]]; then
  echo "Usage: code-twin-anonymize.sh <twin_dir> <out_dir> [--anon-list <file>]" >&2
  exit 2
fi

if [[ ! -d "$TWIN_DIR" ]]; then
  echo "ERROR: twin directory not found: $TWIN_DIR" >&2
  exit 2
fi

python3 - "$TWIN_DIR" "$OUT_DIR" "$ANON_LIST" << 'PYEOF'
import sys, os, re, shutil

twin_dir  = sys.argv[1]
out_dir   = sys.argv[2]
anon_list = sys.argv[3]

# Load project name exclusion list
anon_names = []
if os.path.isfile(anon_list):
    with open(anon_list, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#"):
                anon_names.append(line)

ABS_PATH_RE = re.compile(r'(?<![{])(?:/(?:home|Users|var|opt|srv|workspace|root)/[^\s`"\'\n]*|/[a-zA-Z0-9_.\-]+(?:/[a-zA-Z0-9_.\-]+){2,})')

def anonymize(content: str) -> str:
    # Replace absolute paths with {project_path}
    content = ABS_PATH_RE.sub("{project_path}", content)
    # Replace project names (case-insensitive)
    for name in anon_names:
        if name:
            content = re.sub(re.escape(name), "{project}", content, flags=re.IGNORECASE)
    return content

os.makedirs(out_dir, exist_ok=True)

count = 0
for root, dirs, files in os.walk(twin_dir):
    rel_root = os.path.relpath(root, twin_dir)
    target_root = os.path.join(out_dir, rel_root) if rel_root != "." else out_dir
    os.makedirs(target_root, exist_ok=True)

    for fname in sorted(files):
        src = os.path.join(root, fname)
        dst = os.path.join(target_root, fname)
        if fname.endswith(".md"):
            with open(src, encoding="utf-8") as fh:
                original = fh.read()
            anonymized = anonymize(original)
            with open(dst, "w", encoding="utf-8") as fh:
                fh.write(anonymized)
            count += 1
        else:
            shutil.copy2(src, dst)

print(f"OK: anonymized {count} CTF(s) → {out_dir}")
PYEOF
