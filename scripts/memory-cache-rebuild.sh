#!/usr/bin/env bash
# memory-cache-rebuild.sh — Rebuild SQLite cache from .md memory files
# SPEC-089: Memory Stack L0-L3 — SQLite as cache, .md as truth
#
# Usage: bash scripts/memory-cache-rebuild.sh
# Creates/replaces ~/.savia/memory-cache.db from auto-memory .md files
set -uo pipefail

CACHE_DIR="${HOME}/.savia"
CACHE_DB="${CACHE_DIR}/memory-cache.db"
MEMORY_BASE="${HOME}/.claude/projects"

mkdir -p "$CACHE_DIR"

# ── Require python3 with sqlite3 ──────────────────────────────────────────
if ! python3 -c "import sqlite3" 2>/dev/null; then
  echo "python3 with sqlite3 module required."
  exit 0
fi

# ── Find memory directories ──────────────────────────────────────────────
if [[ ! -d "$MEMORY_BASE" ]]; then
  echo "No memory directories found. Empty cache created."
  exit 0
fi

MEMORY_DIRS=$(find "$MEMORY_BASE" -maxdepth 3 -type d -name memory 2>/dev/null)
if [[ -z "$MEMORY_DIRS" ]]; then
  echo "No memory directories found. Empty cache created."
  exit 0
fi

# ── Build cache via Python ────────────────────────────────────────────────
python3 - "$CACHE_DB" "$MEMORY_DIRS" <<'PYEOF'
import sqlite3, sys, os, re, glob
from pathlib import Path

db_path = sys.argv[1]
mem_dirs = sys.argv[2].strip().split('\n')

# Remove old cache and create fresh
if os.path.exists(db_path):
    os.remove(db_path)

conn = sqlite3.connect(db_path)
c = conn.cursor()
c.executescript("""
CREATE TABLE memory_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  topic_key TEXT NOT NULL,
  type TEXT DEFAULT 'unknown',
  content TEXT NOT NULL,
  importance INTEGER DEFAULT 50,
  tokens_est INTEGER DEFAULT 0,
  created TEXT DEFAULT '',
  accessed TEXT DEFAULT '',
  hits INTEGER DEFAULT 0
);
CREATE TABLE memory_index (
  keyword TEXT NOT NULL,
  entry_id INTEGER NOT NULL,
  FOREIGN KEY (entry_id) REFERENCES memory_entries(id)
);
CREATE INDEX idx_memory_index_keyword ON memory_index(keyword);
CREATE INDEX idx_memory_entries_topic ON memory_entries(topic_key);
""")

from datetime import datetime, timezone
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
file_count = 0

def extract_keywords(text, max_kw=20):
    words = re.findall(r'[a-zA-Z0-9]{4,}', text.lower())
    return list(dict.fromkeys(words))[:max_kw]

def detect_type(filename):
    for prefix, typ in [('feedback_','feedback'),('project_','project'),
                         ('user_','user'),('reference_','reference'),
                         ('decision_','decision'),('pattern_','pattern')]:
        if filename.startswith(prefix):
            return typ
    return 'unknown'

def index_file(filepath):
    global file_count
    content = Path(filepath).read_text(errors='replace').strip()
    if not content:
        return
    filename = Path(filepath).stem
    topic_key = filename
    typ = detect_type(filename)
    tokens_est = len(content) // 4

    c.execute(
        "INSERT INTO memory_entries (topic_key,type,content,importance,tokens_est,created,accessed,hits) VALUES (?,?,?,50,?,?,?,0)",
        (topic_key, typ, content, tokens_est, now, now)
    )
    entry_id = c.lastrowid
    for kw in extract_keywords(content):
        c.execute("INSERT INTO memory_index (keyword,entry_id) VALUES (?,?)", (kw, entry_id))
    file_count += 1

def index_memory_md(filepath):
    global file_count
    for line in Path(filepath).read_text(errors='replace').splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        m = re.search(r'\[([^\]]+)\]', line)
        topic_key = m.group(1) if m else 'index-entry'
        tokens_est = len(line) // 4
        c.execute(
            "INSERT INTO memory_entries (topic_key,type,content,importance,tokens_est,created,accessed,hits) VALUES (?,?,?,60,?,?,?,0)",
            (topic_key, 'index', line, tokens_est, now, now)
        )
    file_count += 1

for mem_dir in mem_dirs:
    mem_dir = mem_dir.strip()
    if not mem_dir or not os.path.isdir(mem_dir):
        continue
    memory_md = os.path.join(mem_dir, 'MEMORY.md')
    if os.path.isfile(memory_md):
        index_memory_md(memory_md)
    for md in sorted(glob.glob(os.path.join(mem_dir, '*.md'))):
        if os.path.basename(md) == 'MEMORY.md':
            continue
        index_file(md)

conn.commit()
total = c.execute("SELECT COUNT(*) FROM memory_entries").fetchone()[0]
print(f"Cache rebuilt: {db_path} ({total} entries from {file_count} files)")
conn.close()
PYEOF
