#!/bin/bash
# memory-extract-lib.sh — Shared functions for memory extraction hooks
# Used by: stop-memory-extract.sh

MIN_LENGTH=${MIN_LENGTH:-50}

# Quality gate: reject short, duplicate, or PII-containing items
passes_quality_gate() {
  local text="$1"
  local memory_dir="$2"
  [[ ${#text} -lt $MIN_LENGTH ]] && return 1
  echo "$text" | grep -qE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' && return 1
  local check="${text:0:40}"
  # Check only previously saved session_* files (not session-hot.md source)
  grep -rqF "$check" "$memory_dir"/session_*.md 2>/dev/null && return 1
  return 0
}

# Register a memory file in MEMORY.md index
register_in_index() {
  local memory_md="$1" filename="$2" title="$3" desc="$4"
  [[ ! -f "$memory_md" ]] && touch "$memory_md"
  local lines
  lines=$(wc -l < "$memory_md")
  [[ "$lines" -ge 195 ]] && return 0
  grep -qF "$filename" "$memory_md" 2>/dev/null && return 0
  echo "- [$title]($filename) — ${desc:0:80}" >> "$memory_md"
}

# Save a memory file with frontmatter and register in index
# Sets ITEMS_SAVED++ (caller must declare ITEMS_SAVED)
save_memory_file() {
  local memory_dir="$1" memory_md="$2"
  local filename="$3" name="$4" desc="$5" type="$6" content="$7"
  cat > "$memory_dir/$filename" << MEMEOF
---
name: $name
description: $desc
type: $type
---

$content

**Why:** Extracted automatically at session stop (SPEC-013v2).
**How to apply:** Review and incorporate if still relevant.
MEMEOF
  register_in_index "$memory_md" "$filename" "$name" "$desc"
  ITEMS_SAVED=$((ITEMS_SAVED + 1))
}
