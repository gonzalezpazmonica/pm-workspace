#!/usr/bin/env bash
set -uo pipefail
# skills-lock.sh — SHA-256 integrity verification for skills
#
# Learned from multica-ai/multica: lock file with hashes for dependency
# verification. Critical for enterprise distribution (SE-008) where
# customers need to verify skill integrity after installation.
#
# Usage:
#   bash scripts/skills-lock.sh generate    # create/update .skills-lock.json
#   bash scripts/skills-lock.sh verify      # check all skills against lock
#   bash scripts/skills-lock.sh diff        # show changed skills since lock

LOCK_FILE=".skills-lock.json"
SKILLS_DIR=".claude/skills"
AGENTS_DIR=".claude/agents"

die() { echo "ERROR: $*" >&2; exit 2; }

cmd_generate() {
  echo "Generating $LOCK_FILE..."
  local entries=""
  local count=0

  # Hash all SKILL.md files
  while IFS= read -r -d '' skill_file; do
    local rel_path="${skill_file#./}"
    local hash
    hash=$(sha256sum "$skill_file" | awk '{print $1}')
    local lines
    lines=$(wc -l < "$skill_file")
    [[ -n "$entries" ]] && entries+=","
    entries+="$(printf '\n    "%s": {"hash": "%s", "lines": %d}' "$rel_path" "$hash" "$lines")"
    ((count++))
  done < <(find "$SKILLS_DIR" -name "SKILL.md" -type f -print0 2>/dev/null | sort -z)

  # Hash all agent files
  while IFS= read -r -d '' agent_file; do
    local rel_path="${agent_file#./}"
    local hash
    hash=$(sha256sum "$agent_file" | awk '{print $1}')
    local lines
    lines=$(wc -l < "$agent_file")
    [[ -n "$entries" ]] && entries+=","
    entries+="$(printf '\n    "%s": {"hash": "%s", "lines": %d}' "$rel_path" "$hash" "$lines")"
    ((count++))
  done < <(find "$AGENTS_DIR" -name "*.md" -type f -print0 2>/dev/null | sort -z)

  cat > "$LOCK_FILE" <<EOF
{
  "version": 1,
  "generated_at": "$(date -Iseconds)",
  "total_entries": $count,
  "entries": {$entries
  }
}
EOF
  echo "Generated: $count entries in $LOCK_FILE"
}

cmd_verify() {
  [[ -f "$LOCK_FILE" ]] || die "No $LOCK_FILE found. Run: skills-lock.sh generate"
  local pass=0 fail=0 missing=0

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    local expected_hash
    expected_hash=$(python3 -c "import json; d=json.load(open('$LOCK_FILE')); print(d['entries'].get('$path',{}).get('hash',''))" 2>/dev/null)
    [[ -z "$expected_hash" ]] && continue

    if [[ ! -f "$path" ]]; then
      echo "  MISSING: $path"
      ((missing++))
      continue
    fi

    local actual_hash
    actual_hash=$(sha256sum "$path" | awk '{print $1}')
    if [[ "$actual_hash" == "$expected_hash" ]]; then
      ((pass++))
    else
      echo "  CHANGED: $path"
      echo "    expected: ${expected_hash:0:16}..."
      echo "    actual:   ${actual_hash:0:16}..."
      ((fail++))
    fi
  done < <(python3 -c "import json; [print(k) for k in json.load(open('$LOCK_FILE'))['entries']]" 2>/dev/null)

  echo ""
  echo "Verified: $pass pass, $fail changed, $missing missing"
  [[ "$fail" -gt 0 || "$missing" -gt 0 ]] && return 1
  return 0
}

cmd_diff() {
  [[ -f "$LOCK_FILE" ]] || die "No $LOCK_FILE found. Run: skills-lock.sh generate"
  echo "Changed since lock:"
  local changes=0

  while IFS= read -r path; do
    [[ -z "$path" || ! -f "$path" ]] && continue
    local expected
    expected=$(python3 -c "import json; print(json.load(open('$LOCK_FILE'))['entries'].get('$path',{}).get('hash',''))" 2>/dev/null)
    local actual
    actual=$(sha256sum "$path" | awk '{print $1}')
    if [[ "$actual" != "$expected" ]]; then
      echo "  $path"
      ((changes++))
    fi
  done < <(python3 -c "import json; [print(k) for k in json.load(open('$LOCK_FILE'))['entries']]" 2>/dev/null)

  echo "Total: $changes changed"
}

case "${1:-}" in
  generate) cmd_generate ;;
  verify)   cmd_verify ;;
  diff)     cmd_diff ;;
  *)        echo "Usage: skills-lock.sh {generate|verify|diff}" ;;
esac
