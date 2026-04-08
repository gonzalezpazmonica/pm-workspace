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

# ── Require sqlite3 ────────────────────────────────────────────────────────
if ! command -v sqlite3 &>/dev/null; then
  echo "sqlite3 not found. Install sqlite3 to build memory cache."
  exit 0
fi

# ── Find memory directories ────────────────────────────────────────────────
find_memory_dirs() {
  if [[ ! -d "$MEMORY_BASE" ]]; then
    return 0
  fi
  find "$MEMORY_BASE" -maxdepth 3 -type d -name memory 2>/dev/null
}

# ── Create/replace SQLite schema ───────────────────────────────────────────
init_db() {
  rm -f "$CACHE_DB"
  sqlite3 "$CACHE_DB" <<'SQL'
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
SQL
}

# ── Extract keywords from content ──────────────────────────────────────────
extract_keywords() {
  local text="$1"
  echo "$text" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs 'a-z0-9' '\n' \
    | awk 'length >= 4' \
    | sort -u \
    | head -20
}

# ── Escape single quotes for SQLite ────────────────────────────────────────
sql_escape() {
  echo "$1" | sed "s/'/''/g"
}

# ── Index a single .md file ────────────────────────────────────────────────
index_file() {
  local filepath="$1"
  local filename
  filename="$(basename "$filepath" .md)"
  local topic_key="$filename"
  local content
  content="$(cat "$filepath" 2>/dev/null)" || return 0
  [[ -z "$content" ]] && return 0

  local tokens_est=$(( ${#content} / 4 ))
  local type="unknown"
  # Detect type from filename prefix
  case "$filename" in
    feedback_*) type="feedback" ;;
    project_*) type="project" ;;
    user_*) type="user" ;;
    reference_*) type="reference" ;;
    decision_*) type="decision" ;;
    pattern_*) type="pattern" ;;
  esac

  local safe_content
  safe_content="$(sql_escape "$content")"
  local safe_topic
  safe_topic="$(sql_escape "$topic_key")"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  sqlite3 "$CACHE_DB" \
    "INSERT INTO memory_entries (topic_key, type, content, importance, tokens_est, created, accessed, hits)
     VALUES ('$safe_topic', '$type', '$safe_content', 50, $tokens_est, '$now', '$now', 0);"

  local entry_id
  entry_id="$(sqlite3 "$CACHE_DB" "SELECT last_insert_rowid();")"

  # Build inverted index
  local kw
  while IFS= read -r kw; do
    [[ -z "$kw" ]] && continue
    local safe_kw
    safe_kw="$(sql_escape "$kw")"
    sqlite3 "$CACHE_DB" \
      "INSERT INTO memory_index (keyword, entry_id) VALUES ('$safe_kw', $entry_id);"
  done < <(extract_keywords "$content")
}

# ── Index MEMORY.md entries (each line is a summary) ───────────────────────
index_memory_md() {
  local filepath="$1"
  [[ -f "$filepath" ]] || return 0
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^#  ]] && continue
    local topic_key
    topic_key="$(echo "$line" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')"
    [[ -z "$topic_key" ]] && topic_key="index-entry"
    local tokens_est=$(( ${#line} / 4 ))
    local safe_line
    safe_line="$(sql_escape "$line")"
    local safe_topic
    safe_topic="$(sql_escape "$topic_key")"
    local now
    now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    sqlite3 "$CACHE_DB" \
      "INSERT INTO memory_entries (topic_key, type, content, importance, tokens_est, created, accessed, hits)
       VALUES ('$safe_topic', 'index', '$safe_line', 60, $tokens_est, '$now', '$now', 0);"
  done < "$filepath"
}

# ── Main ───────────────────────────────────────────────────────────────────
main() {
  init_db
  local count=0
  local dirs
  dirs="$(find_memory_dirs)"
  [[ -z "$dirs" ]] && { echo "No memory directories found. Empty cache created."; exit 0; }

  while IFS= read -r memdir; do
    [[ -z "$memdir" ]] && continue
    # Index MEMORY.md specially
    if [[ -f "$memdir/MEMORY.md" ]]; then
      index_memory_md "$memdir/MEMORY.md"
      count=$((count + 1))
    fi
    # Index topic files
    for mdfile in "$memdir"/*.md; do
      [[ -f "$mdfile" ]] || continue
      [[ "$(basename "$mdfile")" == "MEMORY.md" ]] && continue
      index_file "$mdfile"
      count=$((count + 1))
    done
  done <<< "$dirs"

  local total
  total="$(sqlite3 "$CACHE_DB" "SELECT COUNT(*) FROM memory_entries;")"
  echo "Cache rebuilt: $CACHE_DB ($total entries from $count files)"
}

main "$@"
