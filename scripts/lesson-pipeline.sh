#!/usr/bin/env bash
set -uo pipefail
# lesson-pipeline.sh — SE-032: Cross-Project Lessons Pipeline
#
# Extracts, catalogues, and searches lessons learned across projects.
# Lessons are PII-sanitized and stored as markdown with YAML frontmatter.
#
# Usage:
#   bash scripts/lesson-pipeline.sh extract --domain {domain} --problem "..." --solution "..." [--projects p1,p2]
#   bash scripts/lesson-pipeline.sh search  --query "keyword" [--domain domain]
#   bash scripts/lesson-pipeline.sh stats
#   bash scripts/lesson-pipeline.sh status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LESSONS_DIR="${LESSONS_DIR:-$REPO_ROOT/output/lessons}"
INDEX_FILE="$LESSONS_DIR/index.jsonl"
ARCHIVE_DIR="$LESSONS_DIR/archive"
TODAY=$(date +%Y-%m-%d)
MAX_LESSON_AGE_DAYS=90

log() { echo "[lesson-pipeline] $*" >&2; }

# ── PII sanitization (Rule #20) ─────────────────────────────────────────────

sanitize_pii() {
  local text="$1"
  # Remove emails
  text=$(echo "$text" | sed -E 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/[email]/g')
  # Remove IPs
  text=$(echo "$text" | sed -E 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/[ip]/g')
  # Remove connection strings
  text=$(echo "$text" | sed -E 's/(Server\s*=|Data Source\s*=|jdbc:|mongodb:\/\/|redis:\/\/)[^;"\n]*/[connection]/gi')
  # Remove PAT-like tokens (52+ base64 chars)
  text=$(echo "$text" | sed -E 's/[A-Za-z0-9+\/]{52,}=*/[token]/g')
  echo "$text"
}

# ── Extract lesson ───────────────────────────────────────────────────────────

cmd_extract() {
  local domain="" problem="" solution="" projects="" agents="" confidence=80
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain)     domain="$2"; shift 2 ;;
      --problem)    problem="$2"; shift 2 ;;
      --solution)   solution="$2"; shift 2 ;;
      --projects)   projects="$2"; shift 2 ;;
      --agents)     agents="$2"; shift 2 ;;
      --confidence) confidence="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$domain" || -z "$problem" || -z "$solution" ]]; then
    echo "Usage: lesson-pipeline.sh extract --domain {domain} --problem \"...\" --solution \"...\"" >&2
    echo "  Optional: --projects p1,p2 --agents agent1,agent2 --confidence 80" >&2
    return 1
  fi

  mkdir -p "$LESSONS_DIR"

  # Generate slug from problem
  local slug
  slug=$(echo "$problem" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | head -c 50)

  local filename="${TODAY}-${slug}.md"
  local filepath="$LESSONS_DIR/$filename"

  # Sanitize PII
  problem=$(sanitize_pii "$problem")
  solution=$(sanitize_pii "$solution")

  # Format projects and agents as YAML arrays
  local projects_yaml="[]"
  if [[ -n "$projects" ]]; then
    projects_yaml="[$(echo "$projects" | sed 's/,/, /g')]"
  fi
  local agents_yaml="[]"
  if [[ -n "$agents" ]]; then
    agents_yaml="[$(echo "$agents" | sed 's/,/, /g')]"
  fi

  # Write lesson file
  cat > "$filepath" <<LESSON
---
date: $TODAY
slug: $slug
projects: $projects_yaml
agents: $agents_yaml
domain: $domain
confidence: $confidence
---

## Problem
$problem

## Solution
$solution

## Applicability
Cross-project lesson in domain: $domain.
LESSON

  # Update index
  local index_entry
  index_entry=$(printf '{"date":"%s","slug":"%s","domain":"%s","projects":"%s","agents":"%s","confidence":%d,"file":"%s"}' \
    "$TODAY" "$slug" "$domain" "$projects" "$agents" "$confidence" "$filename")
  echo "$index_entry" >> "$INDEX_FILE"

  log "Lesson extracted: $filename (domain=$domain, confidence=$confidence)"
  echo "$filepath"
}

# ── Search lessons ───────────────────────────────────────────────────────────

cmd_search() {
  local query="" domain=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --query)  query="$2"; shift 2 ;;
      --domain) domain="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$query" && -z "$domain" ]]; then
    echo "Usage: lesson-pipeline.sh search --query \"keyword\" [--domain domain]" >&2
    return 1
  fi

  if [[ ! -d "$LESSONS_DIR" ]]; then
    echo "No lessons directory found."
    return 0
  fi

  local results=0
  echo "Lesson Search Results"
  echo "━━━━━━━━━━━━━━━━━━━━"

  while IFS= read -r -d '' lesson_file; do
    local match=false

    if [[ -n "$domain" ]]; then
      grep -qi "^domain: $domain" "$lesson_file" 2>/dev/null && match=true
    fi

    if [[ -n "$query" ]]; then
      grep -qi "$query" "$lesson_file" 2>/dev/null && match=true
    fi

    if $match; then
      local ldate lslug ldomain lconf
      ldate=$(grep -m1 '^date:' "$lesson_file" 2>/dev/null | awk '{print $2}')
      lslug=$(grep -m1 '^slug:' "$lesson_file" 2>/dev/null | awk '{print $2}')
      ldomain=$(grep -m1 '^domain:' "$lesson_file" 2>/dev/null | awk '{print $2}')
      lconf=$(grep -m1 '^confidence:' "$lesson_file" 2>/dev/null | awk '{print $2}')
      local problem_line
      problem_line=$(sed -n '/^## Problem/,/^##/{/^## Problem/d;/^##/d;p}' "$lesson_file" | head -1)

      echo ""
      echo "  [$ldate] $lslug ($ldomain, ${lconf}%)"
      echo "    $problem_line"
      echo "    File: $(basename "$lesson_file")"
      (( results++ )) || true
    fi
  done < <(find "$LESSONS_DIR" -maxdepth 1 -name "*.md" -not -name "index.jsonl" -print0 2>/dev/null)

  echo ""
  echo "Found: $results lesson(s)"
}

# ── Stats ────────────────────────────────────────────────────────────────────

cmd_stats() {
  if [[ ! -d "$LESSONS_DIR" ]]; then
    echo "No lessons directory. Extract your first lesson with: /lesson-extract"
    return 0
  fi

  local total=0 archived=0
  total=$(find "$LESSONS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
  [[ -d "$ARCHIVE_DIR" ]] && archived=$(find "$ARCHIVE_DIR" -name "*.md" 2>/dev/null | wc -l)

  # Count by domain
  local domains=""
  if [[ -f "$INDEX_FILE" ]]; then
    domains=$(grep -oP '"domain":"[^"]*"' "$INDEX_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -10)
  fi

  cat <<EOS
Cross-Project Lessons Stats (SE-032)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Active lessons:   $total
Archived:         $archived
Index entries:    $(wc -l < "$INDEX_FILE" 2>/dev/null || echo 0)

Top domains:
$domains
EOS
}

# ── Status ───────────────────────────────────────────────────────────────────

cmd_status() {
  local lesson_count=0
  [[ -d "$LESSONS_DIR" ]] && lesson_count=$(find "$LESSONS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)

  local index_count=0
  [[ -f "$INDEX_FILE" ]] && index_count=$(wc -l < "$INDEX_FILE" 2>/dev/null || echo 0)

  cat <<EOS
Lesson Pipeline Status (SE-032)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Lessons dir:      $LESSONS_DIR
Active lessons:   $lesson_count
Index entries:    $index_count
Archive dir:      $ARCHIVE_DIR
EOS
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "${1:-status}" in
  extract) shift; cmd_extract "$@" ;;
  search)  shift; cmd_search "$@"  ;;
  stats)   cmd_stats   ;;
  status)  cmd_status  ;;
  *)       echo "Usage: lesson-pipeline.sh {extract|search|stats|status}" >&2; exit 1 ;;
esac
