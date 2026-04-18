#!/usr/bin/env bash
# query-lib-index.sh — SE-031
# Regenerates .claude/queries/INDEX.md from current snippet files.
# Ref: docs/propuestas/SE-031-query-library-nl.md
#
# Usage: bash scripts/query-lib-index.sh [--check]

set -uo pipefail

CHECK_MODE=false
[[ "${1:-}" == "--check" ]] && CHECK_MODE=true

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}" || REPO_ROOT="."
INDEX="$REPO_ROOT/.claude/queries/INDEX.md"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

export REPO_ROOT
# NOTE: heredoc is quoted (<<'PY') to disable bash expansion — the python
# code contains backticks/$ that must NOT be command-substituted by bash.
# REPO_ROOT is read from env instead.
python3 <<'PY' > "$TMP"
import os, re, sys

REPO = os.environ.get("REPO_ROOT", ".")
Q_DIR = os.path.join(REPO, ".claude/queries")

entries = []
for root, dirs, files in os.walk(Q_DIR):
    for f in sorted(files):
        if f == "INDEX.md":
            continue
        if not f.endswith((".wiql", ".jql", ".yaml")):
            continue
        path = os.path.join(root, f)
        rel = os.path.relpath(path, Q_DIR)
        try:
            with open(path) as fd:
                content = fd.read()
        except Exception:
            continue
        m = re.search(r'^---\n(.*?)\n---', content, re.DOTALL | re.MULTILINE)
        fm = m.group(1) if m else ""
        def grab(k, block=fm):
            mm = re.search(r'^' + re.escape(k) + r':\s*(.+)$', block, re.MULTILINE)
            return mm.group(1).strip().strip('"') if mm else ""
        qid = grab("id") or f.rsplit(".", 1)[0]
        lang = grab("lang") or "unknown"
        desc = grab("description")
        tags = grab("tags").strip("[]")
        entries.append((qid, lang, tags, desc, rel))

print("# Query Library — INDEX")
print()
print("Auto-generated. {n} queries. Regen: scripts/query-lib-index.sh. CI check: --check flag. SPEC-SE-031.".format(n=len(entries)))
print()
print("| ID | Lang | Tags | Description | File |")
print("|---|---|---|---|---|")
for qid, lang, tags, desc, rel in sorted(entries):
    safe_desc = (desc or "").replace("|", "\\|")[:80]
    safe_tags = (tags or "").replace("|", "\\|")
    print("| {qid} | {lang} | {tags} | {desc} | [{rel}](./{rel}) |".format(
        qid=qid, lang=lang, tags=safe_tags, desc=safe_desc, rel=rel))
PY

if $CHECK_MODE; then
  if diff -q "$INDEX" "$TMP" >/dev/null 2>&1; then
    echo "OK: INDEX.md up-to-date"
    exit 0
  else
    echo "FAIL: INDEX.md stale — run 'bash scripts/query-lib-index.sh'" >&2
    diff "$INDEX" "$TMP" 2>/dev/null | head -15 >&2
    exit 1
  fi
else
  cp "$TMP" "$INDEX"
  echo "Generated $INDEX"
fi
