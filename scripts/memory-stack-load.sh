#!/usr/bin/env bash
# memory-stack-load.sh — Token-budgeted progressive memory loading
# SPEC-089: Memory Stack L0-L3
#
# Usage: bash scripts/memory-stack-load.sh L0|L1|L2|L3 [topic]
# Each layer outputs to stdout within its token budget.
# Exit 0 always (graceful degradation).
set -uo pipefail

LAYER="${1:-}"
TOPIC="${2:-}"
PM_ROOT="${PM_WORKSPACE_ROOT:-${HOME}/claude}"
PROFILES_DIR="${SAVIA_PROFILES_DIR:-${PM_ROOT}/.claude/profiles}"
MEMORY_BASE="${HOME}/.savia-memory"
LEGACY_MEMORY_BASE="${HOME}/.claude/projects"
CACHE_DB="${HOME}/.savia/memory-cache.db"

# ── Budget limits (chars, ~4 chars per token) ──────────────────────────────
BUDGET_L0=200   # ~50 tokens
BUDGET_L1=600   # ~150 tokens
BUDGET_L2=2000  # ~500 tokens
BUDGET_L3=4000  # ~1000 tokens

# ── Helpers ────────────────────────────────────────────────────────────────
truncate_to() {
  local budget="$1"
  head -c "$budget"
}

find_memory_dir() {
  # Find first memory directory (prefer canonical, fallback legacy)
  local proj_slug
  proj_slug="$(echo "$PWD" | sed 's|/|-|g')"
  for base in "$MEMORY_BASE" "$LEGACY_MEMORY_BASE"; do
    if [[ -d "$base/$proj_slug/memory" ]]; then
      echo "$base/$proj_slug/memory"
      return
    fi
  done
  # Fallback: find any memory dir in canonical or legacy
  local found=""
  for base in "$MEMORY_BASE" "$LEGACY_MEMORY_BASE"; do
    found=$(find "$base" -maxdepth 4 -type d -name memory 2>/dev/null | head -1 || true)
    [[ -n "$found" ]] && { echo "$found"; return; }
  done
}

# ── L0: Identity (~50 tokens) ─────────────────────────────────────────────
load_l0() {
  local active_file="$PROFILES_DIR/active-user.md"
  local name="" role="" language=""

  # Try active-user.md first
  if [[ -f "$active_file" ]]; then
    local slug
    slug="$(grep -m1 'active_slug' "$active_file" 2>/dev/null | sed 's/.*: *//' | tr -d '"' | tr -d "'")"
    if [[ -n "$slug" ]]; then
      local id_file="$PROFILES_DIR/users/$slug/identity.md"
      if [[ -f "$id_file" ]]; then
        name="$(grep -m1 '^name:' "$id_file" | sed 's/^name: *//' | tr -d '"')"
        role="$(grep -m1 '^role:' "$id_file" | sed 's/^role: *//' | tr -d '"')"
      fi
      local pref_file="$PROFILES_DIR/users/$slug/preferences.md"
      if [[ -f "$pref_file" ]]; then
        language="$(grep -m1 '^language:' "$pref_file" | sed 's/^language: *//' | tr -d '"')"
      fi
    fi
  fi

  # Scan identity files if no active-user
  if [[ -z "$name" ]]; then
    for id_file in "$PROFILES_DIR"/users/*/identity.md; do
      [[ -f "$id_file" ]] || continue
      name="$(grep -m1 '^name:' "$id_file" | sed 's/^name: *//' | tr -d '"')"
      role="$(grep -m1 '^role:' "$id_file" | sed 's/^role: *//' | tr -d '"')"
      [[ -n "$name" ]] && break
    done
  fi

  [[ -z "$name" ]] && name="unknown"
  [[ -z "$role" ]] && role="user"
  [[ -z "$language" ]] && language="es"

  echo "User: $name | Role: $role | Lang: $language" | truncate_to "$BUDGET_L0"
}

# ── L1: Critical facts (~150 tokens) ──────────────────────────────────────
load_l1() {
  local memdir
  memdir="$(find_memory_dir)"
  if [[ -z "$memdir" || ! -f "$memdir/MEMORY.md" ]]; then
    echo "No memory index found."
    return 0
  fi

  # Read first 8 non-empty, non-comment entries
  local count=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^#  ]] && continue
    # Trim to one-liner: extract description after " — "
    local summary
    summary="$(echo "$line" | sed 's/.*— //' | head -c 75)"
    echo "- $summary"
    count=$((count + 1))
    [[ $count -ge 8 ]] && break
  done < "$memdir/MEMORY.md" | truncate_to "$BUDGET_L1"
}

# ── L2: Topic recall (~500 tokens) ────────────────────────────────────────
load_l2() {
  if [[ -z "$TOPIC" ]]; then
    echo "Usage: memory-stack-load.sh L2 <topic>"
    return 0
  fi

  local memdir
  memdir="$(find_memory_dir)"
  [[ -z "$memdir" ]] && { echo "No memory directory found."; return 0; }

  # Find matching topic file
  local found=""
  for mdfile in "$memdir"/*.md; do
    [[ -f "$mdfile" ]] || continue
    local fname
    fname="$(basename "$mdfile" .md)"
    if [[ "$fname" == *"$TOPIC"* ]]; then
      found="$mdfile"
      break
    fi
  done

  if [[ -z "$found" ]]; then
    # Grep through files for topic keyword
    local match
    match="$(grep -rl "$TOPIC" "$memdir"/*.md 2>/dev/null | head -1)"
    [[ -n "$match" ]] && found="$match"
  fi

  if [[ -n "$found" ]]; then
    cat "$found" | truncate_to "$BUDGET_L2"
  else
    echo "No topic file matching '$TOPIC'."
  fi
}

# ── L3: Deep search (~1000 tokens) ────────────────────────────────────────
load_l3() {
  if [[ -z "$TOPIC" ]]; then
    echo "Usage: memory-stack-load.sh L3 <topic>"
    return 0
  fi

  # Try SQLite cache first
  if [[ -f "$CACHE_DB" ]] && command -v sqlite3 &>/dev/null; then
    local safe_topic
    safe_topic="$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | sed "s/'/''/g")"
    local results
    results="$(sqlite3 "$CACHE_DB" \
      "SELECT e.topic_key, substr(e.content, 1, 200)
       FROM memory_entries e
       JOIN memory_index i ON e.id = i.entry_id
       WHERE i.keyword LIKE '%${safe_topic}%'
       GROUP BY e.id
       ORDER BY e.importance DESC
       LIMIT 10;" 2>/dev/null)"
    if [[ -n "$results" ]]; then
      echo "$results" | truncate_to "$BUDGET_L3"
      return 0
    fi
  fi

  # Fallback: grep memory files directly
  local memdir
  memdir="$(find_memory_dir)"
  if [[ -n "$memdir" ]]; then
    grep -rli "$TOPIC" "$memdir"/*.md 2>/dev/null \
      | while IFS= read -r f; do
          echo "--- $(basename "$f" .md) ---"
          head -c 300 "$f"
          echo ""
        done \
      | truncate_to "$BUDGET_L3"
    return 0
  fi

  echo "No memory sources available for '$TOPIC'."
}

# ── Dispatcher ─────────────────────────────────────────────────────────────
case "$LAYER" in
  L0) load_l0 ;;
  L1) load_l1 ;;
  L2) load_l2 ;;
  L3) load_l3 ;;
  *)
    echo "Usage: memory-stack-load.sh L0|L1|L2|L3 [topic]"
    echo "  L0 — Identity (~50 tokens)"
    echo "  L1 — Critical facts (~150 tokens)"
    echo "  L2 — Topic recall (~500 tokens)"
    echo "  L3 — Deep search (~1000 tokens)"
    ;;
esac

exit 0
