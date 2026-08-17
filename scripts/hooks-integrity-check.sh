#!/usr/bin/env bash
# hooks-integrity-check.sh — SE-094: detect orphan and phantom hooks.
#
# Verifies two-way integrity between filesystem and .claude/settings.json:
#   - PHANTOM: registered in settings.json but no .sh file on disk
#     (searches .claude/hooks/, optional .opencode/hooks/, and scripts/)
#   - ORPHAN: .sh file exists in either hooks directory but no registration
#
# Exit 0 if zero violations, 2 otherwise.
# Ref: SE-094, ROADMAP.md §Tier 0

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SETTINGS="$REPO_ROOT/.claude/settings.json"
HOOKS_DIR="$REPO_ROOT/.opencode/hooks"
CLAUDE_HOOKS_DIR="$REPO_ROOT/.claude/hooks"
SCRIPTS_DIR="$REPO_ROOT/scripts"

[[ -f "$SETTINGS" ]] || { echo "ERROR: $SETTINGS not found" >&2; exit 2; }
[[ -d "$CLAUDE_HOOKS_DIR" ]] || { echo "ERROR: $CLAUDE_HOOKS_DIR not found" >&2; exit 2; }

# Extract all hook script paths from settings.json
mapfile -t REGISTERED < <(python3 -c "
import json, re, sys
d = json.load(open('$SETTINGS'))
seen = set()
for event, lst in d.get('hooks', {}).items():
    for matcher in lst:
        for hook in matcher.get('hooks', []):
            cmd = hook.get('command', '')
            # Extract first .sh path from command
            m = re.search(r'([./\w-]+\.sh)', cmd)
            if m:
                path = m.group(1)
                # Strip leading quotes/dollar-expansion
                path = re.sub(r'^.*?(\.claude|\.opencode|scripts)/', r'\1/', path)
                if path not in seen:
                    seen.add(path)
                    print(path)
")

PHANTOM=()
for rel in "${REGISTERED[@]}"; do
  # Resolve relative to repo root; check both candidate locations
  if [[ -f "$REPO_ROOT/$rel" ]]; then
    continue  # found
  fi
  # Also try basename in either dir (handles variant paths)
  base="$(basename "$rel")"
  if [[ -f "$CLAUDE_HOOKS_DIR/$base" || -f "$HOOKS_DIR/$base" || -f "$SCRIPTS_DIR/$base" ]]; then
    continue
  fi
  PHANTOM+=("$rel")
done

# Allowlist: hooks that are intentionally WIRE-READY but NOT registered.
# Each entry MUST justify why (governance / spec reference / human-gate reason).
# Format: "filename.sh\tjustification" — one per line, TAB-separated.
ALLOWLIST_FILE="$REPO_ROOT/.claude/hooks-allowlist.tsv"

declare -A ALLOWED=()
if [[ -f "$ALLOWLIST_FILE" ]]; then
  while IFS=$'\t' read -r fname _just; do
    [[ -z "$fname" || "$fname" =~ ^# ]] && continue
    ALLOWED["$fname"]=1
  done < "$ALLOWLIST_FILE"
fi

# Detect orphans: .sh in either hooks directory not referenced in settings.json
# AND not on the allowlist (deliberate non-registration).
mapfile -t ORPHANS < <(
  while IFS= read -r f; do
    base="$(basename "$f")"
    [[ -n "${ALLOWED[$base]:-}" ]] && continue
    if ! grep -q "$base" "$SETTINGS" 2>/dev/null; then
      echo "$base"
    fi
  done < <(find -L "$CLAUDE_HOOKS_DIR" "$HOOKS_DIR" -maxdepth 1 -name '*.sh' -type f 2>/dev/null)
)

EXIT=0

if [[ ${#PHANTOM[@]} -gt 0 ]]; then
  echo "PHANTOM (registered in settings.json but no .sh found):"
  printf '  %s\n' "${PHANTOM[@]}"
  EXIT=2
fi

if [[ ${#ORPHANS[@]} -gt 0 ]]; then
  echo "ORPHAN (.sh in hooks directories without registration):"
  printf '  %s\n' "${ORPHANS[@]}"
  EXIT=2
fi

if [[ $EXIT -eq 0 ]]; then
  echo "PASS: hooks integrity OK"
  echo "  registered=${#REGISTERED[@]} on-disk-hooks=$(find -L "$CLAUDE_HOOKS_DIR" "$HOOKS_DIR" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
fi

exit $EXIT
