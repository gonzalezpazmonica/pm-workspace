#!/usr/bin/env bash
set -uo pipefail
# generate-blocklist.sh — Dynamic blocklist from workspace context
# Scans projects/, CLAUDE.local.md, profiles, team files for real names.
# Outputs patterns to stdout (one per line) for piping to scanner.
# Usage: bash scripts/generate-blocklist.sh > /tmp/blocklist.txt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Projects that are SAFE (generic names or explicitly public/whitelisted)
SAFE_PROJECTS="proyecto-alpha|proyecto-beta|sala-reservas|example|test|demo|sample|template"
# Public projects whitelisted in .gitignore with !projects/name/
GITIGNORE="$ROOT_DIR/.gitignore"
if [ -f "$GITIGNORE" ]; then
  PUBLIC_PROJS=$(grep -oE '!projects/[a-z][a-z0-9_-]+/' "$GITIGNORE" \
    | sed 's|!projects/||;s|/||' | tr '\n' '|' | sed 's/|$//')
  [ -n "$PUBLIC_PROJS" ] && SAFE_PROJECTS="$SAFE_PROJECTS|$PUBLIC_PROJS"
fi

PATTERNS=()
add() { PATTERNS+=("$1"); }

# ── Source 1: Real project directory names ─────────────────────────────────
if [ -d "$ROOT_DIR/projects" ]; then
  for dir in "$ROOT_DIR"/projects/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    echo "$name" | grep -qiE "^($SAFE_PROJECTS)$" && continue
    add "$name"
    # Also match with separators (traza-bios, traza_bios, traza bios)
    base=$(echo "$name" | sed 's/[-_]/.?/g')
    [ "$base" != "$name" ] && add "$base"
  done
fi

# ── Source 2: CLAUDE.local.md project names ────────────────────────────────
LOCAL_MD="$ROOT_DIR/CLAUDE.local.md"
if [ -f "$LOCAL_MD" ]; then
  grep -oE 'PROJECT_[A-Z]+_NAME\s*=\s*"([^"]+)"' "$LOCAL_MD" \
    | sed 's/.*=\s*"//;s/"$//' | while read -r pname; do
    add "$pname"
  done
  # Azure DevOps org names
  grep -oE 'dev\.azure\.com/[A-Za-z0-9_-]+' "$LOCAL_MD" \
    | sed 's|dev.azure.com/||' | while read -r org; do
    echo "$org" | grep -qi "MI-ORGANIZACION" || add "$org"
  done
fi

# ── Source 3: Team member real names from project team files ───────────────
for teamfile in "$ROOT_DIR"/projects/*/team/TEAM.md; do
  [ -f "$teamfile" ] || continue
  # Extract "### Name Surname" patterns (H3 headers = team members)
  grep -oE '^### [A-Z][a-z]+ [A-Z][a-z]+' "$teamfile" \
    | sed 's/^### //' | while read -r fullname; do
    # Add full name
    add "$fullname"
    # Add surname alone (>4 chars to avoid false positives)
    surname=$(echo "$fullname" | awk '{print $NF}')
    [ ${#surname} -gt 4 ] && add "$surname"
  done
done

# ── Source 4: Profile real names ───────────────────────────────────────────
for idfile in "$ROOT_DIR"/.claude/profiles/users/*/identity.md; do
  [ -f "$idfile" ] || continue
  grep -oE 'name:\s*"?([^"]+)"?' "$idfile" \
    | sed 's/name:\s*"*//;s/"$//' | while read -r uname; do
    [ ${#uname} -gt 3 ] && add "$uname"
  done
done

# ── Source 5: Corporate email domains from local config ────────────────────
if [ -f "$LOCAL_MD" ]; then
  grep -oiE '@[a-z0-9.-]+\.(com|es|org|net)' "$LOCAL_MD" \
    | grep -v "@example\.\|@test\.\|@contoso\.\|@miorganizacion\." \
    | sort -u | while read -r domain; do
    add "$domain"
  done
fi

# ── Source 6: Static public blocklist (always include) ─────────────────────
STATIC="$ROOT_DIR/scripts/confidentiality-blocklist.txt"
if [ -f "$STATIC" ]; then
  grep -v "^#" "$STATIC" | grep -v "^$" | while read -r pat; do
    add "$pat"
  done
fi

# ── Output: deduplicated patterns ──────────────────────────────────────────
if [ ${#PATTERNS[@]} -gt 0 ]; then
  printf '%s\n' "${PATTERNS[@]}" | sort -u | grep -v "^$"
fi
