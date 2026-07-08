#!/bin/bash
set -uo pipefail
# tracked-vs-nivel.sh — SE-258 Slice 1
# Cruza git ls-files contra config/sensitive-paths.yaml

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$REPO_ROOT/config/sensitive-paths.yaml"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: config/sensitive-paths.yaml not found at $CONFIG" >&2
  exit 2
fi

echo "=== Tracked-vs-Nivel Report ==="

FOUND_N3=0
FOUND_N2=0

# Parse YAML manually: extract patterns per level
extract_patterns() {
  local level="$1"
  sed -n "/^  ${level}:/,/^  [AN]/p" "$CONFIG" | grep '^\s*- ' | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

# Match a file against patterns for a level
match_any() {
  local file="$1"
  shift
  local patterns=("$@")
  for p in "${patterns[@]}"; do
    [[ -z "$p" ]] && continue
    case "$file" in
      $p) return 0 ;;
    esac
  done
  return 1
}

# Collect patterns
mapfile -t N4_PATTERNS < <(extract_patterns "N4")
mapfile -t N3_PATTERNS < <(extract_patterns "N3")
mapfile -t N2_PATTERNS < <(extract_patterns "N2")

echo "Checking $(git ls-files | wc -l) tracked files..."
echo ""

cd "$REPO_ROOT"
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  
  if match_any "$file" "${N4_PATTERNS[@]}"; then
    echo "  [N4] $file"
    FOUND_N3=$((FOUND_N3 + 1))
  elif match_any "$file" "${N3_PATTERNS[@]}"; then
    echo "  [N3] $file"
    FOUND_N3=$((FOUND_N3 + 1))
  elif match_any "$file" "${N2_PATTERNS[@]}"; then
    echo "  [N2] $file"
    FOUND_N2=$((FOUND_N2 + 1))
  fi
done < <(git ls-files)

echo ""
echo "=== Summary ==="
echo "N3+ tracked: $FOUND_N3"
echo "N2 tracked:  $FOUND_N2"

if [ "$FOUND_N3" -gt 0 ]; then
  echo "ACTION REQUIRED: $FOUND_N3 files at N3+ level are tracked in git."
  exit 1
fi

echo "OK: Zero N3+ files tracked."
exit 0
