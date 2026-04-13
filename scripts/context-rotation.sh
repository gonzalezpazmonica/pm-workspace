#!/usr/bin/env bash
set -uo pipefail
# context-rotation.sh — SE-033: Automated context rotation (daily/weekly/monthly)
#
# Usage:
#   bash scripts/context-rotation.sh daily    # Rotate session-hot if >24h
#   bash scripts/context-rotation.sh weekly   # Archive stale project memories, generate summary
#   bash scripts/context-rotation.sh monthly  # Consolidate + enforce 25KB cap
#   bash scripts/context-rotation.sh status   # Show rotation state and memory size

MEMORY_DIR="${MEMORY_DIR:-$HOME/.claude/projects/-home-monica-claude/memory}"
MEMORY_INDEX="$MEMORY_DIR/MEMORY.md"
SESSION_HOT="$MEMORY_DIR/session-hot.md"
ARCHIVE_DIR="$MEMORY_DIR/archive"
WEEKLY_DIR="output/weekly-summaries"
MAX_MEMORY_KB=25
STALE_PROJECT_DAYS=7
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[context-rotation] $*" >&2; }

# ── Helpers ──────────────────────────────────────────────────────────────────

file_age_hours() {
  local file="$1"
  [[ -f "$file" ]] || { echo 0; return; }
  local mod_epoch now_epoch
  mod_epoch=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  echo $(( (now_epoch - mod_epoch) / 3600 ))
}

file_age_days() {
  local file="$1"
  [[ -f "$file" ]] || { echo 0; return; }
  local mod_epoch now_epoch
  mod_epoch=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  echo $(( (now_epoch - mod_epoch) / 86400 ))
}

memory_size_kb() {
  if [[ -d "$MEMORY_DIR" ]]; then
    du -sk "$MEMORY_DIR" 2>/dev/null | awk '{print $1}'
  else
    echo 0
  fi
}

# ── Daily: Rotate session-hot.md ─────────────────────────────────────────────

cmd_daily() {
  if [[ ! -f "$SESSION_HOT" ]]; then
    log "No session-hot.md found — nothing to rotate"
    exit 0
  fi

  local age_h
  age_h=$(file_age_hours "$SESSION_HOT")

  if (( age_h < 24 )); then
    log "session-hot.md is ${age_h}h old — fresh, skipping"
    exit 0
  fi

  local today
  today=$(date +%Y-%m-%d)
  mkdir -p "$ARCHIVE_DIR/sessions"

  # Archive with date suffix to avoid collisions
  local dest="$ARCHIVE_DIR/sessions/${today}.md"
  if [[ -f "$dest" ]]; then
    dest="$ARCHIVE_DIR/sessions/${today}-$(date +%H%M%S).md"
  fi

  cp "$SESSION_HOT" "$dest"
  # Truncate to empty with header
  printf '## Session Context\n\nNew session started %s.\n' "$(date -Iseconds)" > "$SESSION_HOT"

  log "Rotated session-hot.md (${age_h}h old) → $(basename "$dest")"
}

# ── Weekly: Archive stale project memories, generate summary ──────────────────

cmd_weekly() {
  [[ -f "$MEMORY_INDEX" ]] || { log "No MEMORY.md — skipping weekly"; exit 0; }

  mkdir -p "$ARCHIVE_DIR/retired"
  mkdir -p "$WEEKLY_DIR"

  local archived=0
  local summary_lines=()

  # Scan memory files for stale project entries
  while IFS= read -r -d '' mfile; do
    local fname
    fname=$(basename "$mfile")
    [[ "$fname" == "MEMORY.md" || "$fname" == "session-hot.md" || "$fname" == "session-journal.md" ]] && continue

    # Read frontmatter type — skip non-project and feedback (never archive feedback)
    local mtype
    mtype=$(grep -m1 '^type:' "$mfile" 2>/dev/null | awk '{print $2}' || true)
    [[ "$mtype" == "feedback" ]] && continue

    local age_d
    age_d=$(file_age_days "$mfile")

    if (( age_d > STALE_PROJECT_DAYS )) && [[ "$mtype" == "project" ]]; then
      mv "$mfile" "$ARCHIVE_DIR/retired/$fname"
      # Remove from MEMORY.md index
      local escaped_fname
      escaped_fname=$(printf '%s\n' "$fname" | sed 's/[[\.*^$/]/\\&/g')
      sed -i "/${escaped_fname}/d" "$MEMORY_INDEX" 2>/dev/null || true
      summary_lines+=("- Archived: $fname (${age_d}d, type=$mtype)")
      (( archived++ )) || true
    fi
  done < <(find "$MEMORY_DIR" -maxdepth 1 -name "*.md" -not -name "MEMORY.md" -print0 2>/dev/null)

  # Generate weekly summary
  local week_id
  week_id=$(date +%Y-W%V)
  local summary_file="$WEEKLY_DIR/${week_id}.md"

  {
    echo "# Weekly Memory Summary — $week_id"
    echo ""
    echo "Generated: $(date -Iseconds)"
    echo "Memory entries: $(grep -c '^\- ' "$MEMORY_INDEX" 2>/dev/null || echo 0)"
    echo "Memory size: $(memory_size_kb)KB / ${MAX_MEMORY_KB}KB"
    echo "Archived this week: $archived"
    echo ""
    if (( ${#summary_lines[@]} > 0 )); then
      echo "## Archived Entries"
      printf '%s\n' "${summary_lines[@]}"
    else
      echo "No entries archived this week."
    fi
  } > "$summary_file"

  # Run knowledge lint (LLM Wiki pattern — Karpathy-inspired)
  local lint_script="$SCRIPT_DIR/knowledge-lint.sh"
  if [[ -x "$lint_script" ]]; then
    log "Running knowledge lint..."
    local lint_output
    lint_output=$(bash "$lint_script" 2>&1 || true)
    echo "" >> "$summary_file"
    echo "## Knowledge Lint" >> "$summary_file"
    echo '```' >> "$summary_file"
    echo "$lint_output" | tail -10 >> "$summary_file"
    echo '```' >> "$summary_file"
  fi

  log "Weekly rotation: archived=${archived}, summary=${summary_file}"
}

# ── Monthly: Consolidate + enforce 25KB cap ──────────────────────────────────

cmd_monthly() {
  # 1. Run memory-hygiene (dedup, truncate, broken refs)
  local hygiene_script="$SCRIPT_DIR/memory-hygiene.sh"
  if [[ -x "$hygiene_script" ]]; then
    bash "$hygiene_script" "$MEMORY_DIR"
    log "memory-hygiene.sh completed"
  else
    log "WARN: memory-hygiene.sh not found at $hygiene_script"
  fi

  # 2. Check size after hygiene
  local size_kb
  size_kb=$(memory_size_kb)

  if (( size_kb <= MAX_MEMORY_KB )); then
    log "Monthly OK: ${size_kb}KB <= ${MAX_MEMORY_KB}KB cap"
    return 0
  fi

  # 3. Size exceeds cap — archive oldest non-feedback entries by modification date
  log "Monthly: ${size_kb}KB > ${MAX_MEMORY_KB}KB — trimming oldest entries"
  mkdir -p "$ARCHIVE_DIR/retired"

  while (( $(memory_size_kb) > MAX_MEMORY_KB )); do
    # Find oldest non-feedback, non-index memory file
    local oldest=""
    local oldest_epoch=999999999999

    while IFS= read -r -d '' mfile; do
      local fname
      fname=$(basename "$mfile")
      [[ "$fname" == "MEMORY.md" || "$fname" == "session-hot.md" || "$fname" == "session-journal.md" ]] && continue

      local mtype
      mtype=$(grep -m1 '^type:' "$mfile" 2>/dev/null | awk '{print $2}' || true)
      [[ "$mtype" == "feedback" ]] && continue  # Never archive feedback

      local mod_epoch
      mod_epoch=$(stat -c %Y "$mfile" 2>/dev/null || stat -f %m "$mfile" 2>/dev/null || echo 0)
      if (( mod_epoch < oldest_epoch )); then
        oldest_epoch=$mod_epoch
        oldest="$mfile"
      fi
    done < <(find "$MEMORY_DIR" -maxdepth 1 -name "*.md" -not -name "MEMORY.md" -print0 2>/dev/null)

    if [[ -z "$oldest" ]]; then
      log "No more entries to archive — cannot reduce further"
      break
    fi

    local fname
    fname=$(basename "$oldest")
    mv "$oldest" "$ARCHIVE_DIR/retired/$fname"
    local escaped_fname
    escaped_fname=$(printf '%s\n' "$fname" | sed 's/[[\.*^$/]/\\&/g')
    sed -i "/${escaped_fname}/d" "$MEMORY_INDEX" 2>/dev/null || true
    log "Archived (monthly cap): $fname"
  done

  log "Monthly complete: $(memory_size_kb)KB"
}

# ── Status ───────────────────────────────────────────────────────────────────

cmd_status() {
  local size_kb
  size_kb=$(memory_size_kb)
  local entry_count=0
  [[ -f "$MEMORY_INDEX" ]] && entry_count=$(grep -c '^\- ' "$MEMORY_INDEX" 2>/dev/null || echo 0)

  local hot_age="N/A"
  [[ -f "$SESSION_HOT" ]] && hot_age="$(file_age_hours "$SESSION_HOT")h"

  local archived_sessions=0
  [[ -d "$ARCHIVE_DIR/sessions" ]] && archived_sessions=$(find "$ARCHIVE_DIR/sessions" -name "*.md" 2>/dev/null | wc -l)
  local archived_retired=0
  [[ -d "$ARCHIVE_DIR/retired" ]] && archived_retired=$(find "$ARCHIVE_DIR/retired" -name "*.md" 2>/dev/null | wc -l)

  local last_weekly="never"
  if [[ -d "$WEEKLY_DIR" ]]; then
    local latest
    latest=$(ls -t "$WEEKLY_DIR"/*.md 2>/dev/null | head -1)
    [[ -n "$latest" ]] && last_weekly=$(basename "$latest" .md)
  fi

  cat <<EOS
Context Rotation Status (SE-033)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Memory size:      ${size_kb}KB / ${MAX_MEMORY_KB}KB $([ "$size_kb" -le "$MAX_MEMORY_KB" ] && echo "OK" || echo "OVER")
Active entries:   ${entry_count}
session-hot age:  ${hot_age}
Archived sessions: ${archived_sessions}
Archived retired:  ${archived_retired}
Last weekly:      ${last_weekly}
EOS
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "${1:-status}" in
  daily)   cmd_daily   ;;
  weekly)  cmd_weekly  ;;
  monthly) cmd_monthly ;;
  status)  cmd_status  ;;
  *)       echo "Usage: context-rotation.sh {daily|weekly|monthly|status}" >&2; exit 1 ;;
esac
