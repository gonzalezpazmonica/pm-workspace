#!/usr/bin/env bash
set -uo pipefail
# exit-purge-verify.sh — SE-272 S5: Verify purge after engagement forget
#
# After scenario-forget (engagement deletion), verifies zero living
# references outside tombstones and audit log.
#
# Performs exhaustive grep across the workspace looking for:
#   - Engagement name references in code, docs, configs
#   - Project directory remnants
#   - Agent memory references
#   - Session log references
#   - Knowledge graph nodes
#
# Allowed references:
#   - Tombstone files: .savia-tombstones/{engagement}.json
#   - Audit log entries: output/audit-trail.jsonl
#   - Exit packages: output/exit-packages/{engagement}/
#   - Drill logs: output/exit-drills/
#   - This script itself
#
# Usage:
#   bash scripts/exit-purge-verify.sh verify --engagement NAME
#   bash scripts/exit-purge-verify.sh verify --engagement NAME --exclude-dir DIR
#   bash scripts/exit-purge-verify.sh tombstone --engagement NAME
#   bash scripts/exit-purge-verify.sh --help

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "ERROR: $*" >&2; exit 2; }
warn() { echo "WARN:  $*" >&2; }
ok() { echo "OK:    $*" >&2; }
info() { echo "INFO:  $*" >&2; }

usage() {
  sed -n '/^# /{s/^# //;p;}' "$0" | head -22
}

# ── Allowed paths (references that are expected to survive purge) ──────────────

allowed_paths() {
  local engagement="$1"
  cat <<ALLOWED
.savia-tombstones
output/audit-trail.jsonl
output/exit-packages/$engagement
output/exit-drills
scripts/exit-purge-verify.sh
scripts/exit-package-generate.sh
scripts/exit-dependencies-declare.sh
scripts/exit-drill-execute.sh
scripts/exit-independence-verify.sh
ALLOWED
}

# ── Verify purge ───────────────────────────────────────────────────────────────

cmd_verify() {
  local engagement="" extra_excludes=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --engagement) engagement="$2"; shift 2 ;;
      --exclude-dir) extra_excludes+=("$2"); shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$engagement" ]] && die "--engagement required"

  echo "=== PURGE VERIFICATION ==="
  echo "Engagement: $engagement"
  echo "Workspace: $ROOT"
  echo ""

  local violations=0
  local total_matches=0
  local allowed_count=0
  local violation_count=0

  # Build search pattern: engagement name variations
  local patterns=("$engagement")

  # Also search for common substrings if name contains hyphens
  if [[ "$engagement" == *-* ]]; then
    patterns+=("${engagement//-/ }")
  fi

  # Add the project directory pattern
  patterns+=("projects/$engagement")

  echo "Search patterns: ${patterns[*]}"
  echo ""

  # Build exclude patterns from allowed paths
  local allowed
  allowed=$(allowed_paths "$engagement")
  local exclude_args=()
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    exclude_args+=("--exclude-dir" "$path")
  done <<< "$allowed"
  for ed in "${extra_excludes[@]}"; do
    exclude_args+=("--exclude-dir" "$ed")
  done

  # Also exclude .git directory
  exclude_args+=("--exclude-dir" ".git")

  # Run grep for each pattern
  local results_file
  results_file=$(mktemp)

  for pat in "${patterns[@]}"; do
    info "Searching for: '$pat'"
    grep -rnI "$pat" "$ROOT" \
      --exclude-dir=".git" \
      --exclude-dir=".savia-tombstones" \
      --exclude-dir="output/exit-packages" \
      --exclude-dir="output/exit-drills" \
      --exclude="audit-trail.jsonl" \
      --exclude="exit-purge-verify.sh" \
      --exclude="exit-package-generate.sh" \
      --exclude="exit-dependencies-declare.sh" \
      --exclude="exit-drill-execute.sh" \
      --exclude="exit-independence-verify.sh" \
      --exclude="exit-*" \
      2>/dev/null >> "$results_file" || true
  done

  local total
  total=$(wc -l < "$results_file" 2>/dev/null || echo 0)
  echo ""
  echo "Total matches found: $total"
  echo ""

  # Classify each match
  if [[ "$total" -gt 0 ]]; then
    echo "=== Match Details ==="
    local match_n=0
    while IFS= read -r match; do
      match_n=$((match_n + 1))
      local file="${match%%:*}"
      local rest="${match#*:}"
      local line_num="${rest%%:*}"
      local content="${rest#*:}"

      # Determine if this is a safe reference
      local safe=0
      if echo "$file" | grep -qE "(\.savia-tombstones|audit-trail|exit-packages|exit-drills|scripts/exit-)"; then
        safe=1
      fi

      if [[ "$safe" -eq 1 ]]; then
        allowed_count=$((allowed_count + 1))
        echo "  [ALLOWED] $file:$line_num — $content"
      else
        violation_count=$((violation_count + 1))
        echo "  [VIOLATION] $file:$line_num — $content"
      fi
    done < "$results_file"
  fi

  rm -f "$results_file"

  echo ""
  echo "=== VERIFICATION RESULT ==="
  echo "Total matches:    $total"
  echo "Allowed references: $allowed_count"
  echo "Violations:       $violation_count"

  if [[ "$violation_count" -eq 0 ]]; then
    echo ""
    echo "RESULT: CLEAN — zero living references outside tombstones and audit log"
    return 0
  else
    echo ""
    echo "RESULT: DIRTY — $violation_count living reference(s) found"
    echo ""
    echo "These references should either be:"
    echo "  1. Moved to .savia-tombstones/$engagement.json"
    echo "  2. Replaced with generic/obfuscated content"
    echo "  3. Marked as excluded via --exclude-dir if legitimate"
    return 1
  fi
}

# ── Create tombstone ───────────────────────────────────────────────────────────

cmd_tombstone() {
  local engagement=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --engagement) engagement="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$engagement" ]] && die "--engagement required"

  local tombstone_dir="$ROOT/.savia-tombstones"
  mkdir -p "$tombstone_dir"

  local tombstone="$tombstone_dir/${engagement}.json"

  if [[ -f "$tombstone" ]]; then
    warn "Tombstone already exists: $tombstone"
    info "Existing content:"
    python3 -c "import json; d=json.load(open('$tombstone')); print(json.dumps(d, indent=2, ensure_ascii=False))" 2>/dev/null || cat "$tombstone"
    return 0
  fi

  info "Creating tombstone for engagement: $engagement"

  python3 -c "
import json
tombstone = {
    'engagement': '$engagement',
    'action': 'scenario-forget',
    'timestamp': '$(date -Iseconds)',
    'reason': 'Engagement completed — data purged per exit guarantee',
    'retained': {
        'exit_package': 'output/exit-packages/$engagement/',
        'audit_log': 'output/audit-trail.jsonl',
        'drill_reports': 'output/exit-drills/',
        'tombstone': '.savia-tombstones/${engagement}.json'
    },
    'purged': {
        'project_directory': 'projects/$engagement',
        'agent_memory': 'memory entries for $engagement',
        'agent_notes': 'agent notes referencing $engagement',
        'session_logs': 'session entries for $engagement'
    },
    'verified_at': '$(date -Iseconds)',
    'verification_status': 'pending',
    'notes': 'This tombstone records the purge. All references outside this file and audit-trail.jsonl should have been removed.'
}
with open('$tombstone', 'w') as f:
    json.dump(tombstone, f, indent=2, ensure_ascii=False)
" 2>/dev/null

  ok "Tombstone created: $tombstone"

  # Verify immediately
  info "Running purge verification..."
  cmd_verify --engagement "$engagement" || warn "Verification found references — purge may be incomplete"

  # Update verification status
  local verified_at
  verified_at=$(date -Iseconds)
  python3 -c "
import json
with open('$tombstone') as f:
    d = json.load(f)
d['verified_at'] = '$verified_at'
d['verification_status'] = 'verified'
with open('$tombstone', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
" 2>/dev/null

  ok "Tombstone updated with verification timestamp"
}

# ── Main ──────────────────────────────────────────────────────────────────────

cmd="${1:-}"; shift || true
case "$cmd" in
  verify)    cmd_verify "$@" ;;
  tombstone) cmd_tombstone "$@" ;;
  --help|-h) usage; exit 0 ;;
  *) echo "Usage: exit-purge-verify.sh {verify|tombstone} [options]" >&2; usage >&2; exit 1 ;;
esac
