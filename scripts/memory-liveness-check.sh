#!/usr/bin/env bash
# scripts/memory-liveness-check.sh — SE-257 Slice 2
# Verifica que todos los scripts de memoria tienen consumidor vivo
# y que no hay huerfanos.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-missing)
      shift
      if [[ -z "${1:-}" ]]; then
        echo "ERROR: --check-missing requires a path argument" >&2
        exit 1
      fi
      if [[ ! -e "$1" ]]; then
        echo "ERROR: artifact not found: $1" >&2
        exit 1
      fi
      echo "  OK: artifact exists: $1"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

echo "=== Memory Liveness Check ==="

mapfile -d '' MEMORY_SCRIPTS < <(
  find "$ROOT/scripts" -type f \( -name "*memory*" -o -name "*memor*" -o -name "*bitemporal*" \) \
    ! -name "*.pyc" ! -name "test-*" ! -name "*.test.py" ! -path "*_legacy*" -print0 | sort -z
)
ORPHANS=0
OK=0

declare -A SCRIPT_BY_NAME=()
declare -A REFERENCED=()
PATTERNS=$(mktemp)
MATCHES=$(mktemp)
MATCHED_FILES=$(mktemp)
trap 'rm -f "$PATTERNS" "$MATCHES" "$MATCHED_FILES"' EXIT

for script in "${MEMORY_SCRIPTS[@]}"; do
  name=$(basename "$script")
  SCRIPT_BY_NAME["$name"]="${script#"$ROOT/"}"
  printf '%s\n' "$name" >> "$PATTERNS"
done

SEARCH_ROOTS=()
for directory in scripts docs .claude .opencode tests .github; do
  [[ -d "$ROOT/$directory" ]] && SEARCH_ROOTS+=("$directory")
done

if [[ -s "$PATTERNS" && ${#SEARCH_ROOTS[@]} -gt 0 ]]; then
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    (cd "$ROOT" && git grep -z -o -F -f "$PATTERNS" \
      -- "${SEARCH_ROOTS[@]}" 2>/dev/null) > "$MATCHES" || true
  elif command -v rg >/dev/null 2>&1; then
    (cd "$ROOT" && rg -o -F -f "$PATTERNS" --field-match-separator $'\t' \
      --glob '!node_modules/**' --glob '!output/**' --glob '!.git/**' --glob '!*.pyc' \
      -- "${SEARCH_ROOTS[@]}" 2>/dev/null) > "$MATCHES" || true
  else
    (cd "$ROOT" && grep -rlZF -f "$PATTERNS" --exclude='*.pyc' --exclude-dir=node_modules \
      --exclude-dir=output --exclude-dir=.git -- "${SEARCH_ROOTS[@]}" 2>/dev/null) > "$MATCHED_FILES" || true
  fi
fi

if [[ -s "$MATCHES" ]]; then
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' reference && IFS= read -r name; do
      [[ -n "$name" && "$reference" != "${SCRIPT_BY_NAME[$name]:-}" ]] && REFERENCED["$name"]=1
    done < "$MATCHES"
  else
  while IFS=$'\t' read -r reference name; do
    [[ -n "$name" && "$reference" != "${SCRIPT_BY_NAME[$name]:-}" ]] && REFERENCED["$name"]=1
  done < "$MATCHES"
  fi
elif [[ -s "$MATCHED_FILES" ]]; then
  while IFS= read -r -d '' reference; do
    [[ -f "$ROOT/$reference" && ! -L "$ROOT/$reference" ]] || continue
    while IFS= read -r name; do
      [[ "$reference" != "${SCRIPT_BY_NAME[$name]:-}" ]] && REFERENCED["$name"]=1
    done < <(grep -oF -f "$PATTERNS" -- "$ROOT/$reference" 2>/dev/null || true)
  done < "$MATCHED_FILES"
fi

for script in "${MEMORY_SCRIPTS[@]}"; do
  name=$(basename "$script")
  if [[ -n "${REFERENCED[$name]:-}" ]]; then
    echo "  OK: $name"
    OK=$((OK + 1))
  else
    echo "  ORPHAN: $name (no external references found)"
    ORPHANS=$((ORPHANS + 1))
  fi
done

echo ""
echo "  Total: $OK OK, $ORPHANS orphans"
[ "$ORPHANS" -gt 0 ] && exit 1
exit 0
