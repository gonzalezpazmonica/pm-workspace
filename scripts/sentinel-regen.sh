#!/usr/bin/env bash
# Ref: SPEC-180 / docs/rules/domain/sentinel-safe-regen.md
# Sentinel-safe regeneration primitive: inject / extract / verify-hash.
set -uo pipefail

usage() {
  cat >&2 <<EOF
Usage:
  sentinel-regen.sh inject FILE SECTION-ID            (reads new content from stdin)
  sentinel-regen.sh extract FILE SECTION-ID
  sentinel-regen.sh verify-hash FILE
EOF
  exit 2
}

# sha8 of the given string (first 8 hex chars of sha256)
sha8() {
  printf '%s' "$1" | sha256sum | awk '{print substr($1,1,8)}'
}

# Print the line range [start_excl+1 .. end_excl-1] of FILE — inner content.
# Empty if range is empty.
inner_between() {
  local file="$1" start="$2" end="$3"
  if (( end - start <= 1 )); then
    return 0
  fi
  awk -v s="$start" -v e="$end" 'NR>s && NR<e {print}' "$file"
}

# Find START / END line numbers for SECTION-ID in FILE.
# Echoes "start_line end_line stored_hash" on stdout, or empty if not found.
# Errors to stderr; returns 0 if found, 1 if not found, 2 if malformed.
find_block() {
  local file="$1" sid="$2"
  local start_line end_line stored_hash
  start_line=$(grep -n -E "^<!-- @generated:${sid} START hash=[a-f0-9]*+ -->\$" "$file" | head -1 | cut -d: -f1 || true)
  if [[ -z "$start_line" ]]; then
    return 1
  fi
  stored_hash=$(sed -n "${start_line}p" "$file" | sed -E "s/^<!-- @generated:${sid} START hash=([a-f0-9]*) -->\$/\\1/")
  end_line=$(awk -v s="$start_line" -v sid="$sid" '
    NR>s && $0 ~ "^<!-- @generated:" sid " END -->$" { print NR; exit }
  ' "$file")
  if [[ -z "$end_line" ]]; then
    echo "ERROR: section '$sid' has START at line $start_line but no END marker" >&2
    return 2
  fi
  printf '%s %s %s\n' "$start_line" "$end_line" "$stored_hash"
  return 0
}

cmd_inject() {
  local file="$1" sid="$2"
  [[ -e "$file" ]] || : > "$file"
  [[ -f "$file" ]] || { echo "ERROR: not a regular file: $file" >&2; exit 1; }
  [[ "$sid" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "ERROR: invalid section-id (kebab-case lowercase): $sid" >&2; exit 1; }

  local new_content
  new_content=$(cat)
  local new_hash
  new_hash=$(sha8 "$new_content")

  local block
  block=$(find_block "$file" "$sid")
  local rc=$?
  if [[ $rc -eq 2 ]]; then exit 1; fi

  local tmp
  tmp=$(mktemp)
  if [[ $rc -eq 1 ]]; then
    # Append at EOF (ensure trailing newline)
    cp "$file" "$tmp"
    [[ -s "$tmp" ]] && [[ -n "$(tail -c1 "$tmp")" ]] && printf '\n' >> "$tmp"
    {
      echo "<!-- @generated:${sid} START hash=${new_hash} -->"
      printf '%s\n' "$new_content"
      echo "<!-- @generated:${sid} END -->"
    } >> "$tmp"
  else
    local start_line end_line _stored
    read -r start_line end_line _stored <<<"$block"
    {
      awk -v n="$start_line" 'NR<n' "$file"
      echo "<!-- @generated:${sid} START hash=${new_hash} -->"
      printf '%s\n' "$new_content"
      echo "<!-- @generated:${sid} END -->"
      awk -v n="$end_line" 'NR>n' "$file"
    } > "$tmp"
  fi
  mv "$tmp" "$file"
}

cmd_extract() {
  local file="$1" sid="$2"
  [[ -f "$file" ]] || { echo "ERROR: file not found: $file" >&2; exit 1; }
  local block
  block=$(find_block "$file" "$sid") || { echo "ERROR: section '$sid' not found in $file" >&2; exit 1; }
  local s e _h
  read -r s e _h <<<"$block"
  inner_between "$file" "$s" "$e"
}

cmd_verify_hash() {
  local file="$1"
  [[ -f "$file" ]] || { echo "ERROR: file not found: $file" >&2; exit 1; }
  local drift=0
  local seen=()

  while IFS= read -r line; do
    local lineno marker
    lineno=$(echo "$line" | cut -d: -f1)
    marker=$(echo "$line" | cut -d: -f2-)
    local sid stored
    sid=$(echo "$marker" | sed -E 's/^<!-- @generated:([a-z0-9-]+) START hash=[a-f0-9]* -->$/\1/')
    stored=$(echo "$marker" | sed -E 's/^<!-- @generated:[a-z0-9-]+ START hash=([a-f0-9]*) -->$/\1/')

    # Duplicate id check
    for prev in "${seen[@]:-}"; do
      if [[ "$prev" == "$sid" ]]; then
        echo "ERROR: duplicate section-id '$sid' in $file" >&2
        drift=1
      fi
    done
    seen+=("$sid")

    local block
    block=$(find_block "$file" "$sid") || { drift=1; continue; }
    local s e _h
    read -r s e _h <<<"$block"
    local content recomputed
    content=$(inner_between "$file" "$s" "$e")
    recomputed=$(sha8 "$content")
    if [[ "$stored" != "$recomputed" ]]; then
      echo "DRIFT: section '$sid' stored=$stored recomputed=$recomputed" >&2
      drift=1
    fi
  done < <(grep -n -E '^<!-- @generated:[a-z0-9-]+ START hash=[a-f0-9]* -->$' "$file" || true)

  if [[ $drift -eq 0 ]]; then
    echo "OK: all generated blocks match stored hashes"
    return 0
  fi
  return 1
}

main() {
  local mode="${1:-}"
  case "$mode" in
    inject)        shift; [[ $# -eq 2 ]] || usage; cmd_inject "$1" "$2" ;;
    extract)       shift; [[ $# -eq 2 ]] || usage; cmd_extract "$1" "$2" ;;
    verify-hash)   shift; [[ $# -eq 1 ]] || usage; cmd_verify_hash "$1" ;;
    *)             usage ;;
  esac
}

main "$@"
